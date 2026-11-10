import { useEffect, useState } from "react";

/**
 * Subdominio del negocio en RyCitas: de aquí salen tratamientos, precios, horario y contacto. Se toma del host
 * (sonrisawari.ryjec.com en producción, sonrisa-wari.localhost en desarrollo); en `npm run dev` (localhost) se usa
 * el de respaldo.
 */
const SLUG_RESPALDO = "sonrisa-wari";
export const SLUG = (() => {
  const partes = window.location.hostname.split(".");
  return partes.length >= 2 && /^[a-z0-9-]+$/.test(partes[0]) ? partes[0] : SLUG_RESPALDO;
})();

export type Tratamiento = {
  slug: string;
  nombre: string;
  motivo: string;
  descripcion: string;
  duracion_min: number;
  precio_desde: string | null;
  reservable: boolean;
};

export type DiaHorario = { dia: string; dia_semana: number; tramos: string[]; rangos: [string, string][] };

export type Perfil = {
  nombre: string;
  acepta_reservas: boolean;
  doctor: string;
  colegiatura: string;
  foto: string | null;
  presentacion: string;
  direccion: string;
  mapa_url: string;
  whatsapp: string;
  horario: DiaHorario[];
  tratamientos: Tratamiento[];
  opciones: { llegar_antes_min?: number };
  contenido?: {
    formas_de_pago?: string[];
    anos_practica?: number | null;
    publico?: string;
    referencias?: string;
    bloques_confianza?: { titulo: string; texto: string }[];
  };
};

const semana = (lv: [string, string][], sab: [string, string][]): DiaHorario[] =>
  ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"].map((dia, i) => {
    const rangos = i < 5 ? lv : i === 5 ? sab : [];
    return { dia, dia_semana: i, rangos, tramos: rangos.map(([a, b]) => `${hora12(a)} a ${hora12(b)}`) };
  });

/**
 * Copia de respaldo: se ve al instante y si la API no responde. Lo que vale es lo que dice el panel de RyCitas,
 * que reemplaza esto apenas llega.
 */
export const RESPALDO: Perfil = {
  nombre: "Sonrisa Wari",
  acepta_reservas: true,
  doctor: "Dra. Ana Quispe Rojas",
  colegiatura: "",
  foto: null,
  presentacion:
    "Atiendo a familias de Huamanga desde hace 12 años. Te explico cada paso con palabras simples y sin apuros.",
  direccion: "Jr. Asamblea 123, Ayacucho",
  mapa_url: "https://maps.google.com/?q=Plaza+de+Armas+Ayacucho",
  whatsapp: "",
  horario: semana(
    [
      ["09:00", "13:00"],
      ["15:00", "19:00"],
    ],
    [["09:00", "14:00"]],
  ),
  tratamientos: [
    { slug: "evaluacion", nombre: "Evaluación", motivo: "Es mi primera vez / no sé qué necesito", descripcion: "Revisión completa y plan de tratamiento.", duracion_min: 30, precio_desde: "40.00", reservable: true },
    { slug: "limpieza-dental", nombre: "Limpieza dental", motivo: "Quiero una limpieza", descripcion: "Retiro de sarro y pulido.", duracion_min: 45, precio_desde: "80.00", reservable: true },
    { slug: "urgencia-por-dolor", nombre: "Urgencia por dolor", motivo: "Tengo dolor", descripcion: "Atención para aliviar el dolor lo antes posible.", duracion_min: 30, precio_desde: "60.00", reservable: true },
    { slug: "curacion", nombre: "Curación", motivo: "Tengo una caries o se me rompió un diente", descripcion: "Restauración con resina.", duracion_min: 45, precio_desde: "90.00", reservable: true },
    { slug: "blanqueamiento", nombre: "Blanqueamiento", motivo: "Quiero blanquear mis dientes", descripcion: "Sesión en consultorio.", duracion_min: 60, precio_desde: "350.00", reservable: true },
    { slug: "control-de-ortodoncia", nombre: "Control de ortodoncia", motivo: "Tengo control de brackets", descripcion: "Ajuste mensual.", duracion_min: 20, precio_desde: "70.00", reservable: true },
  ],
  opciones: { llegar_antes_min: 15 },
  contenido: { formas_de_pago: ["Efectivo", "Yape", "Plin"], anos_practica: 12, publico: "Niños, adultos y personas mayores" },
};

let pedido: Promise<Perfil> | null = null;
let ultimo: Perfil | null = null;

function cargar(): Promise<Perfil> {
  pedido ??= fetch(`/public/v1/${SLUG}/perfil`, { headers: { Accept: "application/json" } })
    .then((r) => (r.ok ? (r.json() as Promise<Perfil>) : Promise.reject(new Error(String(r.status)))))
    .then((p) => (ultimo = p))
    .catch(() => {
      pedido = null; // se reintenta en la próxima página
      return RESPALDO;
    });
  return pedido;
}

/** El perfil del negocio: primero la copia de respaldo y, en cuanto llega, lo que dice RyCitas. */
export function usePerfil(): Perfil {
  const [perfil, setPerfil] = useState<Perfil>(ultimo ?? RESPALDO);
  useEffect(() => {
    let vivo = true;
    cargar().then((p) => vivo && setPerfil(p));
    return () => {
      vivo = false;
    };
  }, []);
  return perfil;
}

// --- Formato -----------------------------------------------------------------------------------------

export function hora12(hhmm: string): string {
  const [h, m] = hhmm.split(":").map(Number);
  const sufijo = h < 12 ? "a. m." : "p. m.";
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${h12}:${String(m).padStart(2, "0")} ${sufijo}`;
}

export function soles(precio: string | null): string | null {
  if (precio == null) return null;
  const n = Number(precio);
  if (!Number.isFinite(n)) return null;
  return Number.isInteger(n) ? `S/ ${n}` : `S/ ${n.toFixed(2)}`;
}

export function whatsappUrl(numero: string, texto = "Hola, quisiera hacer una consulta."): string | null {
  const limpio = numero.replace(/\D/g, "");
  return limpio ? `https://wa.me/${limpio}?text=${encodeURIComponent(texto)}` : null;
}

export function telefonoVisible(numero: string): string {
  const d = numero.replace(/\D/g, "");
  const local = d.startsWith("51") ? d.slice(2) : d;
  return local.length === 9 ? `${local.slice(0, 3)} ${local.slice(3, 6)} ${local.slice(6)}` : numero;
}

/** Enlace de reserva de RyCitas, con el tratamiento ya elegido si se indica. */
export function enlaceReserva(servicio?: string): string {
  return servicio ? `/reservar/?servicio=${encodeURIComponent(servicio)}` : "/reservar/";
}

// --- ¿Abierto ahora? (hora de Lima) ------------------------------------------------------------------

const DIAS_EN = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

function ahoraEnLima(fecha = new Date()): { dia: number; minutos: number } {
  const partes = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/Lima",
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(fecha);
  const valor = (t: string) => partes.find((p) => p.type === t)?.value ?? "";
  return { dia: DIAS_EN.indexOf(valor("weekday")), minutos: Number(valor("hour")) * 60 + Number(valor("minute")) };
}

const aMinutos = (hhmm: string) => {
  const [h, m] = hhmm.split(":").map(Number);
  return h * 60 + m;
};

export type EstadoApertura = { abierto: boolean; texto: string; hoy: number };

export function estadoApertura(horario: DiaHorario[], fecha = new Date()): EstadoApertura {
  const { dia, minutos } = ahoraEnLima(fecha);
  const deHoy = horario.find((d) => d.dia_semana === dia);
  const abiertoAhora = deHoy?.rangos.find(([a, b]) => minutos >= aMinutos(a) && minutos < aMinutos(b));
  if (abiertoAhora) return { abierto: true, hoy: dia, texto: `Abierto ahora · hasta las ${hora12(abiertoAhora[1])}` };
  const luegoHoy = deHoy?.rangos.find(([a]) => aMinutos(a) > minutos);
  if (luegoHoy) return { abierto: false, hoy: dia, texto: `Cerrado ahora · abre hoy a las ${hora12(luegoHoy[0])}` };
  for (let i = 1; i <= 7; i++) {
    const siguiente = horario.find((d) => d.dia_semana === (dia + i) % 7);
    if (siguiente?.rangos.length) {
      const cuando = i === 1 ? "mañana" : `el ${siguiente.dia.toLowerCase()}`;
      return { abierto: false, hoy: dia, texto: `Cerrado ahora · abre ${cuando} a las ${hora12(siguiente.rangos[0][0])}` };
    }
  }
  return { abierto: false, hoy: dia, texto: "Cerrado" };
}

/** «Lun–Vie 9:00 a. m. a 1:00 p. m. y 3:00 p. m. a 7:00 p. m.»: agrupa los días seguidos con el mismo horario. */
export function horarioResumido(horario: DiaHorario[]): string[] {
  const cortos = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"];
  const grupos: { desde: number; hasta: number; tramos: string }[] = [];
  for (const d of [...horario].sort((a, b) => a.dia_semana - b.dia_semana)) {
    if (!d.tramos.length) continue;
    const tramos = d.tramos.join(" y ");
    const ultimo = grupos[grupos.length - 1];
    if (ultimo && ultimo.tramos === tramos && ultimo.hasta === d.dia_semana - 1) ultimo.hasta = d.dia_semana;
    else grupos.push({ desde: d.dia_semana, hasta: d.dia_semana, tramos });
  }
  return grupos.map((g) =>
    `${g.desde === g.hasta ? cortos[g.desde] : `${cortos[g.desde]}–${cortos[g.hasta]}`}: ${g.tramos}`,
  );
}
