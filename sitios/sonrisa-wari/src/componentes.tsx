import { useEffect, useState, type ReactNode } from "react";
import { Link, NavLink, useLocation } from "react-router-dom";
import {
  ArrowRight,
  ArrowUp,
  ArrowUpRight,
  CalendarDays,
  ChevronDown,
  Clock3,
  HeartPulse,
  MapPin,
  Menu,
  MessageCircle,
  Smile,
  Sparkles,
  Stethoscope,
  ShieldCheck,
  Sun,
  Wrench,
  X,
} from "lucide-react";
import type { Ficha } from "./contenido";
import { enlaceReserva, estadoApertura, horarioResumido, telefonoVisible, usePerfil, whatsappUrl } from "./datos";

const ENLACES = [
  { texto: "Inicio", a: "/" },
  { texto: "Tratamientos", a: "/tratamientos" },
  { texto: "Nosotros", a: "/nosotros" },
  { texto: "Consejos", a: "/consejos" },
  { texto: "Contacto", a: "/contacto" },
];

/** Título de la pestaña de cada página (y lo que muestra Google). */
export function useTitulo(titulo: string, descripcion?: string) {
  useEffect(() => {
    document.title = titulo ? `${titulo} · Sonrisa Wari` : "Sonrisa Wari · Consultorio dental en Huamanga";
    if (descripcion) document.querySelector('meta[name="description"]')?.setAttribute("content", descripcion);
  }, [titulo, descripcion]);
}

/**
 * Abre la reserva de RyCitas encima de la página (rycitas.js intercepta el enlace). Si el script no cargó, el enlace
 * lleva igual a la reserva a pantalla completa.
 */
export function Reservar({
  servicio,
  children = "Reservar cita",
  variante = "coral",
  className = "",
  flecha = true,
}: {
  servicio?: string;
  children?: ReactNode;
  variante?: "coral" | "contorno";
  className?: string;
  flecha?: boolean;
}) {
  return (
    <a
      href={enlaceReserva(servicio)}
      data-rycitas-reservar=""
      data-servicio={servicio}
      className={`boton boton--${variante} ${className}`}
    >
      {children}
      {flecha && <ArrowUpRight aria-hidden="true" />}
    </a>
  );
}

export function BotonWhatsapp({ texto = "Escríbenos", mensaje, className = "" }: { texto?: string; mensaje?: string; className?: string }) {
  const { whatsapp } = usePerfil();
  const url = whatsappUrl(whatsapp, mensaje);
  if (!url) return null;
  return (
    <a href={url} target="_blank" rel="noopener noreferrer" className={`boton boton--contorno ${className}`}>
      <MessageCircle aria-hidden="true" />
      {texto}
    </a>
  );
}

export function Icono({ tipo }: { tipo: Ficha["icono"] }) {
  const iconos = {
    evaluacion: Stethoscope,
    limpieza: Sparkles,
    urgencia: HeartPulse,
    curacion: ShieldCheck,
    blanqueamiento: Sun,
    ortodoncia: Wrench,
    general: Smile,
  } as const;
  const Componente = iconos[tipo];
  return <Componente aria-hidden="true" />;
}

export function Antetitulo({ children }: { children: ReactNode }) {
  return (
    <span className="eyebrow">
      <span aria-hidden="true" />
      {children}
    </span>
  );
}

export function Introduccion({ antetitulo, titulo, texto }: { antetitulo: string; titulo: string; texto: string }) {
  return (
    <div className="page-shell page-intro">
      <Antetitulo>{antetitulo}</Antetitulo>
      <h1>{titulo}</h1>
      <p>{texto}</p>
    </div>
  );
}

export function TituloSeccion({
  antetitulo,
  titulo,
  texto,
  enlace,
}: {
  antetitulo: string;
  titulo: string;
  texto?: string;
  enlace?: { a: string; texto: string };
}) {
  return (
    <div className="section-heading">
      <div>
        <Antetitulo>{antetitulo}</Antetitulo>
        <h2>{titulo}</h2>
        {texto && <p>{texto}</p>}
      </div>
      {enlace && (
        <Link to={enlace.a} className="boton boton--contorno section-heading__link">
          {enlace.texto}
          <ArrowRight aria-hidden="true" />
        </Link>
      )}
    </div>
  );
}

export function Preguntas({ items }: { items: { pregunta: string; respuesta: string }[] }) {
  return (
    <div className="faq-list">
      {items.map((p) => (
        <details className="faq-item" key={p.pregunta}>
          <summary>
            {p.pregunta}
            <ChevronDown className="faq-chevron" aria-hidden="true" />
          </summary>
          <p>{p.respuesta}</p>
        </details>
      ))}
    </div>
  );
}

/** Las preguntas generales, completadas con lo que dice el panel (formas de pago, a quién atiende). */
export function usePreguntas(base: { pregunta: string; respuesta: string }[]) {
  const perfil = usePerfil();
  const pagos = perfil.contenido?.formas_de_pago ?? [];
  const publico = perfil.contenido?.publico;
  return base
    .map((p) => {
      if (p.respuesta === "PAGOS")
        return pagos.length ? { ...p, respuesta: `Aceptamos ${unirLista(pagos)}.` } : null;
      if (p.respuesta === "PUBLICO")
        return publico
          ? { ...p, respuesta: `Sí. Atendemos a ${publico.charAt(0).toLowerCase()}${publico.slice(1)}. A los más pequeños les explicamos todo con paciencia.` }
          : null;
      return p;
    })
    .filter((p): p is { pregunta: string; respuesta: string } => p !== null);
}

export function unirLista(items: string[]): string {
  if (items.length <= 1) return items.join("");
  return `${items.slice(0, -1).join(", ")} y ${items[items.length - 1]}`;
}

function AlCambiarDePagina() {
  const { pathname } = useLocation();
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);
  return null;
}

export function Plantilla({ children }: { children: ReactNode }) {
  const [menu, setMenu] = useState(false);
  const perfil = usePerfil();
  const apertura = estadoApertura(perfil.horario);
  const wa = whatsappUrl(perfil.whatsapp);
  const { pathname } = useLocation();
  useEffect(() => setMenu(false), [pathname]);

  return (
    <div className="clinic-site">
      <AlCambiarDePagina />
      <a className="skip-to-content" href="#contenido">
        Saltar al contenido
      </a>
      <div className="top-banner" role="status">
        <span className={`top-banner__dot ${apertura.abierto ? "top-banner__dot--abierto" : ""}`} aria-hidden="true" />
        {apertura.texto}
        <span className="top-banner__sep" aria-hidden="true">
          ·
        </span>
        <span className="top-banner__extra">Reserva en línea las 24 horas</span>
      </div>
      <header className="site-header">
        <div className="site-header__inner">
          <Link to="/" className="brand" aria-label={`${perfil.nombre}, inicio`}>
            <span className="brand__mark">
              <Smile aria-hidden="true" />
            </span>
            <span className="brand__words">
              <span>{perfil.nombre}</span>
              <small>CONSULTORIO DENTAL · HUAMANGA</small>
            </span>
          </Link>
          <nav className="site-nav" aria-label="Navegación principal">
            {ENLACES.map((e) => (
              <NavLink key={e.a} to={e.a} end={e.a === "/"} className="site-nav__link">
                {e.texto}
              </NavLink>
            ))}
          </nav>
          <div className="site-header__actions">
            {wa && (
              <a className="header-phone" href={wa} target="_blank" rel="noopener noreferrer">
                <MessageCircle aria-hidden="true" />
                <span>{telefonoVisible(perfil.whatsapp)}</span>
              </a>
            )}
            <Reservar className="header-cta" />
            <button
              type="button"
              className="mobile-menu-button"
              aria-label={menu ? "Cerrar menú" : "Abrir menú"}
              aria-expanded={menu}
              onClick={() => setMenu(!menu)}
            >
              {menu ? <X aria-hidden="true" /> : <Menu aria-hidden="true" />}
            </button>
          </div>
        </div>
        {menu && (
          <nav className="mobile-nav" aria-label="Navegación móvil">
            {ENLACES.map((e) => (
              <Link key={e.a} to={e.a}>
                {e.texto}
                <ArrowRight aria-hidden="true" />
              </Link>
            ))}
            <Link to="/urgencias">
              Urgencias
              <ArrowRight aria-hidden="true" />
            </Link>
          </nav>
        )}
      </header>
      <main id="contenido">{children}</main>
      <Pie />
      <div className="mobile-bottom-bar">
        {wa ? (
          <a className="boton boton--contorno" href={wa} target="_blank" rel="noopener noreferrer">
            <MessageCircle aria-hidden="true" /> WhatsApp
          </a>
        ) : (
          <Link className="boton boton--contorno" to="/contacto">
            <MapPin aria-hidden="true" /> Cómo llegar
          </Link>
        )}
        <Reservar flecha={false}>
          <CalendarDays aria-hidden="true" /> Reservar
        </Reservar>
      </div>
    </div>
  );
}

function Pie() {
  const perfil = usePerfil();
  const wa = whatsappUrl(perfil.whatsapp);
  return (
    <footer className="site-footer">
      <div className="page-shell site-footer__main">
        <div className="site-footer__brand">
          <Link to="/" className="brand">
            <span className="brand__mark">
              <Smile aria-hidden="true" />
            </span>
            <span className="brand__words">
              <span>{perfil.nombre}</span>
              <small>CONSULTORIO DENTAL · HUAMANGA</small>
            </span>
          </Link>
          <p>{perfil.doctor}. Atención dental cercana, con explicaciones claras y sin apuros.</p>
        </div>
        <div>
          <h3>Explora</h3>
          <Link to="/tratamientos">Tratamientos y precios</Link>
          <Link to="/nosotros">Nosotros</Link>
          <Link to="/consejos">Consejos</Link>
          <Link to="/preguntas-frecuentes">Preguntas frecuentes</Link>
          <Link to="/urgencias">Urgencias</Link>
        </div>
        <div>
          <h3>Visítanos</h3>
          <span>{perfil.direccion}</span>
          {horarioResumido(perfil.horario).map((linea) => (
            <span key={linea}>{linea}</span>
          ))}
          {wa && (
            <a href={wa} target="_blank" rel="noopener noreferrer">
              WhatsApp {telefonoVisible(perfil.whatsapp)}
            </a>
          )}
        </div>
        <div>
          <h3>Tu cita</h3>
          <a href={enlaceReserva()} data-rycitas-reservar="">
            Reservar en línea
          </a>
          {/* /privacidad/ la sirve RyCitas: es la política real de los datos de la reserva */}
          <a href="/privacidad/">Privacidad</a>
        </div>
      </div>
      <div className="page-shell site-footer__bottom">
        <span>
          © {new Date().getFullYear()} {perfil.nombre} · Reservas con RyCitas
        </span>
        <a href="#contenido">
          Volver arriba <ArrowUp aria-hidden="true" />
        </a>
      </div>
    </footer>
  );
}

export function FranjaContacto() {
  const perfil = usePerfil();
  const referencias = perfil.contenido?.referencias;
  return (
    <div className="contact-strip">
      <div>
        <span className="contact-strip__icon">
          <Clock3 aria-hidden="true" />
        </span>
        <div>
          <small>Horario</small>
          {horarioResumido(perfil.horario).map((l) => (
            <span key={l}>{l}</span>
          ))}
        </div>
      </div>
      <div>
        <span className="contact-strip__icon">
          <MapPin aria-hidden="true" />
        </span>
        <div>
          <small>Dirección</small>
          <a href={perfil.mapa_url} target="_blank" rel="noopener noreferrer">
            {perfil.direccion}
          </a>
          {referencias && <span className="contact-strip__nota">{referencias}</span>}
        </div>
      </div>
      {perfil.whatsapp && (
        <div>
          <span className="contact-strip__icon">
            <MessageCircle aria-hidden="true" />
          </span>
          <div>
            <small>WhatsApp</small>
            <a href={whatsappUrl(perfil.whatsapp) ?? "#"} target="_blank" rel="noopener noreferrer">
              {telefonoVisible(perfil.whatsapp)}
            </a>
          </div>
        </div>
      )}
    </div>
  );
}
