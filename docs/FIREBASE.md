# Notificaciones push con Firebase

Firebase envía los avisos a la app del negocio aunque esté cerrada. Es gratis (Firebase Cloud Messaging no cobra
por mensaje). Sin Firebase todo funciona igual: la app se actualiza cada 30 s mientras está abierta, pero no avisa
con el teléfono bloqueado.

## Qué avisos llegan

| Aviso | A quién | Cuándo |
| --- | --- | --- |
| **En 30 min: Rosa Paz** | Al profesional de la cita. Si no tiene cuenta en la app, a la cuenta general | N min antes de cada cita confirmada (10, 15, 30 o 60; se elige en la app o en el panel) |
| **Nueva reserva por confirmar** | Al profesional elegido y a la cuenta general | Al reservar en la web |
| **Tienes reservas por confirmar** | Igual | Si pasan horas sin respuesta, y la víspera |
| **Agenda de mañana** | A todas las cuentas | 8 p. m., si mañana hay citas |

Cada persona apaga en su teléfono los que no quiera: **Ajustes → Notificaciones**.

### Sonidos con voz

Cada tipo suena distinto, con una campanita y la voz de Camila (voz neuronal femenina de Perú), para saber qué pasó sin mirar el teléfono:

| Canal de Android | Se oye |
| --- | --- |
| Reservas por confirmar | «¡Hola! Tienes una nueva reserva por confirmar» |
| Citas nuevas | «¡Listo! Se agendó una nueva cita» |
| Cita por empezar | «Tu próxima cita empieza en unos minutos» |
| Resumen y otros avisos | Solo la campanita |

Los audios están en `app_doctor/android/app/src/main/res/raw/aviso_*.ogg`. En el teléfono se puede cambiar el sonido
de cada canal: mantener presionada la notificación → Ajustes. Si se reemplaza un audio, hay que darle al canal un id
nuevo (Android guarda el sonido del canal la primera vez).

## Paso a paso (una sola vez, unos 10 minutos)

### 1. Crear el proyecto

1. Entra a <https://console.firebase.google.com> con tu cuenta de Google.
2. **Crear un proyecto** → nombre `RyCitas` → puedes desactivar Google Analytics → **Crear proyecto**.

### 2. Registrar la app Android (dos veces: pruebas y producción)

1. En el proyecto, toca el ícono de **Android**.
2. **Nombre del paquete:** `pe.rycitas.app.dev` (la versión de pruebas) → **Registrar app**.
3. **Descarga `google-services.json`** y guárdalo en
   `app_doctor\android\app\src\dev\google-services.json`.
4. Los pasos siguientes del asistente (agregar el SDK) ya están hechos en el código: toca **Siguiente** hasta terminar.
5. Repite con el paquete `pe.rycitas.app` (producción) y guarda ese archivo en
   `app_doctor\android\app\src\prod\google-services.json`.

### 3. La clave para que el servidor pueda enviar

1. ⚙️ **Configuración del proyecto → Cuentas de servicio → Generar nueva clave privada → Generar clave**.
2. Se descarga un `.json`. Es un **secreto**: no lo subas a GitHub ni lo dejes en OneDrive.
3. Guárdalo como `%LOCALAPPDATA%\denticita\firebase.json`. Para abrir esa carpeta, pega `%LOCALAPPDATA%\denticita` en la
   barra del Explorador de archivos.
4. `scripts\dev.ps1 run` lo detecta solo. En el servidor de producción va en `/secretos/firebase.json`, con
   `FIREBASE_PROJECT_ID` y `FIREBASE_CREDENCIALES` en `deploy/.env` (ver `deploy/.env.example`).

### 4. Instalar la app en el teléfono

Con el teléfono conectado por USB (y «Instalar vía USB» activado en los Xiaomi):

```powershell
cd app_doctor
flutter run --flavor dev --dart-define-from-file=config/dev.json
```

Al entrar, la app pide permiso para notificaciones: **Permitir**. Desde ese momento el teléfono queda registrado.

### 5. Probar

Reserva una cita en el sitio del negocio. En segundos le llega al teléfono «Nueva reserva por confirmar».

## Si no llega

- **La app no pidió permiso:** en Android, Ajustes → Apps → RyCitas → Notificaciones → activar.
- **Xiaomi / Redmi:** Ajustes → Apps → RyCitas → **Inicio automático: activado** y **Ahorro de batería: sin
  restricciones**. MIUI/HyperOS detiene las apps en segundo plano y entonces los avisos llegan tarde o no llegan.
- **El servidor no tiene la clave:** en el registro de tareas aparece `push omitido (Firebase sin configurar)`.
- **El aviso está apagado** para esa cuenta en Ajustes → Notificaciones.
