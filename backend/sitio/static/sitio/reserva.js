/* Reserva en 4 pasos dentro de la página y «Mis citas» (RW-08 a RW-12). El paciente nunca sale del sitio para reservar. */
"use strict";

(() => {
  const { el, hora, fechaLarga, api, config, mostrarError, selectorHoras, almacen, enlaceGoogleCalendar, sesionWeb } = window.dc;
  const cfg = config();
  const voc = cfg.voc || { servicio: "motivo", profesional: "profesional", el_local: "el consultorio", cliente: "paciente" };
  const opciones = cfg.opciones || {};
  const alLocal = voc.el_local.startsWith("el ") ? `al ${voc.el_local.slice(3)}` : `a ${voc.el_local}`;
  const mayuscula = (texto) => texto.charAt(0).toUpperCase() + texto.slice(1);
  const sesionDatos = sesionWeb(opciones.sesion_web_min);
  const API = `/public/v1/${cfg.slug}`;
  const seccion = document.getElementById("reservar");
  const paso = document.getElementById("paso");
  const titulo = document.getElementById("reserva-titulo");
  const pasoTexto = document.getElementById("paso-texto");
  const progreso = document.getElementById("progreso");
  const volver = document.getElementById("volver");
  const CLAVE_ACTIVA = "dc_reserva_activa";
  // Página /reservar/: la reserva sola, a pantalla completa (enlace directo o dentro del widget de un sitio propio).
  const paginaReserva = document.body.classList.contains("pagina-reservar");
  const embebida = document.body.classList.contains("embebida");
  const barraResumen = document.getElementById("rv-resumen");
  const parametros = new URLSearchParams(location.search);
  if (paginaReserva && /^#[0-9a-f]{6}$/i.test(cfg.acento || "")) {
    // El texto sobre el acento es blanco o casi negro según cuál se lea mejor (contraste WCAG).
    const canal = (i) => { const v = parseInt(cfg.acento.slice(i, i + 2), 16) / 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; };
    const luz = 0.2126 * canal(1) + 0.7152 * canal(3) + 0.0722 * canal(5);
    document.body.style.setProperty("--acento", cfg.acento);
    document.body.style.setProperty("--sobre-acento", 1.05 / (luz + 0.05) >= (luz + 0.05) / 0.05 ? "#ffffff" : "#0d1014");
  }
  const avisarAlSitio = (tipo, datos = {}) => {
    if (embebida && window.parent !== window) window.parent.postMessage({ rycitas: tipo, ...datos }, "*");
  };

  const estado = {
    motivo: null, profesional: null, inicio: null, oferta: "", acepta: false, token: null,
    nombre: sesionDatos.leer("nombre", ""), celular: sesionDatos.leer("celular", ""),
  };
  const elegirProfesional = Boolean(opciones.elegir_profesional) && (cfg.profesionales || []).length > 1;
  // Los pasos cambian según el negocio: con varios profesionales se agrega «¿Con quién?».
  const PASOS = ["motivo", ...(elegirProfesional ? ["profesional"] : []), "hora", "datos", "final"];
  const numeroDe = (nombre) => PASOS.indexOf(nombre) + 1;
  progreso.replaceChildren(...PASOS.map(() => el("li")));
  let motivos = cfg.motivos;
  let pasoActual = "motivo";
  let alVolver = null;
  let tokenTurnstile = "";
  let widgetTurnstile = null;
  let reloj = null;
  let consulta = null;

  // --- Medición -----------------------------------------------------------------------------------

  function sesion() {
    let id = almacen.leer("dc_sesion", null, "sessionStorage");
    if (!id) {
      id = crypto.randomUUID ? crypto.randomUUID() : `s-${Math.random().toString(36).slice(2, 14)}`;
      almacen.escribir("dc_sesion", id, "sessionStorage");
    }
    return id;
  }

  /** Nunca interrumpe al paciente: si falla, solo se pierde una medición. */
  function evento(tipo) {
    fetch(`${API}/eventos`, {
      method: "POST", keepalive: true, headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ tipo, sesion: sesion() }),
    }).catch(() => {});
  }

  // --- Armazón de los pasos -----------------------------------------------------------------------

  function detener() {
    clearInterval(reloj);
    clearTimeout(consulta);
    reloj = consulta = null;
  }

  function encabezar(nombre, texto, { atras = null, enfocar = true, final = false } = {}) {
    detener();
    const numero = numeroDe(nombre);
    pasoActual = nombre;
    alVolver = atras;
    pasoTexto.textContent = final ? "Listo" : `Paso ${numero} de ${PASOS.length}`;
    [...progreso.children].forEach((barra, i) => {
      barra.className = final || i + 1 < numero ? "hecho" : i + 1 === numero ? "actual" : "";
    });
    titulo.textContent = texto;
    volver.hidden = !atras;
    mostrarError("");
    paso.replaceChildren();
    // La animación de entrada se reinicia en cada paso; con «reducir movimiento» el CSS la apaga.
    paso.classList.remove("rv-entra");
    void paso.offsetWidth;
    paso.classList.add("rv-entra");
    pintarResumen(final);
    if (paginaReserva) window.scrollTo({ top: 0 });
    if (enfocar) titulo.focus({ preventScroll: true });
  }

  /** Barra fija abajo con lo elegido hasta ahora: «Corte · sáb 14 · 10:30 a. m. · S/ 20». */
  function pintarResumen(final = false) {
    if (!barraResumen) return;
    const partes = [
      estado.motivo && estado.motivo.nombre,
      estado.profesional && `Con ${estado.profesional.nombre}`,
      estado.inicio && `${fechaLarga(estado.inicio)}, ${hora(estado.inicio)}`,
      estado.motivo?.precio_desde && `desde S/ ${Number(estado.motivo.precio_desde)}`,
    ].filter(Boolean);
    barraResumen.hidden = final || partes.length === 0;
    barraResumen.replaceChildren(...partes.map((p) => el("span", { class: "rv-chip" }, p)));
  }

  const llevarALaReserva = () => (paginaReserva ? window.scrollTo({ top: 0 }) : seccion.scrollIntoView());

  /** Esqueleto mientras carga: el cliente ve la forma de lo que viene, no un texto suelto. */
  const esqueleto = (filas = 3, clase = "") => el("div", { class: `rv-esqueleto ${clase}`, "aria-hidden": "true" },
    Array.from({ length: filas }, () => el("span")));

  const iniciales = (nombre) => nombre.split(/\s+/).filter((p) => p && !/^(dra?|lic|sr|sra)\.?$/i.test(p)).slice(0, 2).map((p) => p[0]).join("").toUpperCase();

  /** Check animado de la pantalla final. */
  const checkFinal = () => el("div", { class: "rv-check", "aria-hidden": "true" });

  function escribirAlConsultorio() {
    return el("a", { class: "boton boton-bloque", href: `https://wa.me/${cfg.whatsapp}`, rel: "noopener" }, `Escribir ${alLocal} por WhatsApp`);
  }

  /** RWN-03: si la API falla, el paciente siempre tiene el WhatsApp del consultorio. */
  function falloDeServicio(error, reintentar) {
    paso.replaceChildren(escribirAlConsultorio());
    mostrarError(error.sinConexion ? error.message : "No pudimos cargar la reserva. Inténtalo de nuevo o escríbenos.", reintentar);
  }

  // --- Paso 1 -------------------------------------------------------------------------------------

  function detalleMotivo(m) {
    const precio = m.precio_desde ? ` · desde S/ ${Number(m.precio_desde)}` : "";
    return `${m.nombre} · aprox. ${m.duracion_min} min${precio}`;
  }

  const trasMotivo = () => (elegirProfesional ? pasoProfesional() : pasoHora());

  function pasoMotivo({ enfocar = true } = {}) {
    encabezar("motivo", cfg.pregunta_servicio || "¿Qué te trae por aquí?", { enfocar });
    paso.append(el("div", { class: "opciones" }, motivos.map((m) =>
      el("button", {
        class: "opcion opcion-servicio", type: "button", "aria-pressed": String(estado.motivo?.slug === m.slug),
        onclick: () => { elegirMotivo(m); trasMotivo(); },
      },
        // En /reservar/ la duración y el precio van a la derecha; en la landing, en el texto como siempre.
        el("span", { class: "opcion-texto" }, m.motivo, el("small", {}, paginaReserva ? m.nombre : detalleMotivo(m))),
        paginaReserva && el("span", { class: "opcion-meta" },
          el("span", {}, `${m.duracion_min} min`),
          m.precio_desde ? el("b", {}, `S/ ${Number(m.precio_desde)}`) : null),
      ),
    )));
  }

  function elegirMotivo(m) {
    if (estado.motivo?.slug !== m.slug) {
      estado.inicio = null;
      estado.profesional = null;
    }
    estado.motivo = m;
    evento("paso_1");
  }

  // --- ¿Con quién? (solo con varios profesionales) ------------------------------------------------

  const atiende = (p, motivo) => !p.servicios || p.servicios.includes(motivo.slug);

  function pasoProfesional() {
    encabezar("profesional", "¿Con quién?", { atras: () => pasoMotivo() });
    const elegir = (p) => {
      if (estado.profesional?.id !== p?.id) estado.inicio = null;
      estado.profesional = p;
      pasoHora();
    };
    const disponibles = cfg.profesionales.filter((p) => atiende(p, estado.motivo));
    paso.append(el("div", { class: "opciones" },
      el("button", { class: "opcion opcion-persona", type: "button", "aria-pressed": String(estado.profesional === null), onclick: () => elegir(null) },
        el("span", { class: "rv-avatar rv-avatar-todos", "aria-hidden": "true" }, "★"),
        el("span", { class: "opcion-texto" }, "Cualquiera", el("small", {}, "Te asignamos al primero libre: más horarios para elegir"))),
      disponibles.map((p) => el("button", {
        class: "opcion opcion-persona", type: "button", "aria-pressed": String(estado.profesional?.id === p.id), onclick: () => elegir(p),
      },
        p.foto ? el("img", { class: "rv-avatar", src: p.foto, alt: "", width: "44", height: "44" }) : el("span", { class: "rv-avatar", "aria-hidden": "true" }, iniciales(p.nombre)),
        el("span", { class: "opcion-texto" }, p.nombre, p.detalle ? el("small", {}, p.detalle) : null))),
    ));
  }

  // --- Paso 2 -------------------------------------------------------------------------------------

  async function pasoHora(avisoPrevio = "") {
    encabezar("hora", "¿Cuándo puedes venir?", { atras: () => (elegirProfesional ? pasoProfesional() : pasoMotivo()) });
    evento("paso_2");
    paso.append(el("p", { class: "dato" }, "Buscando horarios libres…"), esqueleto(4, "rv-esqueleto-dias"), esqueleto(6, "rv-esqueleto-horas"));
    const conQuien = estado.profesional ? `&profesional=${estado.profesional.id}` : "";
    try {
      const { dias } = await api(`${API}/disponibilidad?motivo=${encodeURIComponent(estado.motivo.slug)}&dias=${cfg.dias_maximos}${conQuien}`);
      if (pasoActual !== "hora") return;
      if (cfg.acepta_reservas === false) {
        paso.replaceChildren(el("p", {}, `Por ahora las reservas en línea no están disponibles. Escríbele ${alLocal} y te atienden.`), escribirAlConsultorio());
        return;
      }
      selectorHoras(paso, dias, (inicio) => { estado.inicio = inicio; pasoDatos(); }, { maximo: cfg.dias_maximos, elegido: estado.inicio });
      mostrarError(avisoPrevio);
    } catch (error) {
      if (pasoActual === "hora") falloDeServicio(error, () => pasoHora(avisoPrevio));
    }
  }

  // --- Paso 3 -------------------------------------------------------------------------------------

  function cargarTurnstile(contenedor) {
    if (!cfg.turnstile) return;
    tokenTurnstile = "";
    const pintar = () => {
      widgetTurnstile = window.turnstile.render(contenedor, {
        sitekey: cfg.turnstile,
        size: "flexible",
        appearance: "interaction-only",
        callback: (t) => { tokenTurnstile = t; },
        "expired-callback": () => { tokenTurnstile = ""; },
      });
    };
    if (window.turnstile) return pintar();
    // Se carga aquí y no con la página: un script de terceros no debe frenar la primera pantalla (RNF-02).
    const script = el("script", { src: "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit", async: true });
    script.addEventListener("load", pintar);
    document.head.append(script);
  }

  const soloCelular = (valor) => valor.replace(/\D/g, "").replace(/^51(?=\d{9}$)/, "");

  const precioReferencia = () => (estado.motivo?.precio_desde ? Number(estado.motivo.precio_desde) : null);
  const ofertable = () => Boolean(opciones.precio_ofertable) && precioReferencia() !== null;

  const VALIDACIONES = {
    nombre: () => (estado.nombre.trim().split(/\s+/).length >= 2 ? "" : "Escribe nombre y apellido."),
    celular: () => (/^9\d{8}$/.test(soloCelular(estado.celular)) ? "" : "Debe ser un celular peruano de 9 dígitos que empiece con 9."),
    oferta: () => {
      if (!ofertable() || estado.oferta.trim() === "") return "";
      const monto = Number(estado.oferta.replace(",", "."));
      const maximo = precioReferencia() * 2;
      return monto > 0 && monto <= maximo ? "" : `Ofrece un monto mayor que 0 y de hasta S/ ${maximo}.`;
    },
    acepta: () => (estado.acepta ? "" : "Necesitamos tu autorización para avisarte sobre la cita."),
  };

  function pasoDatos() {
    encabezar("datos", "Tus datos", { atras: () => pasoHora() });
    evento("paso_3");
    const campo = (id, atributos) => el("input", { id, "aria-describedby": `error-${id}`, required: true, ...atributos });
    const nombre = campo("nombre", { type: "text", autocomplete: "name", maxlength: "120", value: estado.nombre });
    const celular = campo("celular", {
      type: "tel", inputmode: "tel", autocomplete: "tel-national", maxlength: "16", placeholder: "987 654 321", value: estado.celular,
    });
    const acepta = campo("acepta", { type: "checkbox", checked: estado.acepta });
    // Permiso aparte y opcional para promociones (Ley 29733): sin marcarlo, la reserva funciona igual.
    const publicidad = el("input", { id: "publicidad", type: "checkbox", checked: Boolean(estado.publicidad) });
    publicidad.addEventListener("change", () => { estado.publicidad = publicidad.checked; });
    const oferta = el("input", {
      id: "oferta", type: "text", inputmode: "decimal", maxlength: "8", placeholder: String(precioReferencia() ?? ""),
      value: estado.oferta, "aria-describedby": "error-oferta ayuda-oferta",
    });
    const errores = {
      nombre: el("p", { class: "error-campo", id: "error-nombre", hidden: true }),
      celular: el("p", { class: "error-campo", id: "error-celular", hidden: true }),
      oferta: el("p", { class: "error-campo", id: "error-oferta", hidden: true }),
      acepta: el("p", { class: "error-campo", id: "error-acepta", hidden: true }),
    };
    const enviar = el("button", { class: "boton boton-principal boton-bloque", type: "submit" }, "Continuar");
    const turnstile = el("div");

    function mostrar(nombreCampo) {
      const mensaje = VALIDACIONES[nombreCampo]();
      errores[nombreCampo].textContent = mensaje;
      errores[nombreCampo].hidden = !mensaje;
      return mensaje;
    }

    // aria-disabled y no disabled: al tocarlo todavía explica qué falta, en vez de no responder.
    function actualizarBoton() {
      const completo = Object.values(VALIDACIONES).every((validar) => !validar());
      enviar.setAttribute("aria-disabled", String(!completo));
      return completo;
    }

    function sincronizar(evento_) {
      estado.nombre = nombre.value;
      estado.celular = celular.value;
      estado.oferta = oferta.value;
      estado.acepta = acepta.checked;
      actualizarBoton();
      const id = evento_?.target.id;
      if (id && (!errores[id].hidden || evento_.type === "blur" || id === "acepta")) mostrar(id);
      // Validación en vivo: el campo se marca apenas el dato es válido.
      celular.closest(".campo")?.classList.toggle("valido", !VALIDACIONES.celular());
      nombre.closest(".campo")?.classList.toggle("valido", !VALIDACIONES.nombre());
    }
    for (const entrada of [nombre, celular, oferta, acepta]) {
      entrada.addEventListener("input", sincronizar);
      entrada.addEventListener("blur", sincronizar);
    }

    async function reservar() {
      enviar.disabled = true;
      enviar.textContent = "Reservando…";
      try {
        const reserva = await api(`${API}/reservas`, {
          method: "POST",
          body: JSON.stringify({
            motivo: estado.motivo.slug,
            inicio: estado.inicio,
            nombre: estado.nombre.trim(),
            celular: `+51${soloCelular(estado.celular)}`,
            acepta_politica: true,
            acepta_publicidad: Boolean(estado.publicidad),
            turnstile: tokenTurnstile,
            profesional: estado.profesional ? estado.profesional.id : null,
            precio_ofrecido: ofertable() && estado.oferta.trim() ? Number(estado.oferta.replace(",", ".")) : null,
          }),
        });
        // Datos de la sesión web: la próxima reserva ya viene con nombre y WhatsApp, sin cuenta ni contraseña.
        sesionDatos.escribir("nombre", estado.nombre.trim());
        sesionDatos.escribir("celular", soloCelular(estado.celular));
        guardarCita(reserva.token);
        evento("paso_4");
        avisarAlSitio("reservada");
        pasoConfirmar(reserva.token);
      } catch (error) {
        enviar.disabled = false;
        enviar.textContent = "Continuar";
        if (widgetTurnstile !== null) window.turnstile.reset(widgetTurnstile);
        if (error.codigo === "horario_tomado") {
          estado.inicio = null;
          pasoHora("Ese horario acaba de ocuparse. Elige otro.");
        } else if (error.codigo === "paciente_ocupado") {
          // Ya tiene otra cita a esa hora (aunque sea con otra persona): de vuelta a elegir hora, con el motivo.
          estado.inicio = null;
          pasoHora(error.message);
        } else if (error.codigo === "limite_citas") {
          mostrarError(error.message);
          pintarCitas();
        } else {
          mostrarError(error.message, error.sinConexion ? reservar : null);
        }
      }
    }

    paso.append(el("form", {
      novalidate: true,
      onsubmit: (e) => {
        e.preventDefault();
        mostrarError("");
        const fallidos = ["nombre", "celular", "oferta", "acepta"].filter(mostrar);
        if (fallidos.length) {
          ({ nombre, celular, oferta, acepta })[fallidos[0]].focus();
          return;
        }
        reservar();
      },
    },
      el("div", { class: "tarjeta" },
        el("strong", {}, estado.motivo.nombre), el("br"),
        `${fechaLarga(estado.inicio)}, ${hora(estado.inicio)}`,
        estado.profesional ? el("span", {}, el("br"), `Con ${estado.profesional.nombre}`) : null,
      ),
      el("div", { class: "campo" }, el("label", { for: "nombre" }, "Nombre y apellido"), nombre, errores.nombre),
      el("div", { class: "campo" },
        el("label", { for: "celular" }, "Celular"),
        el("div", { class: "grupo-celular" }, el("span", {}, "+51"), celular),
        errores.celular,
        el("p", { class: "dato" }, `A este número ${voc.el_local} te escribirá por WhatsApp para confirmar tu cita.`),
      ),
      ofertable() && el("div", { class: "campo oferta" },
        el("label", { for: "oferta" }, "¿Quieres ofrecer otro precio? (opcional)"),
        el("p", { class: "dato", id: "ayuda-oferta" }, `Precio de referencia: S/ ${precioReferencia()}. ${mayuscula(voc.el_local)} acepta tu oferta o te dice el precio final al confirmar.`),
        el("div", { class: "grupo-celular" }, el("span", {}, "S/"), oferta),
        errores.oferta,
      ),
      el("div", { class: "campo" },
        el("p", { class: "dato uso-datos" }, `Pedimos solo tu nombre, tu celular y el ${voc.servicio} que eliges, para registrar tu cita y avisarte sobre ella. No necesitas crear una cuenta.`),
        el("div", { class: "casilla" }, acepta,
          el("label", { for: "acepta" }, "Acepto el uso de mis datos según la ", el("a", { href: "/privacidad/", target: "_blank", rel: "noopener" }, "política de datos"), "."),
        ),
        errores.acepta,
        el("div", { class: "casilla" }, publicidad,
          el("label", { for: "publicidad" }, `Quiero recibir promociones de ${voc.el_local} (opcional).`),
        ),
      ),
      turnstile,
      enviar,
    ));
    sincronizar();
    cargarTurnstile(turnstile);
  }

  // --- Paso 4 y pantalla final --------------------------------------------------------------------

  const rutaCita = (token) => `/public/v1/citas/${token}`;
  const enlaceCita = (token) => `${location.origin}/c/${token}/`;
  const reloj_ = (segundos) => `${String(Math.floor(segundos / 60)).padStart(2, "0")}:${String(segundos % 60).padStart(2, "0")}`;
  const segundosRestantes = (c) => Math.max(0, Math.ceil((new Date(c.expira_en) - Date.now()) / 1000));

  /** Si vuelve de WhatsApp a una página recargada, se recuperan motivo y hora para poder reintentar. */
  function recordarDatos(c) {
    estado.motivo = motivos.find((m) => m.slug === c.tratamiento_slug) || estado.motivo;
    estado.inicio = c.inicio;
  }

  async function pasoConfirmar(token, { enfocar = true } = {}) {
    encabezar("final", "Tu reserva", { enfocar });
    estado.token = token;
    almacen.escribir(CLAVE_ACTIVA, token);
    paso.append(el("p", { class: "dato" }, "Preparando tu mensaje…"));
    let c;
    try {
      c = await api(rutaCita(token));
    } catch (error) {
      if (error.status === 404 || error.status === 410) return olvidarActiva(token);
      paso.replaceChildren();
      mostrarError(error.message, () => pasoConfirmar(token));
      return;
    }
    if (estado.token !== token || pasoActual !== "final") return;
    recordarDatos(c);
    pintarCitas();
    if (c.estado !== "pendiente") return alCambiarEstado(c);

    // Solo con la verificación por WhatsApp activa (VERIFICACION_WHATSAPP=1).
    titulo.textContent = "Confirma tu cita por WhatsApp";
    const cuenta = el("p", { class: "cuenta", role: "timer" }, reloj_(segundosRestantes(c)));
    const mensaje = new URL(c.whatsapp_url).searchParams.get("text");
    paso.replaceChildren(
      el("p", {}, "Toca el botón y envía el mensaje tal como aparece. No tienes que escribir nada."),
      el("p", { class: "mensaje-listo" }, mensaje),
      el("div", { class: "pila" },
        el("a", { class: "boton boton-principal boton-bloque", href: c.whatsapp_url, target: "_blank", rel: "noopener" }, "Enviar por WhatsApp"),
      ),
      el("p", { class: "dato" }, "Guardamos tu horario por:"),
      cuenta,
      el("p", { class: "espera dato", "aria-live": "polite" }, "Esperando tu mensaje"),
      cfg.demo && el("div", { class: "aviso" },
        el("p", {}, "Modo de prueba: simula el mensaje de WhatsApp sin una cuenta de Meta."),
        el("button", {
          class: "boton boton-bloque", type: "button", id: "simular",
          onclick: async () => { await fetch(`/dev/simular-whatsapp/${token}/`, { method: "POST" }); consultar(token); },
        }, "Simular mensaje de WhatsApp"),
      ),
      el("div", { class: "pila" },
        el("button", {
          class: "boton-texto", type: "button",
          onclick: async () => {
            try {
              alCambiarEstado(await api(`${rutaCita(token)}/sin-whatsapp`, { method: "POST" }));
            } catch (error) {
              mostrarError(error.message);
            }
          },
        }, "No tengo WhatsApp en este celular"),
      ),
    );
    reloj = setInterval(() => {
      const quedan = segundosRestantes(c);
      cuenta.textContent = reloj_(quedan);
      if (quedan === 0) {
        detener();
        alCambiarEstado({ ...c, estado: "expirada" });
      }
    }, 1000);
    consulta = setTimeout(() => consultar(token), 3000);
  }

  async function consultar(token) {
    clearTimeout(consulta);
    if (pasoActual !== "final" || estado.token !== token) return;
    try {
      const c = await api(rutaCita(token));
      if (c.estado !== "pendiente") return alCambiarEstado(c);
    } catch (error) {
      if (error.status === 404 || error.status === 410) return olvidarActiva(token);
      // Sin señal al volver de WhatsApp: se sigue intentando sin molestar al paciente.
    }
    consulta = setTimeout(() => consultar(token), 3000);
  }

  function olvidarActiva(token) {
    almacen.quitar(CLAVE_ACTIVA);
    quitarCita(token);
    pintarCitas();
    estado.token = null;
    pasoMotivo();
  }

  function alCambiarEstado(c) {
    almacen.quitar(CLAVE_ACTIVA);
    if (c.estado === "programada") vistaFinal(c);
    else if (c.estado === "por_aprobar") vistaPorAprobar(c);
    else if (c.estado === "expirada") vistaExpirada(c);
    else {
      quitarCita(estado.token);
      estado.token = null;
      pasoMotivo();
    }
    pintarCitas();
  }

  /** Todos los datos de la cita: los mismos que llegan en el WhatsApp de confirmación. */
  function resumen(c) {
    const referencias = c.consultorio.referencias ? ` (${c.consultorio.referencias})` : "";
    const filas = [
      ["Nombre", c.paciente],
      [mayuscula(voc.servicio), c.duracion_min ? `${c.tratamiento} · ${c.duracion_min} min` : c.tratamiento],
      ["Con", c.profesional],
      ["Fecha", `${fechaLarga(c.inicio)}, ${hora(c.inicio)}`],
      c.precio_texto && ["Precio", c.precio_texto.replace(/^[^:]+: /, "")],
      ["Lugar", `${c.consultorio.direccion}${referencias}`],
      c.hora_llegada && ["Llega", `${c.llegar_antes_min} min antes, a las ${c.hora_llegada}`],
    ].filter(Boolean);
    return el("div", { class: "tarjeta" },
      el("dl", { class: "resumen" }, filas.flatMap(([dt, dd]) => [el("dt", {}, dt), el("dd", {}, dd)])),
      c.consultorio.mapa_url && el("a", { class: "boton", href: c.consultorio.mapa_url, target: "_blank", rel: "noopener" }, "Ver en el mapa"),
    );
  }

  const reservarOtra = () => {
    Object.assign(estado, { motivo: null, profesional: null, inicio: null, oferta: "", token: null });
    pasoMotivo();
  };

  function botonesCalendario(c, token) {
    return el("div", { class: "pila" },
      el("a", { class: "boton boton-principal boton-bloque", href: enlaceGoogleCalendar(c, enlaceCita(token)), target: "_blank", rel: "noopener" }, "Agregar a Google Calendar"),
      el("a", { class: "boton boton-bloque", href: `${rutaCita(token)}/calendario.ics`, download: "cita.ics" }, "Descargar archivo .ics"),
    );
  }

  function vistaFinal(c) {
    encabezar("final", "¡Tu cita está confirmada!", { final: true });
    evento("confirmada");
    const token = estado.token;
    paso.append(
      checkFinal(),
      resumen(c),
      botonesCalendario(c, token),
      el("p", { class: "dato" }, "El archivo .ics avisa 24 horas y 2 horas antes. Tu cita también queda en «Mis citas» en este celular, y puedes abrirla desde ",
        el("a", { href: enlaceCita(token) }, "tu enlace personal"), "."),
      el("button", { class: "boton boton-bloque", type: "button", onclick: reservarOtra }, "Reservar otra cita"),
    );
  }

  function vistaPorAprobar(c) {
    encabezar("final", "¡Reserva recibida! Espera la confirmación", { final: true });
    const token = estado.token;
    paso.append(
      checkFinal(),
      el("p", { class: "mensaje-listo resumen-espera" }, "Te guardamos el horario. ", el("strong", {}, `${c.consultorio.nombre} te escribirá por WhatsApp`),
        " para confirmar tu cita, con todos estos datos. Mantén a la mano tu celular."),
      resumen(c),
      c.hora_llegada && el("p", { class: "aviso" }, `Te pedimos llegar ${c.llegar_antes_min} min antes, a las ${c.hora_llegada}, por si acaso.`),
      el("p", { class: "dato" }, "Puedes ver el estado en «Mis citas» en este celular o desde ",
        el("a", { href: enlaceCita(token) }, "tu enlace personal"), `. Si necesitas cambiar algo, escríbele ${alLocal}.`),
      el("div", { class: "pila" }, escribirAlConsultorio()),
      el("button", { class: "boton boton-bloque", type: "button", onclick: reservarOtra }, "Reservar otra cita"),
    );
  }

  function vistaExpirada(c) {
    quitarCita(estado.token);
    encabezar("final", "El horario se liberó", {});
    paso.append(
      el("p", {}, "No recibimos tu mensaje en 15 minutos y el horario quedó libre. Si sigue disponible, puedes elegirlo otra vez."),
      el("div", { class: "pila" },
        el("button", { class: "boton boton-principal boton-bloque", type: "button", onclick: () => (estado.motivo ? pasoDatos() : pasoMotivo()) },
          `Elegir otra vez ${hora(c.inicio)}`),
        el("button", { class: "boton boton-bloque", type: "button", onclick: () => (estado.motivo ? pasoHora() : pasoMotivo()) }, "Elegir otra hora"),
      ),
    );
  }

  // --- Mis citas ----------------------------------------------------------------------------------

  const listaCitas = document.getElementById("lista-citas");
  const cajaCitas = document.getElementById("mis-citas");
  const avisoCitas = document.getElementById("aviso-citas");
  const columnas = document.getElementById("columnas-reserva");
  // «Mis citas» vive en la sesión web: vence con ella. Cada cita igual se abre desde el enlace del WhatsApp.
  const tokensGuardados = () => sesionDatos.leer("citas", []);

  function guardarCita(token) {
    sesionDatos.escribir("citas", [...new Set([...tokensGuardados(), token])]);
  }

  function quitarCita(token) {
    sesionDatos.escribir("citas", tokensGuardados().filter((t) => t !== token));
  }

  /** Solo lectura: cambiar o cancelar lo hace el consultorio cuando el paciente le escribe. */
  function tarjetaCita(token, c) {
    const acciones = el("div", { class: "acciones" });
    const etiqueta = {
      pendiente: "Falta confirmar",
      por_aprobar: `Por confirmar: ${voc.el_local} te escribirá por WhatsApp`,
      programada: "Confirmada",
      en_curso: "En atención",
    }[c.estado];
    const hijos = [
      el("strong", {}, c.tratamiento),
      el("span", { class: "numeros" }, `${fechaLarga(c.inicio)}, ${hora(c.inicio)}`),
      c.profesional && el("span", { class: "dato" }, `Con ${c.profesional}`),
      el("p", { class: `dato estado-${c.estado}` }, etiqueta),
      c.retraso_min > 0 && c.hora_estimada && el("p", { class: "aviso" }, `Hora estimada: ${hora(c.hora_estimada)} (unos ${c.retraso_min} min de retraso).`),
    ];
    const tarjeta = el("article", { class: "cita-guardada" }, hijos, acciones);

    if (c.estado === "pendiente") {
      acciones.append(el("button", {
        class: "boton", type: "button",
        onclick: () => { estado.token = token; pasoConfirmar(token); llevarALaReserva(); },
      }, "Continuar"));
      return tarjeta;
    }
    if (c.estado === "programada") {
      acciones.append(el("a", { class: "boton", href: enlaceGoogleCalendar(c, enlaceCita(token)), target: "_blank", rel: "noopener" }, "Google Calendar"));
    }
    acciones.append(el("a", { class: "boton", href: `https://wa.me/${c.consultorio.whatsapp}`, rel: "noopener" }, `Escribir ${alLocal}`));
    return tarjeta;
  }

  function anunciar(mensaje) {
    avisoCitas.textContent = mensaje;
    avisoCitas.hidden = false;
  }

  const ACTIVAS = ["pendiente", "por_aprobar", "programada", "en_curso"];

  async function pintarCitas() {
    const tokens = tokensGuardados();
    const resultados = await Promise.allSettled(tokens.map((t) => api(rutaCita(t))));
    const tarjetas = [];
    resultados.forEach((r, i) => {
      if (r.status === "fulfilled" && ACTIVAS.includes(r.value.estado)) tarjetas.push(tarjetaCita(tokens[i], r.value));
      // Solo se olvida lo que ya terminó: un fallo de red no debe borrar las citas del paciente.
      else if (r.status === "fulfilled" || r.reason.status === 404 || r.reason.status === 410) quitarCita(tokens[i]);
    });
    listaCitas.replaceChildren(...tarjetas);
    const hayAlgo = tarjetas.length > 0 || !avisoCitas.hidden;
    cajaCitas.hidden = !hayAlgo;
    columnas.classList.toggle("con-citas", hayAlgo);
  }

  // --- Entradas desde el resto de la página -------------------------------------------------------

  volver.addEventListener("click", () => alVolver && alVolver());

  document.querySelectorAll("[data-tratamiento]").forEach((enlace) => {
    enlace.addEventListener("click", (e) => {
      const motivo = motivos.find((m) => m.slug === enlace.dataset.tratamiento);
      if (!motivo) return;
      e.preventDefault();
      elegirMotivo(motivo);
      trasMotivo();
      llevarALaReserva();
    });
  });

  window.dc.reserva = {
    evento,
    /** Desde el aviso «Próximo horario libre»: entra al paso 3 con esa hora ya elegida. */
    conHora(slug, inicio) {
      const motivo = motivos.find((m) => m.slug === slug);
      if (!motivo) return;
      elegirMotivo(motivo);
      evento("paso_2");
      estado.inicio = inicio;
      pasoDatos();
      llevarALaReserva();
    },
  };

  const normalizar = (texto) => String(texto || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

  /** Enlace directo con servicio (`?servicio=corte` o el nombre tal cual) y profesional (`?con=<id>`). */
  function preseleccion() {
    const pedido = normalizar(parametros.get("servicio"));
    if (!pedido || !motivos) return false;
    const motivo = motivos.find((m) => m.slug === pedido || normalizar(m.nombre) === pedido)
      || motivos.find((m) => normalizar(m.nombre).startsWith(pedido) || pedido.startsWith(normalizar(m.nombre)));
    if (!motivo) return false;
    elegirMotivo(motivo);
    const con = parametros.get("con");
    const profesional = con && (cfg.profesionales || []).find((p) => String(p.id) === con && atiende(p, motivo));
    if (profesional) {
      estado.profesional = profesional;
      pasoHora();
    } else {
      trasMotivo();
    }
    return true;
  }

  document.getElementById("rv-cerrar")?.addEventListener("click", () => avisarAlSitio("cerrar"));
  document.addEventListener("keydown", (e) => { if (e.key === "Escape") avisarAlSitio("cerrar"); });

  async function iniciar() {
    if (!preseleccion()) pasoMotivo({ enfocar: false });
    pintarCitas();
    const activa = almacen.leer(CLAVE_ACTIVA, null);
    if (activa) {
      estado.token = activa;
      pasoConfirmar(activa, { enfocar: false });
    }
    try {
      motivos = (await api(`${API}/perfil`)).motivos;
      if (pasoActual === "motivo" && !preseleccion()) pasoMotivo({ enfocar: false });
    } catch (error) {
      if (pasoActual === "motivo") falloDeServicio(error, iniciar);
    }
  }

  // Al volver de WhatsApp el celular suele reanudar la pestaña: se revisa de inmediato.
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden && pasoActual === "final" && estado.token && reloj) consultar(estado.token);
  });

  iniciar();
})();
