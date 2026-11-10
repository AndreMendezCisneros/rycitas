/* Mi cita, de solo lectura: estado, hora estimada y calendario. Cambiar o cancelar se pide al consultorio por WhatsApp. */
"use strict";

(() => {
  const { el, hora, fechaLarga, api, config, mostrarError, enlaceGoogleCalendar } = window.dc;
  const cfg = config();
  const raiz = document.getElementById("cita");
  const rutaApi = `/public/v1/citas/${cfg.token}`;
  let temporizador = null;
  let ultimoEstado = null;
  let vencimiento = null;

  const vocDe = (c) => c.consultorio.vocabulario || { servicio: "motivo", el_local: "el consultorio" };
  const mayuscula = (texto) => texto.charAt(0).toUpperCase() + texto.slice(1);
  /** «al consultorio», «a la barbería». */
  const alLocal = (c) => {
    const local = vocDe(c).el_local;
    return local.startsWith("el ") ? `al ${local.slice(3)}` : `a ${local}`;
  };

  /** Todos los datos de la cita, los mismos del WhatsApp de confirmación. */
  function resumen(c) {
    const referencias = c.consultorio.referencias ? ` (${c.consultorio.referencias})` : "";
    const filas = [
      ["Nombre", c.paciente],
      [mayuscula(vocDe(c).servicio), c.duracion_min ? `${c.tratamiento} · ${c.duracion_min} min` : c.tratamiento],
      c.profesional && ["Con", c.profesional],
      ["Fecha", `${fechaLarga(c.inicio)}, ${hora(c.inicio)}`],
      c.precio_texto && ["Precio", c.precio_texto.replace(/^[^:]+: /, "")],
      ["Lugar", `${c.consultorio.nombre}, ${c.consultorio.direccion}${referencias}`],
      c.hora_llegada && ["Llega", `${c.llegar_antes_min} min antes, a las ${c.hora_llegada}`],
    ].filter(Boolean);
    return el("div", { class: "tarjeta" },
      el("dl", { class: "resumen" }, filas.flatMap(([dt, dd]) => [el("dt", {}, dt), el("dd", {}, dd)])),
      c.consultorio.mapa_url && el("a", { href: c.consultorio.mapa_url, target: "_blank", rel: "noopener" }, "Ver en Google Maps"),
    );
  }

  const botonConsultorio = (c, texto = `Escribir ${alLocal(c)}`) =>
    el("a", { class: "boton boton-bloque", href: `https://wa.me/${c.consultorio.whatsapp}`, rel: "noopener" }, texto);

  const notaCambios = (c) => el("div", { class: "pila" },
    el("p", { class: "dato" }, `¿Necesitas cambiar o cancelar tu cita? Escríbele ${alLocal(c)} por WhatsApp.`),
    botonConsultorio(c),
  );

  function minutosRestantes(c) {
    return Math.max(0, Math.ceil((new Date(c.expira_en) - Date.now()) / 60000));
  }

  /** Solo con la verificación por WhatsApp activa (VERIFICACION_WHATSAPP=1). */
  function vistaPendiente(c) {
    vencimiento = el("span", {}, `${minutosRestantes(c)} min`);
    const hijos = [
      el("p", { class: "dato" }, "Paso 4 de 4"),
      el("h1", {}, "Confirma tu cita por WhatsApp"),
      el("p", {}, "Toca el botón y envía el mensaje tal como aparece. No cuesta nada y no tienes que escribir nada."),
      el("div", { class: "pila" },
        el("a", { class: "boton boton-principal boton-bloque", href: c.whatsapp_url, target: "_blank", rel: "noopener" }, "Confirmar por WhatsApp"),
      ),
      el("p", { class: "espera", "aria-live": "polite" }, "Esperando tu mensaje"),
      el("p", { class: "dato" }, "Tu código es ", el("strong", {}, c.codigo), ". Guardamos tu horario por ", vencimiento, "."),
      resumen(c),
    ];
    if (cfg.demo) {
      hijos.push(el("div", { class: "aviso" },
        el("p", {}, "Modo de prueba: simula el mensaje de WhatsApp sin una cuenta de Meta."),
        el("button", { class: "boton boton-bloque", type: "button", id: "simular", onclick: simular }, "Simular mensaje de WhatsApp"),
      ));
    }
    hijos.push(el("details", {},
      el("summary", {}, "No tengo WhatsApp"),
      el("p", {}, "El consultorio revisará tu solicitud y te llamará si hace falta. Tu cita queda sin confirmar hasta que la aprueben."),
      el("button", { class: "boton boton-bloque", type: "button", onclick: pedirAprobacion }, "Enviar solicitud al consultorio"),
    ));
    return hijos;
  }

  function vistaPorConfirmar(c) {
    return [
      el("div", { class: "aviso" }, "Reserva recibida · por confirmar"),
      el("h1", {}, "Te guardamos el horario: espera la confirmación"),
      el("p", {}, `${c.consultorio.nombre} te escribirá por WhatsApp para confirmar tu cita. Esta página se actualiza sola cuando la confirmen.`),
      resumen(c),
      c.hora_llegada && el("p", { class: "aviso" }, `Te pedimos llegar ${c.llegar_antes_min} min antes, a las ${c.hora_llegada}, por si acaso.`),
      notaCambios(c),
    ];
  }

  function vistaProgramada(c) {
    const hijos = [el("div", { class: "exito" }, "¡Cita confirmada!")];
    if (c.hora_estimada && c.retraso_min > 0) {
      hijos.push(el("div", { class: "aviso" },
        `${mayuscula(vocDe(c).el_local)} va con retraso. Hora estimada de atención: ${hora(c.hora_estimada)} (unos ${c.retraso_min} min). `,
        "Recarga esta página para ver la hora actualizada.",
      ));
    }
    hijos.push(
      resumen(c),
      c.hora_llegada && el("p", { class: "aviso" }, `Llega ${c.llegar_antes_min} min antes, a las ${c.hora_llegada}, por si acaso.`),
      el("div", { class: "pila" },
        el("a", { class: "boton boton-principal boton-bloque", href: enlaceGoogleCalendar(c, location.href), target: "_blank", rel: "noopener" }, "Agregar a Google Calendar"),
        el("a", { class: "boton boton-bloque", href: `${rutaApi}/calendario.ics`, download: "cita.ics" }, "Descargar archivo .ics"),
        el("p", { class: "dato" }, "El archivo .ics avisa 24 horas y 2 horas antes. Guarda este enlace para ver tu cita."),
      ),
      notaCambios(c),
    );
    return hijos;
  }

  function vistaFinal(c) {
    const textos = {
      en_curso: ["Tu atención está en curso", "Gracias por venir."],
      terminada: ["Tu cita terminó", "Gracias por tu visita."],
      expirada: ["Tu reserva venció", "El horario quedó libre. Puedes reservar de nuevo."],
      cancelada: ["Cita cancelada", `${mayuscula(vocDe(c).el_local)} canceló esta cita. Puedes reservar otro horario.`],
      no_asistio: ["No asististe a esta cita", `Si fue un error, escríbele ${alLocal(c)}.`],
    };
    const [titulo, texto] = textos[c.estado] || [c.estado_texto, ""];
    const hijos = [el("h1", {}, titulo), el("p", {}, texto), resumen(c)];
    if (["expirada", "cancelada"].includes(c.estado)) {
      hijos.push(el("div", { class: "pila" },
        el("a", { class: "boton boton-principal boton-bloque", href: "/#reservar" }, "Reservar otra cita"),
        botonConsultorio(c),
      ));
    }
    return hijos;
  }

  const VISTAS = { pendiente: vistaPendiente, por_aprobar: vistaPorConfirmar, programada: vistaProgramada };

  function pintar(c) {
    raiz.replaceChildren(...(VISTAS[c.estado] || vistaFinal)(c).filter(Boolean));
    ultimoEstado = c.estado;
  }

  async function pedirAprobacion() {
    mostrarError("");
    try {
      const c = await api(`${rutaApi}/sin-whatsapp`, { method: "POST" });
      pintar(c);
      programarConsulta(c);
    } catch (error) {
      mostrarError(error.message);
    }
  }

  async function simular() {
    await fetch(`/dev/simular-whatsapp/${cfg.token}/`, { method: "POST" });
    refrescar();
  }

  /** Cada 3 s mientras se espera el mensaje del paciente; cada 30 s mientras el consultorio no confirma. */
  function programarConsulta(c) {
    clearTimeout(temporizador);
    if (c.estado === "pendiente") temporizador = setTimeout(refrescar, 3000);
    else if (c.estado === "por_aprobar" && !document.hidden) temporizador = setTimeout(refrescar, 30000);
  }

  async function refrescar() {
    try {
      const c = await api(rutaApi);
      if (c.estado === "pendiente" && ultimoEstado === "pendiente") {
        vencimiento.textContent = `${minutosRestantes(c)} min`; // no repinta para no cerrar «No tengo WhatsApp»
        if (minutosRestantes(c) === 0) pintar({ ...c, estado: "expirada", estado_texto: "Expirada" });
      } else if (c.estado !== ultimoEstado) {
        pintar(c);
      }
      programarConsulta(c);
    } catch (error) {
      if (error.status === 410 || error.status === 404) {
        raiz.replaceChildren(el("h1", {}, "Enlace no disponible"), el("p", {}, error.message));
      } else {
        temporizador = setTimeout(refrescar, ultimoEstado === "pendiente" ? 3000 : 30000);
      }
    }
  }

  // Al volver de WhatsApp el celular suele reanudar la pestaña: se revisa de inmediato.
  document.addEventListener("visibilitychange", () => { if (!document.hidden) refrescar(); });

  refrescar();
})();
