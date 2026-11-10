# Protocolo de piloto por tipo de negocio

Adaptado del protocolo de piloto del expediente RYJEC. El objetivo es comprobar, con negocios reales y sin API de
WhatsApp, que la reserva por la web y la confirmación manual funcionan día a día.

## 1. Quién entra al piloto

| Tipo | Cuántos | Por qué |
| --- | --- | --- |
| Odontología | 2 | Es el caso original: citas largas, indicaciones previas y datos sensibles |
| Barbería | 2, al menos una con 2 o 3 barberos | Prueba la agenda por profesional, «Cualquiera» y el precio ofertable |
| Peluquería o estética | 1 | Servicios largos (ondulado, tinte) y la tolerancia de inasistencia |

Cada negocio necesita lo siguiente:
- Un dueño o encargado con Android y WhatsApp en el mismo celular.
- Al menos 15 citas por semana.
- La disposición de responder las reservas en menos de 2 horas.

## 2. Alta (30 minutos por negocio)

1. Panel → **Nuevo negocio**. Se elige el tipo y se revisan los servicios, precios y horario precargados con el dueño
   al lado.
2. Modo de agenda:
   - Usa **compartida** si atiende una persona o una recepción maneja todo.
   - Usa **un profesional por cuenta** si varios atienden a la vez.
3. Opciones según el tipo:

   | Opción | Dental | Barbería |
   | --- | --- | --- |
   | Llegar antes | 15 min | 5 min |
   | Tolerancia de inasistencia | 15 min | 10 min |
   | Precio ofertable | Apagado | A criterio del dueño |
   | Adelantos | Siempre apagados en el piloto | Siempre apagados en el piloto |

4. Se crea una cuenta de la app por persona y se instala el APK en su celular. La contraseña se muestra una sola vez:
   se entrega en persona, nunca por un chat.
5. **Publicar.** Se comparte el enlace en el estado de WhatsApp y en Instagram del negocio.
6. Reserva de prueba hecha por nosotros:
   - El push llega.
   - «Confirmar y avisar» abre WhatsApp con el texto completo: servicio, quién atiende, precio, dirección, mapa y «llega
     N min antes».
   - Después se rechaza para liberar el horario.

## 3. Durante el piloto (4 semanas)

- **Semana 1:** visita o llamada a los 3 días. Se revisa si el encargado entendió «Por confirmar», «Llegó» y «No vino».
- **Semanal:** captura del tablero **Mi mes** de la app, que también se ve en la ficha del negocio en el panel.
- **Lo que se anota en cada incidente:** fecha, negocio, qué pasó y el `request_id`. El encargado lo encuentra en el
  historial de la cita y nosotros en los logs.

## 4. Indicadores y umbrales

| Indicador | Dónde se ve | Meta del piloto |
| --- | --- | --- |
| Reservas web por semana | Mi mes → citas | ≥ 5 por negocio desde la semana 2 |
| % confirmación de reservas web | Mi mes | ≥ 85 % |
| Mediana de respuesta (creada → confirmada) | Mi mes | ≤ 60 min en horario de atención |
| % inasistencia | Mi mes | Bajar frente a lo que el dueño estima hoy |
| Mediana de espera (llegó → inició) | Mi mes | Solo informativa |
| Reservas sin respuesta a la hora de la cita | Panel | 0 después de la semana 1 |
| Incidentes de doble reserva | Logs y reclamos | 0 (la base lo impide) |

## 5. Criterios para seguir, ajustar o parar

- **Seguir:** se cumplen al menos 4 de las metas y el dueño quiere seguir pagando.
- **Ajustar:**
  - Si la respuesta es lenta, se baja `recordar_pendientes_horas` a 1.
  - Si hay muchas inasistencias, se evalúa encender adelantos después del piloto.
- **Parar con ese negocio:** dos semanas seguidas sin reservas web, o reservas que nadie confirma. Se suspende desde el
  panel: las citas existentes siguen en la app y se exporta el CSV de clientes y citas para el dueño.

## 6. Datos y privacidad

- Al dueño se le explica que no debe escribir diagnósticos ni datos de salud en las notas. La política de datos del
  sitio también lo advierte en los negocios de salud.
- El banco de datos debe inscribirse ante la ANPD antes de pasar de piloto a producción (Ley 29733), y un abogado debe
  revisar la política de datos.
- El primer día de cada mes corre `deploy/simulacro_restauracion.sh`. El resultado se anota en el registro del piloto.

## 7. Qué no entra en el piloto

- La API de WhatsApp: toda la comunicación sale del WhatsApp del negocio.
- Los adelantos: están desarrollados, pero `PAGOS_ADELANTADOS=0`.
- La reprogramación por propuesta, la lista de espera y la invitación a volver. Se evalúan con los datos del piloto.
