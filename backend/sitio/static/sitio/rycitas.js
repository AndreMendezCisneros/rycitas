/*
 * RyCitas: widget de reserva para el sitio propio de un negocio.
 *
 *   <script src="/rycitas.js" defer></script>
 *   <a href="/reservar/" data-rycitas-reservar>Agendar cita</a>
 *   <button data-rycitas-reservar data-servicio="Hydrafacial">Agendar este tratamiento</button>
 *
 * Cualquier elemento con `data-rycitas-reservar`, o un enlace a `/reservar`, abre la reserva encima de la página:
 * a pantalla completa en el celular y como ventana centrada en la PC. Sin JavaScript, el enlace igual lleva a la
 * página de reserva. `#reservar` en la dirección la abre al cargar, y `window.RyCitas.abrir({ servicio })` desde código.
 */
(() => {
  "use strict";
  if (window.RyCitas) return;

  const script = document.currentScript;
  const origen = script && script.src ? new URL(script.src).origin : location.origin;
  let capa = null;
  let marco = null;
  let foco = null;
  let conHistorial = false;
  let desbordeAnterior = "";

  const movil = () => window.matchMedia("(max-width: 640px)").matches;
  const reducir = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function estilos() {
    const m = movil();
    capa.style.cssText = [
      "position:fixed", "inset:0", "z-index:2147483000", "display:flex",
      m ? "align-items:flex-end" : "align-items:center", "justify-content:center",
      "background:rgba(12,14,18,.55)", "backdrop-filter:blur(3px)", "-webkit-backdrop-filter:blur(3px)",
      "opacity:0", reducir() ? "" : "transition:opacity .2s ease",
    ].join(";");
    marco.style.cssText = [
      "border:0", "display:block", "background:#f4f5f8", "box-shadow:0 24px 60px rgba(0,0,0,.3)",
      m ? "width:100%" : "width:min(480px,calc(100vw - 32px))",
      m ? "height:100%" : "height:min(780px,calc(100vh - 48px))",
      m ? "border-radius:0" : "border-radius:22px",
      m ? "transform:translateY(24px)" : "transform:translateY(12px) scale(.98)",
      reducir() ? "" : "transition:transform .28s cubic-bezier(.2,.8,.2,1)",
    ].join(";");
  }

  function abrir(opciones = {}) {
    if (capa) return;
    const url = new URL("/reservar/", origen);
    url.searchParams.set("embed", "1");
    if (opciones.servicio) url.searchParams.set("servicio", opciones.servicio);
    if (opciones.con) url.searchParams.set("con", opciones.con);

    foco = document.activeElement;
    capa = document.createElement("div");
    capa.setAttribute("role", "dialog");
    capa.setAttribute("aria-modal", "true");
    capa.setAttribute("aria-label", "Reservar cita");
    marco = document.createElement("iframe");
    marco.title = "Reservar cita";
    marco.src = url.href;
    marco.allow = "clipboard-write";
    capa.append(marco);
    estilos();
    capa.addEventListener("click", (e) => { if (e.target === capa) cerrar(); });
    document.body.append(capa);
    desbordeAnterior = document.documentElement.style.overflow;
    document.documentElement.style.overflow = "hidden";
    requestAnimationFrame(() => {
      capa.style.opacity = "1";
      marco.style.transform = "none";
    });
    const actual = marco;
    actual.addEventListener("load", () => { if (marco === actual) actual.focus(); }, { once: true });
    // El gesto «atrás» del celular cierra la reserva en vez de salir del sitio.
    try {
      history.pushState({ rycitas: true }, "");
      conHistorial = true;
    } catch { conHistorial = false; }
  }

  function cerrar({ desdeHistorial = false } = {}) {
    if (!capa) return;
    const quitar = capa;
    capa = marco = null;
    quitar.style.opacity = "0";
    setTimeout(() => quitar.remove(), reducir() ? 0 : 200);
    document.documentElement.style.overflow = desbordeAnterior;
    if (foco && foco.focus) foco.focus();
    if (conHistorial && !desdeHistorial) {
      conHistorial = false;
      history.back();
    }
    conHistorial = false;
  }

  window.addEventListener("popstate", () => { if (capa) cerrar({ desdeHistorial: true }); });
  window.addEventListener("keydown", (e) => { if (e.key === "Escape" && capa) cerrar(); });
  window.addEventListener("resize", () => { if (capa) { estilos(); capa.style.opacity = "1"; marco.style.transform = "none"; } });
  window.addEventListener("message", (e) => {
    if (e.origin !== origen || !e.data || typeof e.data !== "object") return;
    if (e.data.rycitas === "cerrar") cerrar();
    if (e.data.rycitas === "reservada") document.dispatchEvent(new CustomEvent("rycitas:reservada"));
  });

  /** Un enlace a /reservar del mismo negocio (o a la misma página de reserva en otro dominio del widget). */
  function esEnlaceReserva(a) {
    if (!a || !a.href) return false;
    try {
      const destino = new URL(a.href, location.href);
      return (destino.origin === origen || destino.origin === location.origin) && /^\/reservar\/?$/.test(destino.pathname);
    } catch { return false; }
  }

  // Delegado en el documento: funciona también con botones que React pinta después.
  document.addEventListener("click", (e) => {
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    const disparador = e.target.closest("[data-rycitas-reservar]");
    const enlace = disparador || e.target.closest("a[href]");
    if (!disparador && !esEnlaceReserva(enlace)) return;
    e.preventDefault();
    const datos = (disparador || enlace).dataset;
    let servicio = datos.servicio;
    if (!servicio && enlace && enlace.href) {
      try { servicio = new URL(enlace.href, location.href).searchParams.get("servicio") || undefined; } catch { /* sin servicio */ }
    }
    abrir({ servicio, con: datos.con });
  }, true);

  window.RyCitas = { abrir, cerrar };

  const alCargar = () => { if (location.hash === "#reservar") abrir(); };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", alCargar);
  else alCargar();
})();
