/* Lo que depende de la hora o del navegador. El HTML puede venir de la caché, así que se calcula aquí y no en el servidor. */
"use strict";

(() => {
  const { el, hora, fechaLarga, api, config, almacen } = window.dc;
  const cfg = config();
  const ZONA = "America/Lima";
  const SEMANA = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  function ahoraEnLima() {
    const partes = Object.fromEntries(
      new Intl.DateTimeFormat("en-US", { timeZone: ZONA, weekday: "short", hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
        .formatToParts(new Date()).map((p) => [p.type, p.value]),
    );
    return { dia: SEMANA.indexOf(partes.weekday), minutos: Number(partes.hour) * 60 + Number(partes.minute) };
  }

  const aMinutos = (texto) => { const [h, m] = texto.split(":").map(Number); return h * 60 + m; };
  // Una fecha cualquiera en hora de Lima solo para reutilizar el formato de horas de todo el sitio.
  const textoHora = (texto) => hora(`2026-01-01T${texto}:00-05:00`);

  /** RW-02. No considera bloqueos puntuales: es el horario habitual del consultorio. */
  function pintarEstado() {
    const caja = document.getElementById("estado-atencion");
    const { dia, minutos } = ahoraEnLima();
    const rangos = cfg.horario.find((d) => d.dia_semana === dia)?.rangos || [];
    const actual = rangos.find(([a, c]) => minutos >= aMinutos(a) && minutos < aMinutos(c));
    const proximo = rangos.find(([a]) => minutos < aMinutos(a));
    caja.classList.toggle("abierto", Boolean(actual));
    caja.textContent = actual
      ? `Atendiendo ahora · hasta las ${textoHora(actual[1])}`
      : proximo ? `Abre hoy a las ${textoHora(proximo[0])}` : "Cerrado";
    caja.hidden = false;
  }

  function marcarHoy() {
    document.querySelector(`.horario tr[data-dia="${ahoraEnLima().dia}"]`)?.classList.add("hoy");
  }

  /** RW-14: sin portapapeles (http, navegador antiguo) el número queda seleccionado para copiarlo a mano. */
  function prepararCopia() {
    const numero = document.getElementById("numero-wa");
    const nota = document.getElementById("copiado");
    document.getElementById("copiar-wa").addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(numero.textContent.trim());
        nota.textContent = "Número copiado.";
      } catch {
        const rango = document.createRange();
        rango.selectNodeContents(numero);
        const seleccion = window.getSelection();
        seleccion.removeAllRanges();
        seleccion.addRange(rango);
        nota.textContent = "Número seleccionado: cópialo desde tu celular.";
      }
      nota.hidden = false;
    });
  }

  async function prepararAviso() {
    const aviso = document.getElementById("aviso-horario");
    if (almacen.leer("dc_aviso_cerrado", false, "sessionStorage")) return;
    // RF-05: quien no tiene diagnóstico entra por evaluación.
    const motivo = cfg.motivos.find((m) => m.slug.startsWith("evaluacion")) || cfg.motivos[0];
    if (!motivo) return;
    let inicio;
    try {
      const { dias } = await api(`/public/v1/${cfg.slug}/disponibilidad?motivo=${encodeURIComponent(motivo.slug)}&dias=${cfg.dias_maximos}`);
      inicio = dias[0]?.horas[0];
    } catch {
      return; // la barra superior sigue ofreciendo «Reservar cita»
    }
    if (!inicio) return;
    document.getElementById("aviso-hora").replaceChildren(`${fechaLarga(inicio)}, `, el("span", { class: "sin-corte" }, hora(inicio)));
    let cerrado = false;
    let reservaVisible = false;
    const actualizar = () => { aviso.hidden = cerrado || reservaVisible; };
    document.getElementById("aviso-reservar").addEventListener("click", () => window.dc.reserva.conHora(motivo.slug, inicio));
    document.getElementById("aviso-cerrar").addEventListener("click", () => {
      cerrado = true;
      almacen.escribir("dc_aviso_cerrado", true, "sessionStorage");
      actualizar();
    });
    // Mientras la reserva está en pantalla el aviso solo tapaba el formulario.
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(([entrada]) => {
        reservaVisible = entrada.isIntersecting;
        actualizar();
      }).observe(document.getElementById("reservar"));
    }
    actualizar();
  }

  pintarEstado();
  setInterval(pintarEstado, 60000);
  marcarHoy();
  prepararCopia();
  prepararAviso();
  window.dc.reserva.evento("visita");
})();
