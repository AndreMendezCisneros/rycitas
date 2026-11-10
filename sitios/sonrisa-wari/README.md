# Sonrisa Wari: sitio propio

Sitio del consultorio (React + Vite), basado en el diseño de `cita-clinica-clara` y conectado a RyCitas.

- **Datos en vivo:** tratamientos, precios «desde», duración, horario, dirección, WhatsApp, doctora, formas de pago
  y bloques de confianza salen de `/public/v1/sonrisa-wari/perfil`. Se cambian en el panel, no aquí.
  `src/datos.ts` guarda una copia de respaldo para el primer pintado.
- **Textos propios:** explicación de cada tratamiento, preguntas y consejos en `src/contenido.ts`. Un tratamiento
  nuevo del panel aparece solo, con un texto armado a partir de su descripción.
- **Reserva:** cada botón «Reservar» es un enlace a `/reservar/?servicio=<slug>` que `rycitas.js` abre encima.

Compilar y publicar en local: `.\scripts\sitio.ps1 sonrisa-wari` y, en el panel, Sitio → «Sitio propio: sonrisa-wari».
Desarrollo con recarga: `npm install` y `npm run dev` (http://localhost:8081, usa el backend de :8000).
