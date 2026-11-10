# Arranque local de RyCitas en Windows, sin Docker.
#
#   .\scripts\dev.ps1 setup    Crea el entorno y la base (una vez)
#   .\scripts\dev.ps1 run      Levanta la base, las tareas y el servidor
#   .\scripts\dev.ps1 test     Ejecuta las pruebas
#   .\scripts\dev.ps1 stop     Detiene la base
#
# Base de datos: por defecto, tu PostgreSQL instalado (puerto 5432), base y usuario «denticita».
# Créalos una vez con (te pide la clave de postgres):
#   psql -U postgres -h localhost -c "CREATE ROLE denticita LOGIN PASSWORD 'denticita' CREATEDB;" -c "CREATE DATABASE denticita OWNER denticita;"
# Con $env:DENTICITA_PG_PORT = "5544" usa en cambio un clúster propio, fuera de OneDrive (sincronizar una base
# en uso la corrompería), sin tocar tu servidor instalado.
# Otras variables: DENTICITA_PG_PASSWORD (por defecto «denticita»).
param([ValidateSet("setup", "run", "test", "stop")][string]$Accion = "run")
$ErrorActionPreference = "Stop"

$Local = if ($env:DENTICITA_LOCAL) { $env:DENTICITA_LOCAL } else { Join-Path $env:LOCALAPPDATA "denticita" }
$Venv = Join-Path $Local "venv"
$Datos = Join-Path $Local "pg"
$Backend = Join-Path (Split-Path $PSScriptRoot -Parent) "backend"
$Py = Join-Path $Venv "Scripts\python.exe"
$Puerto = if ($env:DENTICITA_PG_PORT) { $env:DENTICITA_PG_PORT } else { "5432" }
$ClusterPropio = $Puerto -eq "5544"

$Pg = Get-ChildItem "C:\Program Files\PostgreSQL\*\bin\pg_ctl.exe" -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1
if (-not $Pg) { throw "No encontré PostgreSQL en C:\Program Files\PostgreSQL" }
$PgBin = $Pg.DirectoryName

$env:DJANGO_DEBUG = "1"
$env:POSTGRES_HOST = "localhost"
$env:POSTGRES_PORT = $Puerto
$env:POSTGRES_DB = "denticita"
$env:POSTGRES_USER = "denticita"
$env:POSTGRES_PASSWORD = if ($env:DENTICITA_PG_PASSWORD) { $env:DENTICITA_PG_PASSWORD } else { "denticita" }
$env:PLATAFORMA_DOMINIO = "localhost"
$env:WHATSAPP_APP_SECRET = "secreto-solo-para-desarrollo"
$env:WHATSAPP_VERIFY_TOKEN = "token-solo-para-desarrollo"
$env:MAX_INTENTOS_IP_HORA = "1000"

# Notificaciones push: si guardaste la clave de la cuenta de servicio de Firebase en %LOCALAPPDATA%\denticita\firebase.json
# (fuera de OneDrive: es un secreto), se usa sola. Sin ella todo funciona igual, solo que sin push. Ver docs/FIREBASE.md.
$Firebase = Join-Path $Local "firebase.json"
if (Test-Path $Firebase) {
    $env:FIREBASE_CREDENCIALES = $Firebase
    $env:FIREBASE_PROJECT_ID = (Get-Content $Firebase -Raw | ConvertFrom-Json).project_id
}

function Iniciar-Base {
    if (-not $ClusterPropio) {
        & "$PgBin\pg_isready.exe" -h localhost -p $Puerto | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "PostgreSQL no responde en el puerto $Puerto. Revisa el servicio postgresql en services.msc" }
        return
    }
    & "$PgBin\pg_ctl.exe" -D $Datos status *> $null
    if ($LASTEXITCODE -ne 0) {
        & "$PgBin\pg_ctl.exe" -D $Datos -w -l (Join-Path $Local "pg.log") -o "-p $Puerto" start
    }
}

switch ($Accion) {
    "setup" {
        New-Item -ItemType Directory -Force $Local | Out-Null
        if (-not (Test-Path $Py)) { python -m venv $Venv }
        & $Py -m pip install -q --disable-pip-version-check -r (Join-Path $Backend "requirements-dev.txt")
        if ($ClusterPropio -and -not (Test-Path (Join-Path $Datos "PG_VERSION"))) {
            $clave = Join-Path $Local "pgpass.tmp"
            Set-Content -Path $clave -Value "denticita" -Encoding ascii -NoNewline
            & "$PgBin\initdb.exe" -D $Datos -U denticita --pwfile=$clave -A scram-sha-256 -E UTF8 --locale=C | Out-Null
            Remove-Item $clave
        }
        Iniciar-Base
        $env:PGPASSWORD = $env:POSTGRES_PASSWORD
        $existe = & "$PgBin\psql.exe" -h localhost -p $Puerto -U denticita -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='denticita'"
        if ($existe -ne "1") { & "$PgBin\createdb.exe" -h localhost -p $Puerto -U denticita denticita }
        & $Py (Join-Path $Backend "manage.py") migrate --noinput
        & $Py (Join-Path $Backend "manage.py") programar_tareas
        & $Py (Join-Path $Backend "manage.py") crear_demo
    }
    "run" {
        Iniciar-Base
        # IP de la PC en la red local: así un teléfono en el mismo Wi-Fi llega al servidor.
        $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254*' -and $_.PrefixOrigin -ne 'WellKnown' } |
            Select-Object -First 1 -ExpandProperty IPAddress
        if ($ip) {
            $env:HOSTS_DESARROLLO = $ip
            $config = Join-Path (Split-Path $PSScriptRoot -Parent) "app_doctor\config\telefono.json"
            Set-Content -Path $config -Encoding utf8 -Value "{`n  `"API_URL`": `"http://${ip}:8000`",`n  `"SENTRY_DSN`": `"`"`n}"
        }
        & $Py (Join-Path $Backend "manage.py") migrate --noinput | Out-Null
        $tareas = Start-Process -PassThru -NoNewWindow $Py -ArgumentList "`"$(Join-Path $Backend 'manage.py')`"", "qcluster"
        try {
            Write-Host "Sitio demo:  http://sonrisa-wari.localhost:8000"
            Write-Host "Panel:       http://localhost:8000/panel/"
            Write-Host "API (docs):  http://localhost:8000/api/v1/docs"
            if ($ip) { Write-Host "Teléfono:    http://${ip}:8000 (config\telefono.json actualizado)" }
            & $Py (Join-Path $Backend "manage.py") runserver 0.0.0.0:8000
        } finally {
            Stop-Process -Id $tareas.Id -ErrorAction SilentlyContinue
        }
    }
    "test" {
        Iniciar-Base
        Push-Location $Backend
        try { & $Py -m pytest --cov=agenda.motor --cov=citas.estimacion --cov=citas.servicios --cov-report=term-missing @args }
        finally { Pop-Location }
    }
    "stop" {
        if ($ClusterPropio) { & "$PgBin\pg_ctl.exe" -D $Datos -m fast stop }
        else { Write-Host "Tu PostgreSQL instalado es un servicio de Windows: no se detiene desde aquí." }
    }
}
