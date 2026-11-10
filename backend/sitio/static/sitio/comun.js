/* Utilidades compartidas. Todo el texto pasa por textContent: nada de datos del usuario va como HTML. */
"use strict";

window.dc = (() => {
  const ZONA = "America/Lima";
  const LOCAL = "es-PE";
  const DIA_MS = 86400000;
  const DIAS_TIRA = 14;

  function el(etiqueta, atributos = {}, ...hijos) {
    const nodo = document.createElement(etiqueta);
    for (const [nombre, valor] of Object.entries(atributos)) {
      if (valor === false || valor === null || valor === undefined) continue;
      if (nombre === "class") nodo.className = valor;
      else if (nombre.startsWith("on")) nodo.addEventListener(nombre.slice(2), valor);
      else nodo.setAttribute(nombre, valor === true ? "" : valor);
    }
    for (const hijo of hijos.flat()) {
      if (hijo !== null && hijo !== undefined && hijo !== false) nodo.append(hijo);
    }
    return nodo;
  }

  const formato = (opciones) => new Intl.DateTimeFormat(LOCAL, { timeZone: ZONA, ...opciones });
  const sinPunto = (texto) => texto.replace(/\./g, "").toLowerCase();
  const hora = (iso) => formato({ hour: "numeric", minute: "2-digit", hour12: true }).format(new Date(iso));
  /** «jueves 12 de nov» (RWN-11). */
  function fechaLarga(iso) {
    const d = new Date(iso);
    return `${formato({ weekday: "long" }).format(d)} ${formato({ day: "numeric" }).format(d)} de ${sinPunto(formato({ month: "short" }).format(d))}`;
  }
  // Mediodía en Lima: la fecha nunca cambia al formatearla, sea cual sea la zona del teléfono.
  const mediodia = (fecha) => new Date(`${fecha}T12:00:00-05:00`);
  const fechaIso = (d) => new Intl.DateTimeFormat("en-CA", { timeZone: ZONA }).format(d);
  const hora24 = (iso) => Number(new Intl.DateTimeFormat("en-GB", { timeZone: ZONA, hour: "2-digit", hourCycle: "h23" }).format(new Date(iso)));

  async function api(ruta, opciones = {}) {
    let respuesta;
    try {
      respuesta = await fetch(ruta, {
        ...opciones,
        headers: { "Content-Type": "application/json", ...(opciones.headers || {}) },
      });
    } catch {
      const error = new Error("No hay conexión. Revisa tu internet e inténtalo de nuevo.");
      error.sinConexion = true;
      throw error;
    }
    const datos = await respuesta.json().catch(() => ({}));
    if (!respuesta.ok) {
      const mensaje = typeof datos.detail === "string" ? datos.detail : "Algo salió mal. Inténtalo de nuevo.";
      const error = new Error(mensaje);
      error.codigo = datos.codigo;
      error.status = respuesta.status;
      throw error;
    }
    return datos;
  }

  function config() {
    return JSON.parse(document.getElementById("config").textContent);
  }

  /** Muestra un error; con `alReintentar` agrega el botón «Intentar de nuevo». */
  function mostrarError(mensaje, alReintentar) {
    const caja = document.getElementById("error");
    caja.replaceChildren();
    caja.hidden = !mensaje;
    if (!mensaje) return;
    caja.append(el("span", {}, mensaje));
    if (alReintentar) {
      caja.append(el("button", { class: "boton", type: "button", onclick: () => { mostrarError(""); alReintentar(); } }, "Intentar de nuevo"));
    }
  }

  /** El almacenamiento puede fallar (navegación privada, datos bloqueados): nada depende de que funcione. */
  const almacen = {
    leer(clave, valorPorDefecto, zona = "localStorage") {
      try {
        const valor = window[zona].getItem(clave);
        return valor === null ? valorPorDefecto : JSON.parse(valor);
      } catch {
        return valorPorDefecto;
      }
    },
    escribir(clave, valor, zona = "localStorage") {
      try {
        window[zona].setItem(clave, JSON.stringify(valor));
      } catch { /* sin almacenamiento, la sesión sigue en memoria */ }
    },
    quitar(clave, zona = "localStorage") {
      try {
        window[zona].removeItem(clave);
      } catch { /* igual que arriba */ }
    },
  };

  /**
   * Sesión web sin cuenta: el nombre, el WhatsApp y «Mis citas» se recuerdan solo `minutos` desde el último uso
   * (lo define el negocio, 30 o 60 min). Al vencer se borran: en un celular prestado no quedan a la vista.
   * El enlace de cada cita igual llega por WhatsApp.
   */
  function sesionWeb(minutos) {
    const CLAVE = "dc_sesion_web";
    const duracion = Math.max(5, Number(minutos) || 60) * 60 * 1000;
    const vigente = () => {
      const s = almacen.leer(CLAVE, null);
      if (!s || typeof s !== "object" || !s.vence || s.vence < Date.now()) {
        if (s) almacen.quitar(CLAVE);
        return {};
      }
      return s.datos || {};
    };
    const guardar = (datos) => almacen.escribir(CLAVE, { vence: Date.now() + duracion, datos });
    return {
      leer(clave, valorPorDefecto) {
        const datos = vigente();
        if (Object.keys(datos).length) guardar(datos); // cada uso renueva la sesión
        return clave in datos ? datos[clave] : valorPorDefecto;
      },
      escribir(clave, valor) {
        guardar({ ...vigente(), [clave]: valor });
      },
      cerrar() {
        almacen.quitar(CLAVE);
      },
    };
  }

  /** Pregunta dentro de la misma tarjeta, sin ventanas del navegador. «No» deja todo como estaba. */
  function confirmarEnLinea(caja, pregunta, textoSi, alConfirmar) {
    const anteriores = [...caja.childNodes];
    caja.replaceChildren(
      el("p", { class: "dato" }, pregunta),
      el("button", { class: "boton boton-peligro", type: "button", onclick: alConfirmar }, textoSi),
      el("button", { class: "boton", type: "button", onclick: () => caja.replaceChildren(...anteriores) }, "No"),
    );
  }

  function enlaceGoogleCalendar(c, enlaceCita) {
    const utc = (iso) => new Date(iso).toISOString().replace(/[-:]|\.\d{3}/g, "");
    const parametros = new URLSearchParams({
      action: "TEMPLATE",
      text: `Cita en ${c.consultorio.nombre}`,
      dates: `${utc(c.inicio)}/${utc(c.fin)}`,
      location: c.consultorio.direccion,
      details: `${c.tratamiento}. Ver tu cita: ${enlaceCita}`,
    });
    return `https://calendar.google.com/calendar/render?${parametros}`;
  }

  /**
   * Tira de días con cuántos horarios libres tiene cada uno y horas por mañana, tarde y noche.
   * Muestra 14 días; «Ver más días» llega hasta el máximo del consultorio (RF-06 pide 30).
   */
  function svgFlecha(trazo) {
    const ns = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(ns, "svg");
    svg.setAttribute("viewBox", "0 0 24 24");
    svg.setAttribute("aria-hidden", "true");
    const ruta = document.createElementNS(ns, "path");
    ruta.setAttribute("d", trazo);
    svg.append(ruta);
    return svg;
  }

  function selectorHoras(contenedor, dias, alElegir, { maximo = 30, elegido = null } = {}) {
    contenedor.replaceChildren();
    if (!dias.length) {
      contenedor.append(el("p", { class: "aviso" }, "No hay horarios libres en los próximos días. Escríbele al consultorio."));
      return;
    }
    const porFecha = new Map(dias.map((d) => [d.fecha, d]));
    const hoy = mediodia(fechaIso(new Date()));
    const fechas = Array.from({ length: Math.max(maximo, DIAS_TIRA) }, (_, i) => fechaIso(new Date(hoy.getTime() + i * DIA_MS)));
    const ultimaConEspacio = fechas.reduce((ultima, f, i) => (porFecha.has(f) ? i : ultima), 0);
    const primeraConEspacio = fechas.findIndex((f) => porFecha.has(f));
    const elegidoFecha = elegido ? fechaIso(new Date(elegido)) : null;
    let visibles = Math.max(DIAS_TIRA, primeraConEspacio + 1);
    let actual = porFecha.has(elegidoFecha) ? elegidoFecha : fechas[primeraConEspacio];
    if (fechas.indexOf(actual) >= visibles) visibles = fechas.length;

    const tira = el("div", { class: "dias", role: "group", "aria-label": "Días disponibles" });
    const zonaHoras = el("div");
    const mas = el("button", { class: "boton mas-dias", type: "button", onclick: () => { visibles = fechas.length; pintarTira(); } }, "Ver más días");

    // Flechas para la PC: sin ellas, con mouse no hay forma visible de desplazar la tira.
    // Solo aparecen si hay más días hacia ese lado; en el celular se desliza con el dedo.
    const desplazar = (sentido) => tira.scrollBy({ left: sentido * Math.max(tira.clientWidth * 0.8, 120), behavior: "smooth" });
    const flecha = (sentido, etiqueta, trazo) => el("button", {
      class: `dias-flecha dias-flecha-${sentido < 0 ? "izq" : "der"}`, type: "button", "aria-label": etiqueta, tabindex: "-1", hidden: true,
      onclick: () => desplazar(sentido),
    }, svgFlecha(trazo));
    const izq = flecha(-1, "Días anteriores", "M15 18l-6-6 6-6");
    const der = flecha(1, "Días siguientes", "M9 18l6-6-6-6");
    const marco = el("div", { class: "dias-marco" }, tira, izq, der);
    function actualizarFlechas() {
      const resto = tira.scrollWidth - tira.clientWidth - tira.scrollLeft;
      izq.hidden = tira.scrollLeft <= 4;
      der.hidden = resto <= 4;
      marco.classList.toggle("hay-antes", !izq.hidden);
      marco.classList.toggle("hay-despues", !der.hidden);
    }
    tira.addEventListener("scroll", actualizarFlechas, { passive: true });
    // La rueda vertical del mouse también mueve la tira, solo mientras queden días hacia ese lado.
    tira.addEventListener("wheel", (e) => {
      if (Math.abs(e.deltaY) <= Math.abs(e.deltaX)) return;
      const max = tira.scrollWidth - tira.clientWidth;
      if ((e.deltaY > 0 && tira.scrollLeft >= max - 1) || (e.deltaY < 0 && tira.scrollLeft <= 0)) return;
      e.preventDefault();
      tira.scrollLeft += e.deltaY;
    }, { passive: false });
    // Arrastrar con el mouse, como se desliza con el dedo. Si se arrastró, el clic al soltar no elige el día.
    let arrastre = null;
    tira.addEventListener("pointerdown", (e) => {
      if (e.pointerType !== "mouse" || e.button !== 0) return;
      arrastre = { x: e.clientX, inicio: tira.scrollLeft, movio: false };
    });
    window.addEventListener("pointermove", (e) => {
      if (!arrastre) return;
      const dx = e.clientX - arrastre.x;
      if (!arrastre.movio && Math.abs(dx) < 6) return;
      if (!arrastre.movio) { arrastre.movio = true; tira.classList.add("arrastrando"); }
      tira.scrollLeft = arrastre.inicio - dx;
    });
    window.addEventListener("pointerup", () => {
      if (!arrastre) return;
      const movio = arrastre.movio;
      arrastre = null;
      tira.classList.remove("arrastrando");
      if (movio) { ignorarClic = true; setTimeout(() => { ignorarClic = false; }, 0); }
    });
    let ignorarClic = false;
    tira.addEventListener("click", (e) => { if (ignorarClic) { e.stopPropagation(); e.preventDefault(); } }, { capture: true });
    tira.addEventListener("dragstart", (e) => e.preventDefault());
    if (window.ResizeObserver) new ResizeObserver(actualizarFlechas).observe(tira);

    function pintarTira() {
      const posicion = tira.scrollLeft;
      tira.replaceChildren(...fechas.slice(0, visibles).map((f) => {
        const d = porFecha.get(f);
        const fecha = mediodia(f);
        return el("button", {
          class: "dia", type: "button", disabled: !d, "aria-pressed": String(f === actual),
          onclick: () => { actual = f; pintarTira(); pintarHoras(); },
        },
          sinPunto(formato({ weekday: "short" }).format(fecha)),
          el("b", {}, formato({ day: "numeric" }).format(fecha)),
          sinPunto(formato({ month: "short" }).format(fecha)),
          el("small", {}, d ? `${d.horas.length} ${d.horas.length === 1 ? "libre" : "libres"}` : "Lleno"),
        );
      }));
      mas.hidden = visibles > ultimaConEspacio;
      tira.scrollLeft = posicion;
      requestAnimationFrame(actualizarFlechas);
    }

    function pintarHoras() {
      const horas = porFecha.get(actual).horas;
      const grupos = [
        ["Mañana", horas.filter((h) => hora24(h) < 12)],
        ["Tarde", horas.filter((h) => hora24(h) >= 12 && hora24(h) < 18)],
        ["Noche", horas.filter((h) => hora24(h) >= 18)],
      ];
      zonaHoras.replaceChildren(...grupos.filter(([, lista]) => lista.length).flatMap(([titulo, lista]) => [
        el("h4", { class: "grupo-horas" }, titulo),
        el("div", { class: "horas" }, lista.map((h) =>
          el("button", {
            class: "hora", type: "button", "aria-pressed": String(elegido !== null && new Date(h).getTime() === new Date(elegido).getTime()),
            onclick: () => alElegir(h),
          }, hora(h)),
        )),
      ]));
    }

    contenedor.append(marco, mas, zonaHoras);
    pintarTira();
    pintarHoras();
    // Si vuelve con un día ya elegido fuera de la vista, lo trae a la vista.
    const marcado = tira.querySelector('[aria-pressed="true"]');
    if (marcado && marcado.offsetLeft + marcado.offsetWidth > tira.clientWidth) {
      tira.scrollLeft = marcado.offsetLeft - tira.clientWidth / 2 + marcado.offsetWidth / 2;
    }
  }

  return {
    el, hora, fechaLarga, api, config, mostrarError, selectorHoras, almacen, confirmarEnLinea, enlaceGoogleCalendar, sesionWeb,
  };
})();
