import { Link, useParams } from "react-router-dom";
import {
  ArrowRight,
  ArrowUpRight,
  BadgeCheck,
  CalendarCheck,
  Check,
  Clock3,
  CreditCard,
  HeartHandshake,
  MapPin,
  MessageCircle,
  ShieldCheck,
  Smartphone,
  Sparkles,
  Timer,
  Users,
} from "lucide-react";
import fotoConsultorio from "./assets/consultorio.jpg";
import { ARTICULOS, PREGUNTAS, fichaDe } from "./contenido";
import {
  Antetitulo,
  BotonWhatsapp,
  FranjaContacto,
  Icono,
  Introduccion,
  Plantilla,
  Preguntas,
  Reservar,
  TituloSeccion,
  unirLista,
  usePreguntas,
  useTitulo,
} from "./componentes";
import { estadoApertura, soles, telefonoVisible, usePerfil, whatsappUrl, type Tratamiento } from "./datos";

const ICONOS_CONFIANZA = [ShieldCheck, Sparkles, Users];

function Precio({ t }: { t: Tratamiento }) {
  const precio = soles(t.precio_desde);
  return (
    <span className="service-tile__meta">
      {precio && <strong>desde {precio}</strong>}
      <span>
        <Clock3 aria-hidden="true" /> {t.duracion_min} min
      </span>
    </span>
  );
}

function GrillaTratamientos({ tratamientos }: { tratamientos: Tratamiento[] }) {
  return (
    <div className="service-grid">
      {tratamientos.map((t) => {
        const ficha = fichaDe(t.slug, t.descripcion, t.motivo);
        return (
          <Link className="service-tile" key={t.slug} to={`/tratamientos/${t.slug}`}>
            <div className="service-tile__top">
              <span className="service-tile__icon">
                <Icono tipo={ficha.icono} />
              </span>
              <span className="service-tile__category">{ficha.categoria}</span>
            </div>
            <h3>{t.nombre}</h3>
            <p>{ficha.resumen}</p>
            <Precio t={t} />
            <span className="service-tile__link">
              Ver detalle <ArrowUpRight aria-hidden="true" />
            </span>
          </Link>
        );
      })}
    </div>
  );
}

// --- Inicio --------------------------------------------------------------------------------------------

export function Inicio() {
  const perfil = usePerfil();
  useTitulo("", "Consultorio dental en Huamanga. Reserva tu cita en línea en menos de un minuto y te confirmamos por WhatsApp.");
  const reservables = perfil.tratamientos.filter((t) => t.reservable);
  const confianza = perfil.contenido?.bloques_confianza ?? [];
  const anos = perfil.contenido?.anos_practica;
  const apertura = estadoApertura(perfil.horario);

  return (
    <Plantilla>
      <section className="home-hero page-shell" id="inicio">
        <div className="home-hero__copy">
          <Antetitulo>Consultorio dental en Huamanga</Antetitulo>
          <h1>{perfil.nombre}</h1>
          <p className="home-hero__lead">
            Una sonrisa sana empieza con una conversación tranquila. Te explicamos cada paso con palabras simples y sin
            apuros.
          </p>
          <div className="home-hero__actions">
            <Reservar className="boton--grande">Reservar mi cita</Reservar>
            <Link to="/tratamientos" className="boton boton--contorno boton--grande">
              Tratamientos y precios <ArrowRight aria-hidden="true" />
            </Link>
          </div>
          <ul className="home-hero__garantias">
            <li>
              <Timer aria-hidden="true" /> Reservas en menos de un minuto
            </li>
            <li>
              <Smartphone aria-hidden="true" /> Sin crear cuenta
            </li>
            <li>
              <MessageCircle aria-hidden="true" /> Te confirmamos por WhatsApp
            </li>
          </ul>
        </div>
        <div className="home-hero__visual">
          <img src={fotoConsultorio} alt="La doctora conversa con un paciente en el consultorio" />
          <div className="home-hero__photo-note">
            {perfil.foto ? (
              <img className="home-hero__avatar" src={perfil.foto} alt="" />
            ) : (
              <span>
                <HeartHandshake aria-hidden="true" />
              </span>
            )}
            <div>
              <strong>{perfil.doctor}</strong>
              <small>{anos ? `${anos} años cuidando sonrisas en Huamanga` : "Atención con calma"}</small>
            </div>
          </div>
          <span className={`home-hero__estado ${apertura.abierto ? "home-hero__estado--abierto" : ""}`}>
            {apertura.abierto ? "Abierto ahora" : "Reserva para el próximo horario"}
          </span>
        </div>
      </section>

      {confianza.length > 0 && (
        <section className="trust-band" aria-label="Cómo te cuidamos">
          <div className="page-shell trust-band__inner">
            {confianza.slice(0, 3).map((b, i) => {
              const IconoConfianza = ICONOS_CONFIANZA[i % ICONOS_CONFIANZA.length];
              return (
                <div key={b.titulo}>
                  <IconoConfianza aria-hidden="true" />
                  <div>
                    <strong>{b.titulo}</strong>
                    <span>{b.texto}</span>
                  </div>
                </div>
              );
            })}
          </div>
        </section>
      )}

      <section className="content-section page-shell">
        <TituloSeccion
          antetitulo="Reserva directo"
          titulo="¿Qué te trae por aquí?"
          texto="Elige lo que te pasa y reserva tu hora. Si no sabes qué necesitas, empieza con una evaluación."
        />
        <div className="motivos">
          {reservables.map((t) => {
            const ficha = fichaDe(t.slug, t.descripcion, t.motivo);
            return (
              <a key={t.slug} className="motivo" href={`/reservar/?servicio=${encodeURIComponent(t.slug)}`} data-rycitas-reservar="" data-servicio={t.slug}>
                <span className="motivo__icono">
                  <Icono tipo={ficha.icono} />
                </span>
                <span className="motivo__texto">
                  <strong>{t.motivo || t.nombre}</strong>
                  <small>
                    {t.nombre}
                    {soles(t.precio_desde) ? ` · desde ${soles(t.precio_desde)}` : ""}
                  </small>
                </span>
                <ArrowUpRight className="motivo__flecha" aria-hidden="true" />
              </a>
            );
          })}
        </div>
      </section>

      <section className="steps-band">
        <div className="page-shell">
          <TituloSeccion antetitulo="Así de simple" titulo="Tu cita en tres pasos" />
          <ol className="steps-grid">
            <li>
              <span>01</span>
              <CalendarCheck aria-hidden="true" />
              <h3>Elige tratamiento y hora</h3>
              <p>Ves los horarios libres de verdad, al instante.</p>
            </li>
            <li>
              <span>02</span>
              <Smartphone aria-hidden="true" />
              <h3>Deja tu nombre y celular</h3>
              <p>Sin crear cuenta ni contraseñas.</p>
            </li>
            <li>
              <span>03</span>
              <MessageCircle aria-hidden="true" />
              <h3>Te confirmamos por WhatsApp</h3>
              <p>Y te recordamos tu cita un día antes.</p>
            </li>
          </ol>
          <Reservar>Elegir mi horario</Reservar>
        </div>
      </section>

      <section className="content-section page-shell">
        <TituloSeccion
          antetitulo="Tratamientos"
          titulo="Precios claros, desde el principio"
          texto="El precio final depende de tu caso y te lo decimos antes de empezar. Sin sorpresas."
          enlace={{ a: "/tratamientos", texto: "Ver todos" }}
        />
        <GrillaTratamientos tratamientos={perfil.tratamientos.slice(0, 6)} />
      </section>

      <section className="welcome-band">
        <div className="page-shell welcome-band__inner">
          {perfil.foto ? (
            <img className="welcome-band__foto" src={perfil.foto} alt={`Foto de ${perfil.doctor}`} />
          ) : (
            <div className="welcome-band__mark">
              <HeartHandshake aria-hidden="true" />
            </div>
          )}
          <div>
            <Antetitulo>Quién te atiende</Antetitulo>
            <h2>{perfil.doctor}</h2>
            <p>{perfil.presentacion}</p>
          </div>
          <Link to="/nosotros" className="boton boton--contorno">
            Conócenos <ArrowRight aria-hidden="true" />
          </Link>
        </div>
      </section>

      <section className="content-section page-shell">
        <TituloSeccion
          antetitulo="Resolvemos tus dudas"
          titulo="Preguntas frecuentes"
          enlace={{ a: "/preguntas-frecuentes", texto: "Ver todas" }}
        />
        <Preguntas items={usePreguntas(PREGUNTAS).slice(0, 4)} />
      </section>

      <section className="home-contact page-shell">
        <div className="home-contact__copy">
          <Antetitulo>Te esperamos</Antetitulo>
          <h2>¿Agendamos tu visita?</h2>
          <p>Reserva en línea a cualquier hora o escríbenos por WhatsApp si tienes una duda.</p>
          <div className="home-hero__actions">
            <Reservar />
            <BotonWhatsapp />
          </div>
        </div>
        <FranjaContacto />
      </section>
    </Plantilla>
  );
}

// --- Tratamientos --------------------------------------------------------------------------------------

export function Tratamientos() {
  const perfil = usePerfil();
  useTitulo("Tratamientos y precios", "Tratamientos dentales con precios desde y duración: evaluación, limpieza, curación, blanqueamiento, ortodoncia y urgencias.");
  return (
    <Plantilla>
      <Introduccion
        antetitulo="Atención dental"
        titulo="Tratamientos y precios"
        texto="Precios «desde» y duración de cada atención. El precio final depende de tu caso: te lo decimos antes de empezar."
      />
      <section className="content-section page-shell">
        <GrillaTratamientos tratamientos={perfil.tratamientos} />
      </section>
      <section className="closing-band page-shell">
        <div>
          <Antetitulo>¿No sabes cuál elegir?</Antetitulo>
          <h2>Empieza con una evaluación.</h2>
        </div>
        <Reservar servicio="evaluacion">Reservar evaluación</Reservar>
      </section>
    </Plantilla>
  );
}

export function TratamientoDetalle() {
  const { slug = "" } = useParams();
  const perfil = usePerfil();
  const t = perfil.tratamientos.find((x) => x.slug === slug);
  useTitulo(t?.nombre ?? "Tratamiento", t?.descripcion);
  if (!t) return <NoEncontrada titulo="No encontramos ese tratamiento" />;
  const ficha = fichaDe(t.slug, t.descripcion, t.motivo);
  const precio = soles(t.precio_desde);
  const llegar = perfil.opciones?.llegar_antes_min;
  return (
    <Plantilla>
      <Introduccion antetitulo={ficha.categoria} titulo={t.nombre} texto={ficha.resumen} />
      <section className="detail-layout page-shell">
        <article className="prose-column">
          <p className="detail-lead">{ficha.detalle}</p>
          {ficha.incluye.length > 0 && (
            <>
              <h2>¿Qué incluye?</h2>
              <ul className="check-list">
                {ficha.incluye.map((x) => (
                  <li key={x}>
                    <Check aria-hidden="true" />
                    {x}
                  </li>
                ))}
              </ul>
            </>
          )}
          <h2>¿Cómo es la atención?</h2>
          <ol className="step-list">
            {ficha.pasos.map((p, i) => (
              <li key={p}>
                <span>0{i + 1}</span>
                <p>{p}</p>
              </li>
            ))}
          </ol>
          {ficha.preguntas.length > 0 && (
            <>
              <h2>Preguntas sobre {t.nombre.toLowerCase()}</h2>
              <Preguntas items={ficha.preguntas} />
            </>
          )}
          <p className="sample-note">
            <span aria-hidden="true">i</span>La información es general y no reemplaza una evaluación en el consultorio.
          </p>
        </article>
        <aside className="detail-aside">
          <span className="detail-aside__icon">
            <Icono tipo={ficha.icono} />
          </span>
          <dl className="detail-aside__datos">
            {precio && (
              <div>
                <dt>Precio</dt>
                <dd>desde {precio}</dd>
              </div>
            )}
            <div>
              <dt>Duración</dt>
              <dd>{t.duracion_min} min</dd>
            </div>
          </dl>
          {t.reservable ? (
            <Reservar servicio={t.slug}>Reservar {t.nombre.toLowerCase()}</Reservar>
          ) : (
            <BotonWhatsapp texto="Consultar por WhatsApp" mensaje={`Hola, quisiera información sobre ${t.nombre}.`} />
          )}
          <p>Te confirmamos por WhatsApp{llegar ? ` y te pedimos llegar ${llegar} min antes` : ""}.</p>
        </aside>
      </section>
    </Plantilla>
  );
}

// --- Nosotros ------------------------------------------------------------------------------------------

export function Nosotros() {
  const perfil = usePerfil();
  useTitulo("Nosotros", `Conoce a ${perfil.doctor} y la forma de atender de ${perfil.nombre}.`);
  const c = perfil.contenido ?? {};
  const confianza = c.bloques_confianza ?? [];
  return (
    <Plantilla>
      <Introduccion
        antetitulo="Conócenos"
        titulo="Un consultorio pensado para escucharte"
        texto="Creemos que una buena atención empieza cuando puedes preguntar con confianza."
      />
      <section className="about-feature page-shell">
        <img src={perfil.foto || fotoConsultorio} alt={perfil.foto ? `Foto de ${perfil.doctor}` : "Atención en el consultorio"} />
        <div>
          <Antetitulo>Quién te atiende</Antetitulo>
          <h2>{perfil.doctor}</h2>
          {perfil.colegiatura && <p className="about-feature__cop">Colegiatura COP {perfil.colegiatura}</p>}
          <p>{perfil.presentacion}</p>
          <ul className="about-feature__datos">
            {c.anos_practica ? (
              <li>
                <BadgeCheck aria-hidden="true" /> {c.anos_practica} años de práctica
              </li>
            ) : null}
            {c.publico ? (
              <li>
                <Users aria-hidden="true" /> Atiende a {c.publico.charAt(0).toLowerCase() + c.publico.slice(1)}
              </li>
            ) : null}
            {c.formas_de_pago?.length ? (
              <li>
                <CreditCard aria-hidden="true" /> Pagos con {unirLista(c.formas_de_pago)}
              </li>
            ) : null}
          </ul>
          <Reservar />
        </div>
      </section>
      {confianza.length > 0 && (
        <section className="values-band">
          <div className="page-shell values-grid">
            {confianza.map((b, i) => {
              const IconoConfianza = ICONOS_CONFIANZA[i % ICONOS_CONFIANZA.length];
              return (
                <div key={b.titulo}>
                  <IconoConfianza aria-hidden="true" />
                  <h3>{b.titulo}</h3>
                  <p>{b.texto}</p>
                </div>
              );
            })}
          </div>
        </section>
      )}
      <section className="closing-band page-shell">
        <div>
          <Antetitulo>Da el primer paso</Antetitulo>
          <h2>Conversemos sobre lo que necesitas.</h2>
        </div>
        <Reservar servicio="evaluacion">Reservar evaluación</Reservar>
      </section>
    </Plantilla>
  );
}

// --- Preguntas, consejos, urgencias --------------------------------------------------------------------

export function PreguntasFrecuentes() {
  useTitulo("Preguntas frecuentes", "Cómo reservar, precios, formas de pago, cancelaciones y urgencias.");
  const preguntas = usePreguntas(PREGUNTAS);
  return (
    <Plantilla>
      <Introduccion
        antetitulo="Información útil"
        titulo="Preguntas frecuentes"
        texto="Lo que más nos preguntan antes de venir. Si tu duda no está aquí, escríbenos por WhatsApp."
      />
      <section className="faq-page page-shell">
        <Preguntas items={preguntas} />
        <div className="home-hero__actions">
          <Reservar />
          <BotonWhatsapp texto="Hacer una pregunta" />
        </div>
      </section>
    </Plantilla>
  );
}

export function Consejos() {
  useTitulo("Consejos", "Consejos simples para cuidar tu salud bucal y la de tu familia.");
  return (
    <Plantilla>
      <Introduccion
        antetitulo="Para ti y tu familia"
        titulo="Consejos para cuidar tu sonrisa"
        texto="Lecturas cortas para llegar mejor informado a tu consulta. No reemplazan una evaluación."
      />
      <section className="content-section page-shell">
        <div className="article-grid">
          {ARTICULOS.map((a, i) => (
            <Link key={a.slug} to={`/consejos/${a.slug}`} className="article-tile">
              <div className={`article-tile__art article-tile__art--${i % 3}`}>
                <span aria-hidden="true">0{i + 1}</span>
                <Sparkles aria-hidden="true" />
              </div>
              <div className="article-tile__body">
                <span className="article-category">{a.categoria}</span>
                <h3>{a.titulo}</h3>
                <p>{a.resumen}</p>
                <span className="article-tile__link">
                  Leer <ArrowUpRight aria-hidden="true" />
                </span>
              </div>
            </Link>
          ))}
        </div>
      </section>
    </Plantilla>
  );
}

export function Articulo() {
  const { slug = "" } = useParams();
  const a = ARTICULOS.find((x) => x.slug === slug);
  useTitulo(a?.titulo ?? "Consejo", a?.resumen);
  if (!a) return <NoEncontrada titulo="No encontramos ese consejo" />;
  return (
    <Plantilla>
      <Introduccion antetitulo={a.categoria} titulo={a.titulo} texto={a.resumen} />
      <article className="article-content page-shell">
        <p className="article-content__lead">{a.intro}</p>
        {a.secciones.map((s) => (
          <section key={s.titulo}>
            <h2>{s.titulo}</h2>
            <p>{s.texto}</p>
          </section>
        ))}
        <p className="article-content__conclusion">{a.cierre}</p>
        <div className="home-hero__actions">
          {a.servicio && <Reservar servicio={a.servicio} />}
          <Link to="/consejos" className="boton boton--contorno">
            Más consejos <ArrowRight aria-hidden="true" />
          </Link>
        </div>
      </article>
    </Plantilla>
  );
}

export function Urgencias() {
  useTitulo("Urgencias", "Qué hacer ante dolor de muela, un diente roto o un golpe. Reserva el primer horario libre.");
  return (
    <Plantilla>
      <Introduccion
        antetitulo="Atención prioritaria"
        titulo="¿Tienes dolor o una urgencia?"
        texto="Reserva el primer horario libre o escríbenos por WhatsApp. Te atendemos lo antes posible."
      />
      <section className="urgencias page-shell">
        <div className="urgencias__acciones">
          <Reservar servicio="urgencia-por-dolor">Reservar urgencia por dolor</Reservar>
          <BotonWhatsapp texto="Escribir ahora" mensaje="Hola, tengo una urgencia dental. ¿Tienen un espacio hoy?" />
        </div>
        <div className="urgencias__alerta">
          <h2>Acude a emergencias si…</h2>
          <ul className="check-list">
            <li>
              <Check aria-hidden="true" />
              Tienes hinchazón en la cara con fiebre.
            </li>
            <li>
              <Check aria-hidden="true" />
              Te cuesta tragar, respirar o abrir la boca.
            </li>
            <li>
              <Check aria-hidden="true" />
              Sufriste un golpe fuerte en la cara o la boca.
            </li>
            <li>
              <Check aria-hidden="true" />
              Hay un sangrado que no se detiene.
            </li>
          </ul>
        </div>
        <Link to="/consejos/dolor-de-muela-que-hacer" className="boton boton--contorno">
          Qué hacer mientras llegas <ArrowRight aria-hidden="true" />
        </Link>
      </section>
    </Plantilla>
  );
}

// --- Contacto ------------------------------------------------------------------------------------------

/** El enlace de Google Maps del panel convertido en mapa insertable (google.com está permitido en la CSP). */
function mapaInsertable(url: string): string | null {
  try {
    const q = new URL(url).searchParams.get("q");
    return q ? `https://www.google.com/maps?q=${encodeURIComponent(q)}&output=embed` : null;
  } catch {
    return null;
  }
}

export function Contacto() {
  const perfil = usePerfil();
  useTitulo("Contacto y horario", `Dirección, horario y WhatsApp de ${perfil.nombre}.`);
  const { hoy } = estadoApertura(perfil.horario);
  const mapa = mapaInsertable(perfil.mapa_url);
  const pagos = perfil.contenido?.formas_de_pago ?? [];
  const wa = whatsappUrl(perfil.whatsapp);
  return (
    <Plantilla>
      <Introduccion
        antetitulo="Contacto"
        titulo="Te esperamos en el consultorio"
        texto="Reserva en línea a cualquier hora. Si tienes una duda, escríbenos por WhatsApp."
      />
      <section className="contact-page page-shell">
        <div className="contact-page__details">
          <div className="contact-page__item">
            <span>
              <MapPin aria-hidden="true" />
            </span>
            <div>
              <h2>Dirección</h2>
              <p>{perfil.direccion}</p>
              {perfil.contenido?.referencias && <small>{perfil.contenido.referencias}</small>}
              <p>
                <a href={perfil.mapa_url} target="_blank" rel="noopener noreferrer" className="enlace">
                  Abrir en Google Maps <ArrowUpRight aria-hidden="true" />
                </a>
              </p>
            </div>
          </div>
          <div className="contact-page__item">
            <span>
              <Clock3 aria-hidden="true" />
            </span>
            <div>
              <h2>Horario</h2>
              <table className="horario">
                <tbody>
                  {perfil.horario.map((d) => (
                    <tr key={d.dia} className={d.dia_semana === hoy ? "horario__hoy" : ""}>
                      <th scope="row">
                        {d.dia}
                        {d.dia_semana === hoy && <span> · hoy</span>}
                      </th>
                      <td>{d.tramos.length ? d.tramos.join(" y ") : "Cerrado"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
          {wa && (
            <div className="contact-page__item">
              <span>
                <MessageCircle aria-hidden="true" />
              </span>
              <div>
                <h2>WhatsApp</h2>
                <p>
                  <a href={wa} target="_blank" rel="noopener noreferrer" className="enlace">
                    {telefonoVisible(perfil.whatsapp)}
                  </a>
                </p>
              </div>
            </div>
          )}
          {pagos.length > 0 && (
            <div className="contact-page__item">
              <span>
                <CreditCard aria-hidden="true" />
              </span>
              <div>
                <h2>Formas de pago</h2>
                <p>{unirLista(pagos)}</p>
              </div>
            </div>
          )}
        </div>
        <div className="contact-side">
          {mapa && (
            <iframe
              className="contact-map"
              title={`Mapa de ${perfil.nombre}`}
              src={mapa}
              loading="lazy"
              referrerPolicy="no-referrer-when-downgrade"
            />
          )}
          <div className="contact-form-wrap">
            <h2>Reserva tu cita</h2>
            <p>Elige el tratamiento y la hora. Sin crear cuenta: te confirmamos por WhatsApp.</p>
            <div className="home-hero__actions">
              <Reservar />
              <BotonWhatsapp />
            </div>
          </div>
        </div>
      </section>
    </Plantilla>
  );
}

export function NoEncontrada({ titulo = "Página no encontrada" }: { titulo?: string }) {
  useTitulo(titulo);
  return (
    <Plantilla>
      <section className="page-shell unavailable-page">
        <Antetitulo>Sonrisa Wari</Antetitulo>
        <h1>{titulo}</h1>
        <p>Puede que el enlace haya cambiado. Vuelve al inicio o reserva tu cita directamente.</p>
        <div className="home-hero__actions">
          <Link to="/" className="boton boton--contorno">
            Volver al inicio <ArrowRight aria-hidden="true" />
          </Link>
          <Reservar />
        </div>
      </section>
    </Plantilla>
  );
}
