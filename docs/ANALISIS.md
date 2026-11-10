# RyCitas (antes DentiCita): análisis, decisiones y trazabilidad

Fuente principal: `MVP_DentiCita_Requerimientos_y_Arquitectura.pdf` (34 RF: 28 Debe y 6 Debería; 18 RNF).
Las cuentas de costo del documento son correctas: S/ 31 al mes en total y S/ 37 con 360 mensajes.

> **Cambio vigente: confirmación manual por WhatsApp (sección 7).** Sin la API de WhatsApp, la reserva web queda
> «por confirmar» y el doctor confirma, recuerda y avisa desde su propio WhatsApp con un toque. El flujo de verificación
> con código (RF-09 a RF-11) sigue en el código detrás de `VERIFICACION_WHATSAPP=1`.

## 1. Riesgos que conviene resolver antes del piloto

| Riesgo | Por qué importa | Qué hacer |
| --- | --- | --- |
| **Google Calendar puede ignorar las alarmas de un `.ics` importado** (hallazgo 12) | Todo el plan de recordatorios gratis depende de esas alarmas. Si no suenan, el paciente no recibe ningún aviso | Probarlo en celulares reales antes de vender el piloto. El archivo generado cumple RFC 5545, pero eso no garantiza que el calendario lo respete |
| **El número de WhatsApp conectado a Cloud API puede no servir en la app normal** (hallazgo 13) | Puede obligar a usar un número exclusivo para la plataforma | Verificarlo con la cuenta de Meta antes de elegir el número |
| **El motivo de consulta puede ser dato de salud sensible** (hallazgo 14) | La Ley 29733 exige más cuidado con estos datos, y hay que inscribir el banco de datos ante la ANPD | Revisión de un abogado. El texto de privacidad incluido es un borrador |

## 2. Hallazgos y decisiones

Lo que el documento dejaba abierto se resolvió así. Cada punto se puede cambiar.

### Huecos en la API y el modelo

1. **Rutas que faltaban en la lista del documento.** Se agregaron rechazar, reprogramar (público y doctor),
   `sin-whatsapp`, `/citas/disponibilidad`, `/citas/por-aprobar`, `/agenda/semana`, `/bloqueos/impacto`,
   `/pacientes/{id}` y la disponibilidad pública para mover una cita. Los requerimientos las necesitan.
2. **Más de "10 tablas".** Se suman `SesionRenovacion` e `IntentoReserva`, además de las tablas de `django_q`.
3. **Campos agregados.** `Cita.fin_ocupado`, `minutos_extra` y `nombre_ingresado`; `Tratamiento.slug` y `descripcion`;
   `Consultorio.doctor_nombre` y `activo`; `Paciente.consentimiento_en`; campos de bloqueo en `Usuario`.

### Reglas de negocio

4. **+10 y +20 min no modifican el rango reservado.** Si lo hicieran, chocarían con la restricción de exclusión de la
   base en cuanto la cita alcanzara a la siguiente. El retraso se guarda aparte, en `minutos_extra`, y solo afecta a la
   hora estimada.
5. **Expiración perezosa.** La tarea corre cada minuto, lo que no basta para cumplir "a los 15 min" con exactitud. Por
   eso una pre-reserva vencida deja de ocupar el horario desde el instante en que vence, aunque la tarea aún no pase.
6. **Un nombre sin verificar no sobrescribe a un paciente.** Si no, cualquiera podría cambiar el nombre de otra persona
   escribiendo su celular. Por eso existe `nombre_ingresado`.
7. **Vencimiento de "por aprobar".** El documento no lo define. Aquí vence cuando llega su hora.
8. **Margen entre citas.** Se usa `max(tratamiento.margen_min, reglas.margen_entre_citas_min)`. El margen puede pasar
   de la hora de cierre; la cita en sí no.
15. **Las citas por teléfono dejaban al paciente sin enlace ni calendario.** `POST /citas` ahora devuelve `whatsapp_url`
    y la app ofrece enviárselo con un toque.
16. **El token de gestión es aleatorio, no firmado.** El documento dice "enlace firmado". Se usó un token opaco de
    256 bits: es igual de seguro y permite revocarlo y vencerlo desde la base.
17. **"No vino" pide confirmación y no se puede deshacer.** Suma una inasistencia al historial del paciente.

### Infraestructura

9. **Certificado comodín.** Los certificados automáticos de Caddy para `*.dominio` requieren un módulo de DNS que la
   imagen oficial no trae. Se usa un Cloudflare Origin Certificate, gratis y con 15 años de vigencia.
10. **Cloudflare no guarda HTML por defecto.** Hace falta una Cache Rule; está en `deploy/README.md`. Sin ella, el
    sitio no aprovecha la caché.
11. **Suplantación de `CF-Connecting-IP`.** Si el servidor acepta tráfico directo, cualquiera puede falsear su IP y
    saltarse el límite por hora. Además, Docker abre puertos saltándose `ufw`. El origen debe aceptar solo a Cloudflare.

## 3. Trazabilidad de requerimientos

"Automática" significa que hay pruebas que lo comprueban. "E2E" significa que también se recorrió en un navegador
contra el backend real. Los estados "Parcial" y "Sin probar" se explican en la sección 4.

| RF | Tema | Código | Pruebas | Estado |
| --- | --- | --- | --- | --- |
| 01-04 | Perfil, tratamientos, ubicación, botón fijo | `sitio/` | `test_sitio_y_tareas`, `test_reserva` | Automática + E2E |
| 05-07 | Motivo, días y horas, datos | `agenda/motor.py`, `citas/servicios.py`, `sitio/static/sitio/reserva.js` | `test_motor`, `test_reserva` | Automática + E2E |
| 08 | Pre-reserva de 15 min, sin doble reserva | `citas/models.py` (restricción), `citas/servicios.py` | `test_concurrencia` (12 hilos) | Automática |
| 09-10 | Código y webhook de WhatsApp | `mensajeria/webhook.py` | `test_whatsapp_y_mi_cita` | **Desactivado** (sección 7). Con `VERIFICACION_WHATSAPP=1`: webhook firmado simulado, Meta real sin probar |
| 11 | Expiración | `citas/servicios.py`, `mensajeria/tareas.py` | `test_sitio_y_tareas`, `test_confirmacion_manual` | Automática. Sin verificación, la reserva retiene el horario hasta su hora |
| 12 | Pantalla final y `.ics` | `citas/ics.py`, `sitio/` | `test_estimacion_ics` | Parcial: archivo validado, alarmas en celular sin probar |
| 13, 29 | Por confirmar: el doctor confirma y avisa | `citas/servicios.py`, `por_aprobar_pantalla.dart` | `test_confirmacion_manual`, `app_test` | Automática + E2E |
| 14 | Mi cita: ver estado | `citas/api_publica.py`, `sitio/static/sitio/cita.js` | `test_whatsapp_y_mi_cita`, `test_confirmacion_manual` | Automática + E2E |
| 15-16 | Cancelar y reprogramar | Solo el doctor (sección 7); el enlace del paciente es de solo lectura | `test_confirmacion_manual` | Automática + E2E |
| 17 | Turnstile | `mensajeria/turnstile.py` | `test_reserva` | Parcial: Cloudflare real sin probar |
| 18-19 | Límites y números bloqueados | `citas/servicios.py` | `test_reserva`, `test_doctor` | Automática |
| 20 | Sesión y bloqueo tras 5 fallos | `consultorios/autenticacion.py`, `features/auth/` | `test_doctor`, `app_test` | Automática + E2E |
| 21-22 | Hoy y botones de consulta | `citas/estimacion.py`, `hoy_pantalla.dart` | `test_doctor`, `test_estimacion_ics`, `app_test` | Automática + E2E. Los 2 s en 4G, sin medir |
| 23 | Cita por teléfono | `nueva_cita_pantalla.dart` | `test_doctor`, `app_test` | Automática + E2E |
| 24 | Semana | `semana_pantalla.dart` | `test_doctor` | Automática + E2E |
| 25-27 | Horario, bloqueos, tratamientos | `agenda/api.py`, `features/configuracion/` | `test_doctor` | Automática |
| 28 | Pacientes | `pacientes_pantalla.dart` | `test_doctor` | Automática |
| 30 | Avisar con un toque | `acciones_cita.dart`, `citas/presentacion.py` | `test_doctor` | Automática |
| 31-32 | Push y resumen de las 8 p. m. | `mensajeria/push.py`, `mensajeria/tareas.py` | `test_sitio_y_tareas` | Parcial: FCM real sin probar |
| 33 | Alta de consultorio | `consultorios/admin.py` | `test_sitio_y_tareas` | Automática. El tiempo de alta, sin medir |
| 34 | Auditoría | `citas/models.py` (`EventoCita`) | `test_doctor` | Automática |

| RNF | Tema | Evidencia | Estado |
| --- | --- | --- | --- |
| 01 | Costo | Cuentas del documento revisadas; precios no reconsultados | Sin probar |
| 02 | Peso y velocidad web | 24.2 KB sin comprimir; LCP local de 124 ms, no en 4G | Parcial |
| 03 | p95 < 300 ms con 20 usuarios | p95 de 49.9 ms y 0 % de fallos, con 40 680+ citas, **en esta PC, no en el VPS** | Parcial |
| 04 | Capacidad | Volumen de datos cubierto en la prueba anterior; servidor real sin probar | Parcial |
| 05, 15 | Disponibilidad y portabilidad | `/salud/` y guía de monitoreo; Docker nunca ejecutado | Sin probar |
| 06 | Respaldos | `pg_dump` → `openssl` → `pg_restore` dio conteos idénticos, con comandos manuales. `respaldar.sh` y `restaurar.sh` no se ejecutaron | Parcial |
| 07 | Seguridad | Argon2, token de 15 min, renovación rotativa: pruebas automáticas. HTTPS depende del despliegue | Parcial |
| 08 | Aislamiento | `test_aislamiento` intenta cruzar datos en todas las rutas con id | Automática |
| 09 | Privacidad | Consentimiento y borrado a pedido probados; falta revisión legal | Parcial |
| 10, 13 | Usabilidad y accesibilidad del paciente | Confirmación a los 2.9 s en E2E (un robot, no una persona); sin objetivos < 44 px | Parcial |
| 11 | Uso del doctor con una mano | Botones ≥ 44 px probados; sin celular físico | Parcial |
| 12 | Compatibilidad | Chrome de escritorio a 360 px; APK de depuración compilado, **nunca instalado**. Safari, sin probar | Parcial |
| 14 | Mantenibilidad | Cobertura del motor de agenda: 99 % | Automática |
| 16 | Observabilidad | Logs estructurados y Sentry opcional; envío real sin probar | Parcial |
| 17 | Hora de Perú | UTC en base y Lima en cálculos, con reloj fijo en las pruebas | Automática |
| 18 | API versionada | `/public/v1` y `/api/v1` | Automática |

## 4. Lo que falta verificar

Nada de esto se pudo probar en este equipo, porque requiere cuentas, servicios o aparatos reales:

- **Despliegue:** Docker Compose y Caddy nunca se ejecutaron (no hay Docker aquí). Es lo primero a probar en el VPS.
- **Servicios externos:** webhook real de Meta, Turnstile real, push real por FCM, envío a Sentry.
- **Respaldos:** `respaldar.sh` y `restaurar.sh` con `rclone` hacia R2.
- **Celulares:** instalar el APK en un Android real, y probar el sitio en Android 10+ y en iPhone con Safari 15+.
- **Alarmas del `.ics`** en Google Calendar y en Apple Calendar (ver sección 1).
- **Rendimiento real:** carga contra el VPS y LCP en 4G con un celular de gama media.
- **Personas:** el criterio de reservar en menos de 60 s se midió con un robot, no con pacientes.
- **Precios:** no se volvieron a consultar los del documento.

## 5. Especificación del sitio web

`Sitio_Web_Consultorio_Especificacion_MVP.pdf` está implementada: 11 secciones, reserva de 4 pasos dentro de la página,
"Mis citas", aviso de próximo horario, SEO, CSP, caché con purga, fotos a WebP y medición (`manage.py metricas_sitio <slug>`
y panel del consultorio).

Decisiones y desviaciones:

- **14 o 30 días.** La tira muestra 14 días y "Ver más días" llega a 30, para cumplir RF-06 y la especificación.
- **Colores de la guía que no cumplen WCAG AA (RWN-06).** Blanco sobre coral da 2.94:1 y slate `#7a7a7a` da 4.29:1 sobre
  blanco. Por eso el texto sobre coral es `#06140c` (6.41:1) y el texto secundario usa graphite.
- **Continuar "desactivado"** usa `aria-disabled`: se ve desactivado, pero al tocarlo explica qué falta.
- **Google Fonts** es lo que pide la especificación, pero envía la IP del visitante a Google (RWN-09). Alojar la fuente
  en el propio servidor lo evitaría.
- **HSTS** lo pone Caddy, que no se ha ejecutado; CSP lo pone Django y sí está probado.
- **"Atendiendo ahora"** usa el horario habitual: no considera bloqueos puntuales.
- **Enlace de la cita.** Ahora es `/c/<token>/`; `/cita/<token>/` sigue funcionando.
- **Eventos de medición.** `POST /eventos` acepta hasta 120 por IP y hora, contados en memoria para no guardar la IP.
  Con varios procesos de Gunicorn el límite es por proceso: frena el abuso casual, no uno decidido.

| RW / RWN | Dónde | Prueba |
| --- | --- | --- |
| RW-01 subdominio, 404, sin publicar | `sitio/middleware.py`, `sitio/views.py` | `test_sitio_web` |
| RW-02 estado de atención | `sitio/static/sitio/pagina.js` | E2E con reloj fijo (4 casos) |
| RW-03 doctor, monograma, colegiatura | `consultorio.html`, `Consultorio.iniciales_doctor` | `test_sitio_web` |
| RW-04, RW-05 tratamientos y «Reservar este» | `consultorio.html`, `reserva.js` | `test_sitio_web` + E2E |
| RW-06 reservar a un toque | barra fija y aviso | E2E a 360 px |
| RW-07 próximo horario libre | `pagina.js` | E2E: coincide con la primera hora de evaluación |
| RW-08 a RW-10 reserva de 4 pasos | `reserva.js`, `comun.js` | E2E: Volver y validaciones. El paso 4 ahora es «Reserva recibida» (sección 7) |
| RW-11 Google Calendar y .ics | `comun.js`, `citas/ics.py` | E2E + `test_estimacion_ics` |
| RW-12 Mis citas | `reserva.js` | E2E: estado (Por confirmar / Confirmada) y «Escribir al consultorio» |
| RW-13 a RW-15 horario, copiar, Maps | `consultorio.html`, `pagina.js` | `test_sitio_web` + E2E |
| RW-16 uso de datos | pie y paso 3 | `test_sitio_web` + E2E |
| RWN-01 peso | gzip 150 KB, JS < 60 KB, fotos WebP ≤ 150 KB | `test_sitio_web` |
| RWN-02 velocidad | CLS 0.048 y LCP de 496 ms en local | E2E (no en 4G) |
| RWN-03 si la API falla | `reserva.js` | E2E con la API respondiendo 500 |
| RWN-04, RWN-05 SEO y Open Graph | `consultorio.html`, `sitemap.xml`, `robots.txt` | `test_sitio_web` |
| RWN-06 accesibilidad | contraste medido en la página, objetivos ≥ 44 px | E2E |
| RWN-07 adaptable | sin desplazamiento horizontal a 360, 768, 1024 y 1440 px | E2E |
| RWN-10 seguridad | CSP con hash, sin `unsafe-inline` | `test_sitio_web` |
| RWN-11 idioma | «sábado 7 de nov, 10:00 a. m.» | E2E |

Falta verificar: purga real de Cloudflare, Cloudflare Web Analytics, Android e iPhone reales, LCP e INP en 4G, y que la
fuente de Google incluya el juego `ss03`.

## 6. Corrección de concurrencia

Reservas simultáneas que se cruzaban podían provocar `deadlock detected` en PostgreSQL al revisar la restricción de
exclusión: nunca hubo doble reserva, pero los pacientes recibían un error 500. Falló 1 vez en 14 vueltas de la prueba.
Ahora las escrituras de horarios de cada consultorio pasan por `pg_advisory_xact_lock`: 60 vueltas sin fallos ni
deadlocks en el log.

## 7. Confirmación manual por WhatsApp (sin API de Meta)

Por ahora no se puede conseguir la API de WhatsApp. El contacto con el paciente pasa al WhatsApp del doctor: la app
arma el mensaje y abre WhatsApp con el número del paciente, y el doctor solo toca Enviar. El costo sigue en cero.

| Momento | Qué pasa | Dónde |
| --- | --- | --- |
| El paciente reserva | La cita queda **por confirmar** y retiene el horario hasta su hora. El sitio dice «el consultorio te escribirá por WhatsApp». El doctor recibe un push | `crear_prerreserva`, `reserva.js` |
| El doctor confirma | «Confirmar y avisar» confirma la cita y abre WhatsApp con un texto según el tratamiento: fecha en palabras, nombre del doctor, indicaciones y enlace de la cita | `aviso_al_paciente`, `por_aprobar_pantalla.dart` |
| El doctor rechaza | El horario se libera y el mensaje ofrece el enlace para reservar otro | `rechazar` |
| Recordatorios | A las 8 p. m. el push «Agenda de mañana… toca para enviar los recordatorios» abre la pantalla Recordatorios: «Enviar» (WhatsApp ya escrito) y «Confirmó» por paciente | `GET /citas/recordatorios`, `recordatorios_pantalla.dart` |
| Cancelar o «No vino» | Además del aviso al paciente, se ofrece escribir a los siguientes pacientes de ese día: «Se liberó un espacio…, ¿te gustaría venir antes?» | `siguientes_para_adelantar` |
| Cambios del paciente | El enlace y «Mis citas» son de solo lectura y ofrecen «Escribir al consultorio». Las rutas públicas de cancelar y reprogramar ya no existen | `api_publica.py`, `cita.js` |
| Sesión del doctor | El token de renovación dura 365 días y se renueva en cada uso. La app solo cierra sesión con un 401 definitivo, nunca por falta de señal | `TOKEN_RENOVACION_DIAS`, `core/api.dart` |
| Duración real | Cada tratamiento muestra la mediana de las últimas 20 citas terminadas (Iniciar → Terminar) y el botón «Usar este tiempo» | `GET /tratamientos`, `tratamientos_pantalla.dart` |
| Vista de mes | Semana / Mes: cuántas citas tiene cada día, las por confirmar y los bloqueos. Tocar un día abre esa semana | `GET /agenda/mes`, `semana_pantalla.dart` |

**Interruptor.** `VERIFICACION_WHATSAPP=1` devuelve el flujo con código: webhook de Meta, simulador en desarrollo,
cuenta regresiva de 15 minutos y «No tengo WhatsApp». Con el interruptor apagado (por defecto), el webhook y el
simulador responden 404 y `check --deploy` no pide los secretos de Meta. La migración `citas.0004` pasa a «por
confirmar» las pre-reservas pendientes.

**Lo que cambia en el riesgo.** Ya no se comprueba que el número sea del paciente. Siguen Turnstile, el límite por IP,
2 citas futuras por número y los números bloqueados. Además, un número falso queda en evidencia cuando no responde al
doctor, que rechaza la reserva y libera el horario. Una reserva que nadie confirma retiene el horario hasta su hora: es
lo que eligió el usuario para no perder pacientes reales que tardan en responder.

**Pruebas.**
- Backend: `test_confirmacion_manual.py` (25 pruebas). Las pruebas del flujo con código corren con la marca
  `verificacion_whatsapp`. En total son 344 pruebas.
- App: `app_test.dart`, con Confirmar y avisar, Recordatorios, avisar al siguiente tras «No vino», «Usar este tiempo»
  y vista de mes. En total son 30 pruebas.
- E2E con Chrome:
  - El paciente reserva y ve «Reserva recibida».
  - El doctor confirma en la app web y se abre WhatsApp con el número y el texto correctos.
  - El enlace del paciente pasa a «Confirmada».
  - El doctor cancela y avisa al siguiente.

**Falta probar.** Que `wa.me` abra la app de WhatsApp en un Android real, con el APK y con el texto completo.

## 8. Plataforma multinegocio y mejoras del análisis RYJEC

El sistema dejó de ser solo para dentistas. Los nombres internos (`Consultorio`, `Paciente`, `Tratamiento`) no se
renombraron porque sería una migración grande sin beneficio para el usuario. En pantalla, cada negocio usa su
vocabulario.

| Tema | Qué se hizo | Dónde |
| --- | --- | --- |
| Tipos de negocio | Odontología, barbería, peluquería, estética, salud, veterinaria y «otro». Cada tipo trae su vocabulario, sus servicios con precio de referencia, su horario, su color, sus minutos de llegada anticipada y sus preguntas frecuentes | `consultorios/rubros.py` |
| Panel propio | Lista con estado y vencimiento, un asistente «Nuevo negocio» que empieza por el tipo, y una ficha con pestañas: sitio, servicios, horario, equipo y cuentas, opciones y servicio. Suspender nunca cancela citas. Exporta CSV y deja auditoría en `EventoPanel` | `panel/` |
| Varias cuentas y profesionales | Por negocio, la agenda puede ser **compartida** o **un profesional por cuenta** (varios barberos en paralelo). El cliente elige con quién o «Cualquiera», que asigna al profesional libre con menos citas. La restricción contra cruces es por profesional | `Profesional`, `cita_sin_cruces` |
| Precio ofertable (tipo InDrive) | Se activa por negocio. El cliente ofrece un precio de hasta 2 veces la referencia, y al confirmar el negocio acepta la oferta o pone el precio final. El precio queda fijado en la cita | `crear_prerreserva`, `aprobar`, `acciones_cita.dart` |
| Espera y confirmación | La pantalla final dice «Espera la confirmación» y muestra todos los datos. El WhatsApp de confirmación lleva servicio, profesional, precio, dirección, mapa, «llegar N min antes» y las indicaciones | `reserva.js`, `texto_para_paciente` |
| Sesión web sin cuenta | El navegador recuerda el nombre, el celular y «Mis citas» durante 30 o 60 min (configurable) y luego los borra. La app mantiene su sesión de 365 días | `comun.js` (`sesionWeb`) |
| Idempotencia (mejora 1) | Cabecera `Idempotency-Key` en reservar y en cada acción de la app. Un reintento devuelve la misma respuesta. La app repite una vez, con la misma clave, si se corta la red | `denticita/idempotencia.py`, `core/api.dart` |
| Recordar pendientes (2) | Push «Tienes N reservas por confirmar» a las `recordar_pendientes_horas` y en la víspera | `tareas.recordar_pendientes` |
| «Llegó» y tolerancia (3, 6) | Botón «Llegó». «No vino» solo se habilita pasados N min de la hora, y el servidor también lo valida | `marcar_llegada`, `hoy_pantalla.dart` |
| Bloqueo local (7) | Huella o PIN del teléfono al abrir la app y al volver tras 5 min. Además, «Cerrar sesión en todos los equipos» | `bloqueo.dart`, `POST /auth/cerrar-todas` |
| Mi mes (9) | % de confirmación, % de inasistencia, ocupación, mediana de respuesta y de espera, y clientes que vuelven, frente al mes anterior | `sitio/metricas.kpis`, `GET /metricas` |
| Outbox de push (10) | Cada aviso se guarda primero en `AvisoPendiente`, con una clave que evita duplicados. Se reintenta a 1, 5, 15 y 60 min, y va al profesional de la cita y a los encargados | `mensajeria/push.py` |
| Impacto de horario (11) | Antes de guardar un horario nuevo, lista las citas que quedan fuera, cada una con su WhatsApp listo. Nada se cancela solo | `POST /horario/impacto` |
| Auditoría (12) | Cada `EventoCita` guarda el origen (app, sitio, panel o sistema) y el `request_id`, que también sale en los logs y en la cabecera `X-Request-ID` | `denticita/contexto.py` |
| Simulacro (13) | Restaura la última copia en una base temporal, compara conteos y la borra, sin tocar producción | `deploy/simulacro_restauracion.sh` |
| Piloto y privacidad (14, 15) | Protocolo por tipo de negocio, con metas y criterios para seguir o parar. La política de datos usa el vocabulario y, en negocios de salud, advierte no escribir datos de salud | `docs/PILOTO.md`, `privacidad.html` |
| Adelantos (Fase E) | Registrar, verificar y devolver pagos por Yape, Plin, efectivo o transferencia. **Están apagados**: con `PAGOS_ADELANTADOS=0` sus rutas responden 404 y el panel muestra la opción deshabilitada | `citas/adelantos.py` |

**Sin API de WhatsApp.** Toda la comunicación sigue saliendo del WhatsApp del negocio con `wa.me`.

**Migración de datos existentes.** Se probó contra una base con 40 721 citas. La migración se divide en tres:
`0006` (esquema), `0006a` (datos) y `0006b` (NOT NULL y restricción). PostgreSQL no permite crear índices ni alterar
una tabla en la misma transacción en que se actualizaron sus filas, y en un solo paso la actualización fallaba con
datos reales aunque las pruebas, que empiezan con la base vacía, pasaban.

**Pruebas.**
- Backend: 435 pruebas. Incluyen el aislamiento entre negocios, que ahora también cubre las rutas de adelantos.
- App: 42 pruebas. Cubren vocabulario, filtro de profesional, oferta de precio, «Llegó», tolerancia, Mi mes, bloqueo e
  `Idempotency-Key`.
- E2E con Chrome, 32 comprobaciones:
  1. El panel crea una barbería con 2 barberos y la publica.
  2. Se reserva con «Cualquiera» ofreciendo S/ 18.
  3. La app acepta la oferta y el WhatsApp lleva precio, barbero, dirección y llegada.
  4. Se suspende: el sitio deja de reservar y la cita sigue programada.
  5. El sitio dental de demostración sigue igual.

**Falta probar en un Android real.**
- La huella o el PIN, porque cambió la `MainActivity` a `FlutterFragmentActivity`.
- Que `wa.me` abra WhatsApp con el texto completo.

## 9. RyCitas: sitios propios, reserva interactiva y app nueva

El sistema se llama **RyCitas**: así aparece en la app, el panel, los sitios, la API y el `.ics`. Por dentro no
cambiaron nombres: el módulo `denticita`, el paquete Android, la base y las cuentas demo `@denticita.test` siguen
iguales. Cambiarlos rompería las instalaciones y las sesiones que ya existen.

| Tema | Qué se hizo | Dónde |
| --- | --- | --- |
| Sitio propio por negocio | `Consultorio.sitio_propio` apunta a un sitio compilado en `backend/sitios_propios/<nombre>/`. Se sirve en el subdominio, con fallback de SPA, caché larga para los assets y su propia política de contenido. Las rutas de RyCitas siempre ganan. Se elige en el panel (pestaña Sitio) | `sitio/propios.py`, `scripts/sitio.ps1` |
| Widget | `/rycitas.js` abre la reserva encima de cualquier sitio. Se activa con `data-rycitas-reservar` o con cualquier enlace a `/reservar/`. Es una hoja a pantalla completa en el celular y un modal en la PC, y se cierra con ×, Escape o «atrás». Se comunica con el sitio por `postMessage` | `sitio/static/sitio/rycitas.js` |
| Enlace directo | `/reservar/` es la reserva sola, primero para el celular. Acepta `?servicio=` y `&con=`. El panel muestra el enlace para compartirlo | `reservar.html`, `reservar.css` |
| Reserva más interactiva | Tarjetas de servicio con duración y precio, avatares de profesionales y tira de días deslizable. Horas en chips por mañana, tarde y noche. Resumen fijo abajo, esqueletos de carga, validación en vivo del WhatsApp, transiciones entre pasos y check animado al terminar. Respeta «reducir movimiento». El color de acento es el del negocio, con texto blanco o negro según el contraste | `reserva.js` |
| GlowClinic | El sitio de belleza `visage-artisan-hub` ya está integrado. Sus botones «Agendar» abren RyCitas con el tratamiento elegido, y el formulario simulado se reemplazó por la reserva real. `crear_demo` crea el negocio | `sitios/visage-artisan-hub` |
| App rediseñada | Estilo moderno claro con modo oscuro automático. Tipografía Plus Jakarta Sans empaquetada, tarjetas de 20 px y el color del negocio. La pantalla Hoy tiene encabezado, métricas rápidas, línea de tiempo con avatares y chips de estado, y un panel inferior para la siguiente cita. «Por confirmar» usa tarjetas grandes; Ajustes se agrupa en tarjetas; Mi mes tiene barras. La barra inferior muestra una insignia con las reservas pendientes. El login lleva la marca. La lógica no cambió | `core/tema.dart`, `shared/comunes.dart` |
| Marca | Logo de calendario con check, favicon del sitio y del panel, íconos de Android y de la app web | `rycitas-logo.svg`, `mipmap-*` |

**Pruebas.**
- Backend: 455 pruebas. Las 20 nuevas cubren `/reservar/`, el widget, el sitio propio (fallback, caché, rutas con
  `..`, rutas de RyCitas que ganan, aislamiento entre negocios) y el selector del panel.
- App: 42 pruebas.
- E2E con Chrome en tamaño celular, 15 comprobaciones:
  1. El sitio de GlowClinic carga y «Agendar» abre la reserva encima del sitio, con el servicio preseleccionado.
  2. Se reserva hasta la pantalla de espera.
  3. La × y el gesto «atrás» cierran la reserva.
  4. Funcionan el enlace directo y `?servicio=`.
  5. En la PC la reserva es un modal.
  6. `sonrisa-wari` sigue con su landing.

  El E2E multinegocio anterior (32 comprobaciones) sigue pasando.

**Falta revisar en un Android real** el aspecto de la app nueva, cuando el teléfono permita instalar por USB.
