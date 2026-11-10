# Sitios propios: el sitio web del negocio con la reserva de RyCitas

Cada negocio puede tener **su propio sitio web completo** (hecho en React, Vue, Astro o HTML plano). RyCitas no lo
reemplaza: entra solo cuando el cliente toca «Agendar cita», y la reserva se abre encima del sitio.

| Dónde | Qué se ve |
| --- | --- |
| `negocio.rycitas.com/` | El sitio propio del negocio, o la landing de RyCitas si no tiene uno |
| Botón «Agendar» del sitio | La reserva de RyCitas encima de la página: a pantalla completa en el celular y como ventana centrada en la PC. Se cierra con la ×, con Escape o con el gesto «atrás» del celular |
| `negocio.rycitas.com/reservar/` | **Enlace directo** para mandar por WhatsApp o ponerlo en redes. Abre la reserva sola, a pantalla completa |
| `/reservar/?servicio=hydrafacial` | Igual, con el servicio ya elegido (vale el slug o el nombre). `&con=<id>` elige además al profesional |

El enlace directo aparece en el panel, en la ficha del negocio, pestaña **Sitio**.

## Sumar el sitio de un negocio

1. **Copia el código** a `sitios/<nombre>/`. Por ejemplo, `git clone <repo> sitios/<nombre>`. El nombre va en
   minúsculas, con números y guiones.
2. **Conecta sus botones** con RyCitas:
   - En `index.html`, dentro de `<head>`:
     ```html
     <script src="/rycitas.js" defer></script>
     ```
   - En cada botón o enlace de reserva:
     ```html
     <a href="/reservar/" data-rycitas-reservar>Agendar cita</a>
     <a href="/reservar/" data-rycitas-reservar data-servicio="Hydrafacial">Agendar este tratamiento</a>
     ```
   El `href` hace que el enlace funcione aunque el script no cargue. Cualquier enlace a `/reservar/` abre la reserva
   encima, aunque no tenga el atributo. Desde código se usa `window.RyCitas.abrir({ servicio: "Hydrafacial" })`.
3. **Compílalo**:
   ```powershell
   .\scripts\sitio.ps1 <nombre>
   ```
   El script compila fuera de OneDrive (en `%LOCALAPPDATA%\rycitas\build`) y deja el resultado en
   `backend/sitios_propios/<nombre>/`. Avisa si `index.html` no incluye `/rycitas.js`.
4. **Actívalo en el panel**: ficha del negocio → **Sitio** → «Sitio web: Sitio propio: <nombre>». En la misma pestaña,
   pon en «Color de la reserva» el color principal del sitio (por ejemplo `#32b8c6`). La reserva y la app del negocio
   usan ese color.
5. **Revisa que los servicios del panel tengan los mismos nombres** que los botones con `data-servicio`.
   Si un nombre no coincide, la reserva empieza desde el paso 1, sin servicio elegido.

## Cómo funciona por dentro

- **Rutas.** Las rutas de RyCitas siempre ganan al sitio propio: `/reservar/`, `/c/`, `/public/`, `/api/`,
  `/privacidad/`, `/rycitas.js` y `/static/`. Lo demás lo sirve `sitio/propios.py`:
  - Si el archivo existe, se sirve ese archivo.
  - Una ruta sin extensión (`/tratamientos`) recibe `index.html`, para que el router del sitio la pinte.
  - Un archivo con extensión que no existe da 404.
  - Ninguna ruta puede salir de la carpeta del sitio.
- **Caché.** Los assets con hash en el nombre se guardan un año. `index.html` se guarda 5 minutos en Cloudflare.
- **Seguridad.**
  - El sitio propio tiene su propia política de contenido. Permite estilos en línea e imágenes externas, que React y
    Tailwind necesitan, pero solo scripts del mismo dominio.
  - Solo `/reservar/` puede mostrarse dentro de un iframe, y solo desde el mismo sitio (`frame-ancestors 'self'`).
- **Sin publicar.** Un negocio sin publicar muestra «Sitio en preparación» aunque tenga sitio propio.
- **Producción.** `COPY . .` del `Dockerfile` ya incluye `backend/sitios_propios/`. Para actualizar un sitio:
  1. Compila con `scripts/sitio.ps1`.
  2. Despliega como siempre.
  3. Purga la caché de Cloudflare de ese subdominio.

## Demostración: GlowClinic

- **Código:** `sitios/visage-artisan-hub` (React + Vite + Tailwind). Sus botones «Agendar» abren RyCitas, y el
  formulario de contacto simulado se reemplazó por una tarjeta que abre la reserva.
- **Negocio de prueba:** `crear_demo` crea «GlowClinic».
  - Tipo estética, 3 profesionales, los 7 servicios del sitio y color `#32b8c6`.
  - Sitio: <http://glowclinic.localhost:8000>.
  - Enlace directo: <http://glowclinic.localhost:8000/reservar/>.
  - App: `recepcion@glowclinic.test` con la clave de demostración.
