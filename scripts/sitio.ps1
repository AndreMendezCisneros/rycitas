# Compila el sitio propio de un negocio y lo deja listo para RyCitas.
#
#   .\scripts\sitio.ps1 visage-artisan-hub
#
# Toma el código de sitios\<nombre>\, lo compila FUERA de OneDrive (node_modules tiene miles de archivos) y copia el
# resultado a backend\sitios_propios\<nombre>\. Luego, en el panel, ficha del negocio > Sitio > «Sitio propio».
# Funciona con proyectos Vite, Create React App, Astro o cualquier otro cuyo `npm run build` deje dist\ o build\.
param([Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9]+(-[a-z0-9]+)*$')][string]$Nombre)
$ErrorActionPreference = "Stop"

$Raiz = Split-Path $PSScriptRoot -Parent
$Fuente = Join-Path $Raiz "sitios\$Nombre"
$Destino = Join-Path $Raiz "backend\sitios_propios\$Nombre"
$Obra = Join-Path $env:LOCALAPPDATA "rycitas\build\$Nombre"
if (-not (Test-Path (Join-Path $Fuente "package.json"))) { throw "No encontré sitios\$Nombre\package.json" }

Write-Host "Copiando el código a $Obra"
New-Item -ItemType Directory -Force $Obra | Out-Null
robocopy $Fuente $Obra /MIR /XD .git node_modules dist build /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy falló ($LASTEXITCODE)" }

Push-Location $Obra
# npm y Vite escriben avisos en stderr; con "Stop" PowerShell los tomaría como error. Se mira el código de salida.
$ErrorActionPreference = "Continue"
try {
    npm install --no-audit --no-fund --loglevel=error
    if ($LASTEXITCODE -ne 0) { throw "npm install falló" }
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "npm run build falló" }
} finally { Pop-Location; $ErrorActionPreference = "Stop" }

$Salida = @("dist", "build", "out") | ForEach-Object { Join-Path $Obra $_ } | Where-Object { Test-Path (Join-Path $_ "index.html") } | Select-Object -First 1
if (-not $Salida) { throw "La compilación no dejó un index.html en dist\, build\ ni out\" }
if (-not (Select-String -Path (Join-Path $Salida "index.html") -Pattern "/rycitas.js" -Quiet)) {
    Write-Warning "index.html no incluye <script src=""/rycitas.js"" defer>: los botones de reserva no abrirán RyCitas."
}

if (Test-Path $Destino) { Remove-Item -Recurse -Force $Destino }
New-Item -ItemType Directory -Force $Destino | Out-Null
Copy-Item -Recurse -Force (Join-Path $Salida "*") $Destino
Write-Host "Listo: backend\sitios_propios\$Nombre"
