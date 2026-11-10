/**
 * Textos del sitio que no viven en RyCitas: la explicación de cada tratamiento, las preguntas y los consejos.
 * Precios, duraciones, horario y contacto NO van aquí: salen del panel (datos.ts) para que nunca se contradigan.
 */

export type Ficha = {
  categoria: string;
  icono: "evaluacion" | "limpieza" | "urgencia" | "curacion" | "blanqueamiento" | "ortodoncia" | "general";
  resumen: string;
  detalle: string;
  incluye: string[];
  pasos: string[];
  preguntas: { pregunta: string; respuesta: string }[];
};

export const FICHAS: Record<string, Ficha> = {
  evaluacion: {
    categoria: "Primera visita",
    icono: "evaluacion",
    resumen: "Si es tu primera vez o no sabes qué necesitas, empieza aquí. Revisamos todo y te explicamos con calma.",
    detalle:
      "En la evaluación revisamos dientes, encías y mordida, escuchamos lo que te molesta y te damos un plan claro: qué conviene hacer, en qué orden y cuánto costaría. Sin presiones: decides tú.",
    incluye: ["Revisión completa de dientes y encías", "Plan de tratamiento por escrito, con precios", "Respuestas a tus dudas, con palabras simples"],
    pasos: ["Nos cuentas qué te trae y tus antecedentes", "La doctora revisa tu boca con calma", "Te explicamos el plan y eliges cómo seguir"],
    preguntas: [
      { pregunta: "¿Tengo que llevar algo?", respuesta: "Si tienes radiografías o recetas anteriores, tráelas. Si no, no te preocupes." },
      { pregunta: "¿Me harán un tratamiento ese mismo día?", respuesta: "Solo si tú quieres y hay tiempo. La evaluación es para conocerte y planear." },
    ],
  },
  "limpieza-dental": {
    categoria: "Prevención",
    icono: "limpieza",
    resumen: "Retiramos el sarro y pulimos tus dientes para cuidar tus encías y prevenir problemas.",
    detalle:
      "Con el tiempo se acumula sarro que el cepillo no saca y que irrita las encías. La limpieza lo retira, pule los dientes y te deja recomendaciones para tu cepillado diario.",
    incluye: ["Retiro de sarro sobre y bajo la encía", "Pulido de dientes", "Consejos de cepillado e hilo dental para ti"],
    pasos: ["Revisamos tus encías", "Retiramos el sarro con instrumental esterilizado", "Pulimos y te damos recomendaciones"],
    preguntas: [
      { pregunta: "¿Duele?", respuesta: "Por lo general se siente una molestia leve. Si tus encías están sensibles, avísanos y vamos con más cuidado." },
      { pregunta: "¿Cada cuánto conviene?", respuesta: "Depende de cada persona; muchas vuelven cada 6 meses. En la consulta te diremos lo que te conviene a ti." },
    ],
  },
  "urgencia-por-dolor": {
    categoria: "Atención prioritaria",
    icono: "urgencia",
    resumen: "Si tienes dolor, busca el primer horario libre. Nuestro objetivo es aliviarte lo antes posible.",
    detalle:
      "En la urgencia buscamos la causa del dolor y lo aliviamos. Si hace falta un tratamiento más largo, te lo explicamos y lo programamos contigo.",
    incluye: ["Atención en el primer horario disponible", "Alivio del dolor", "Plan para resolver la causa"],
    pasos: ["Reserva el primer horario libre", "Te atendemos y aliviamos el dolor", "Te explicamos qué sigue"],
    preguntas: [
      { pregunta: "¿Y si no hay horario hoy?", respuesta: "Escríbenos por WhatsApp: si podemos hacerte un espacio, te avisamos. Si el dolor es muy fuerte o hay hinchazón con fiebre, acude a emergencias." },
      { pregunta: "¿Puedo tomar algo para el dolor?", respuesta: "No te automediques sin consultar. Cuéntanos qué sientes y te orientamos." },
    ],
  },
  curacion: {
    categoria: "Tratamientos",
    icono: "curacion",
    resumen: "Para una caries o un diente roto: lo restauramos con resina del color de tu diente.",
    detalle:
      "La curación limpia la parte dañada del diente y la rellena con resina del mismo color, para que vuelva a funcionar bien y se vea natural.",
    incluye: ["Limpieza de la caries", "Restauración con resina del color del diente", "Ajuste de la mordida"],
    pasos: ["Revisamos el diente", "Retiramos la caries y preparamos el diente", "Colocamos la resina y ajustamos la mordida"],
    preguntas: [
      { pregunta: "¿Se nota la curación?", respuesta: "La resina se elige del color de tu diente, así que casi no se nota." },
      { pregunta: "¿Puedo comer después?", respuesta: "Sí, aunque si te pusimos anestesia, espera a que pase para no morderte." },
    ],
  },
  blanqueamiento: {
    categoria: "Estética",
    icono: "blanqueamiento",
    resumen: "Aclaramos el tono de tus dientes en el consultorio, después de revisar que tu boca esté sana.",
    detalle:
      "Antes de blanquear revisamos tus dientes y encías: si hay caries o sarro, conviene tratarlos primero. Cada persona responde distinto, así que te diremos con honestidad qué esperar.",
    incluye: ["Revisión previa de dientes y encías", "Sesión de blanqueamiento en consultorio", "Cuidados para los días siguientes"],
    pasos: ["Revisamos que tu boca esté lista", "Protegemos encías y aplicamos el gel", "Te damos los cuidados para mantener el resultado"],
    preguntas: [
      { pregunta: "¿El resultado es igual para todos?", respuesta: "No. Depende de tus dientes y de la causa de la coloración. Te lo explicamos antes de empezar." },
      { pregunta: "¿Da sensibilidad?", respuesta: "Puede dar sensibilidad pasajera. Te diremos cómo aliviarla." },
    ],
  },
  "control-de-ortodoncia": {
    categoria: "Ortodoncia",
    icono: "ortodoncia",
    resumen: "Tu control mensual de brackets: ajustamos y revisamos cómo avanza tu tratamiento.",
    detalle:
      "En cada control revisamos el avance, cambiamos ligas o arcos cuando toca y resolvemos cualquier molestia con los brackets.",
    incluye: ["Revisión del avance", "Ajuste o cambio de ligas y arcos", "Revisión de brackets sueltos o molestias"],
    pasos: ["Revisamos cómo van tus dientes", "Hacemos el ajuste que corresponde", "Agendamos tu próximo control"],
    preguntas: [
      { pregunta: "¿Qué hago si se me suelta un bracket?", respuesta: "Escríbenos por WhatsApp y te damos el primer espacio libre." },
      { pregunta: "¿Es normal sentir presión después?", respuesta: "Sí, unos días es normal. Si hay dolor fuerte, avísanos." },
    ],
  },
};

/** Para un tratamiento que se agregue en el panel y aún no tenga texto aquí: se arma con lo que dice el panel. */
export function fichaDe(slug: string, descripcion: string, motivo: string): Ficha {
  return (
    FICHAS[slug] ?? {
      categoria: "Tratamiento",
      icono: "general",
      resumen: descripcion || motivo,
      detalle: descripcion || "Te explicamos en qué consiste en la consulta.",
      incluye: [],
      pasos: ["Reserva tu cita en línea", "Te confirmamos por WhatsApp", "Te atendemos y te explicamos cada paso"],
      preguntas: [],
    }
  );
}

export const PREGUNTAS = [
  {
    pregunta: "¿Cómo reservo una cita?",
    respuesta:
      "Toca «Reservar cita», elige el tratamiento y la hora que te quede bien, y deja tu nombre y celular. No necesitas crear una cuenta. Te confirmamos por WhatsApp.",
  },
  {
    pregunta: "¿Cuánto cuesta?",
    respuesta:
      "Cada tratamiento muestra su precio «desde». El precio final depende de tu caso y te lo decimos antes de empezar, sin sorpresas.",
  },
  {
    pregunta: "¿Cómo puedo pagar?",
    respuesta: "PAGOS", // se reemplaza con las formas de pago del panel
  },
  {
    pregunta: "¿Atienden a niños?",
    respuesta: "PUBLICO",
  },
  {
    pregunta: "¿Qué pasa si no puedo ir?",
    respuesta:
      "Escríbenos por WhatsApp lo antes posible, o usa el enlace de tu cita, para darle el espacio a otra persona y buscarte un nuevo horario.",
  },
  {
    pregunta: "¿Cuánto tengo que esperar en el consultorio?",
    respuesta:
      "Poco. Trabajamos con cita y, si la doctora se demora, te avisamos por WhatsApp y en el enlace de tu cita ves la hora estimada.",
  },
  {
    pregunta: "¿Qué hago si tengo una urgencia?",
    respuesta:
      "Reserva «Urgencia por dolor» en el primer horario libre o escríbenos por WhatsApp. Si hay hinchazón con fiebre, sangrado que no para o un golpe fuerte en la cara, acude a emergencias.",
  },
  {
    pregunta: "¿Esta página puede decirme qué tengo?",
    respuesta: "No. La información es general y no reemplaza una evaluación en el consultorio.",
  },
];

export type Articulo = {
  slug: string;
  categoria: string;
  titulo: string;
  resumen: string;
  intro: string;
  secciones: { titulo: string; texto: string }[];
  cierre: string;
  servicio?: string;
};

export const ARTICULOS: Articulo[] = [
  {
    slug: "primera-consulta-dental",
    categoria: "Primera visita",
    titulo: "Qué esperar de tu primera consulta dental",
    resumen: "Si hace tiempo que no vas al dentista, es normal tener dudas. Así es una evaluación.",
    intro: "Una primera visita es, sobre todo, una conversación. Saber qué pasa te ayuda a llegar tranquilo.",
    secciones: [
      { titulo: "Cuenta lo que te preocupa", texto: "Dolor, sensibilidad, un diente roto o simplemente que quieres revisarte: todo sirve para entender lo que necesitas." },
      { titulo: "La revisión es personal", texto: "La doctora revisa tus dientes y encías y te muestra lo que encuentra. Si recomienda algo, te explica por qué." },
      { titulo: "Pregunta todo", texto: "Precio, número de visitas, cuidados: pregunta lo que quieras. Tú decides cómo seguir." },
    ],
    cierre: "Una evaluación es el mejor primer paso si no sabes por dónde empezar.",
    servicio: "evaluacion",
  },
  {
    slug: "rutina-de-higiene-bucal",
    categoria: "Prevención",
    titulo: "Una rutina de higiene bucal que sí puedas mantener",
    resumen: "Pequeños hábitos de todos los días hacen la diferencia en cada control.",
    intro: "No hace falta una rutina perfecta: hace falta una que cumplas todos los días.",
    secciones: [
      { titulo: "Cepíllate con calma", texto: "Dos veces al día, sin apuro, llegando a todas las caras de los dientes y al borde de la encía." },
      { titulo: "No te olvides del hilo dental", texto: "Limpia donde el cepillo no llega. Si te sangran las encías al empezar, suele mejorar en unos días; si no, consúltanos." },
      { titulo: "Ven a tus controles", texto: "Una limpieza a tiempo evita tratamientos más largos. Te diremos cada cuánto te conviene." },
    ],
    cierre: "En tu próxima limpieza te enseñamos la técnica que mejor va contigo.",
    servicio: "limpieza-dental",
  },
  {
    slug: "dolor-de-muela-que-hacer",
    categoria: "Urgencias",
    titulo: "Dolor de muela: qué hacer mientras llegas al consultorio",
    resumen: "El dolor no suele irse solo. Esto puedes hacer mientras consigues tu cita.",
    intro: "El dolor de muela es una señal de que algo necesita atención. Lo importante es no dejarlo pasar.",
    secciones: [
      { titulo: "Reserva lo antes posible", texto: "Busca el primer horario libre de «Urgencia por dolor». Mientras antes se trate, más simple suele ser." },
      { titulo: "Evita lo que empeora", texto: "Comidas muy frías, calientes o duras pueden aumentar la molestia. Mastica del otro lado." },
      { titulo: "Cuándo ir a emergencias", texto: "Si hay hinchazón con fiebre, dificultad para tragar o abrir la boca, o un golpe fuerte, acude a emergencias de inmediato." },
    ],
    cierre: "No te automediques sin consultar: escríbenos y te orientamos.",
    servicio: "urgencia-por-dolor",
  },
  {
    slug: "salud-bucal-de-ninos",
    categoria: "Niños",
    titulo: "Cómo acompañar la salud bucal de tus hijos",
    resumen: "Una primera visita tranquila ayuda a que los niños no le teman al dentista.",
    intro: "Los dientes de leche también importan: guardan el espacio para los definitivos y ayudan a comer y hablar bien.",
    secciones: [
      { titulo: "Háblale con naturalidad", texto: "Evita frases como «no te va a doler». Mejor: «la doctora va a contar tus dientes»." },
      { titulo: "Cepíllalo tú hasta que aprenda", texto: "Los niños pequeños necesitan ayuda para cepillarse bien. Supervisa hasta que lo hagan solos." },
      { titulo: "Cuida los dulces entre comidas", texto: "No se trata de prohibir, sino de no picar azúcar todo el día. Después de un dulce, agua y cepillo." },
    ],
    cierre: "Trae a tu hijo a una evaluación: le explicamos todo con paciencia.",
    servicio: "evaluacion",
  },
];
