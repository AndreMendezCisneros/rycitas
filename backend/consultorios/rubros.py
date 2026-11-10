"""Tipos de negocio: vocabulario, servicios y horario con los que nace cada negocio.

Los modelos se siguen llamando Consultorio, Paciente y Tratamiento; lo que ve cada negocio sale de aquí. Una barbería
dice «cliente», «servicio» y «barbero»; un consultorio dental, «paciente», «tratamiento» y «doctor».
"""
from __future__ import annotations

from datetime import time

_LV = range(0, 5)  # lunes a viernes
_LS = range(0, 6)  # lunes a sábado


def _tramos(dias, *tramos):
    return [(d, inicio, fin) for d in dias for inicio, fin in tramos]


_VOC_BASE = {
    "cliente": "cliente",
    "clientes": "clientes",
    "servicio": "servicio",
    "servicios": "servicios",
    "profesional": "profesional",
    "profesionales": "profesionales",
    "local": "local",
    "el_local": "el local",
    "del_local": "del local",
}


def _voc(**cambios) -> dict:
    return {**_VOC_BASE, **cambios}


_CONFIANZA_SALUD = [
    {"titulo": "Bioseguridad", "texto": "Instrumental esterilizado para cada paciente y superficies desinfectadas entre citas."},
    {"titulo": "Materiales de un solo uso", "texto": "Guantes, mascarillas y agujas se abren frente a ti y se desechan al terminar."},
    {"titulo": "Sala sin aglomeración", "texto": "Con cita y hora estimada, esperas poco y sin mucha gente alrededor."},
]
_CONFIANZA_BELLEZA = [
    {"titulo": "Herramientas limpias", "texto": "Desinfectamos peines, tijeras y máquinas entre cada cliente."},
    {"titulo": "Sin colas", "texto": "Con tu hora reservada te atendemos a tiempo, sin esperar turno."},
    {"titulo": "Precios claros", "texto": "Ves el precio de referencia antes de reservar."},
]

RUBROS: dict[str, dict] = {
    "odontologia": {
        "nombre": "Odontología",
        "vocabulario": _voc(
            cliente="paciente", clientes="pacientes", servicio="tratamiento", servicios="tratamientos",
            profesional="doctor", profesionales="doctores", local="consultorio", el_local="el consultorio",
            del_local="del consultorio",
        ),
        "titulo": ("Reserva tu cita dental en", "un minuto"),
        "pregunta_servicio": "¿Qué te trae por aquí?",
        "color": "#1f6fb2",
        "llegar_antes_min": 15,
        "salud": True,
        "confianza": _CONFIANZA_SALUD,
        "horario": _tramos(_LV, (time(9), time(13)), (time(15), time(19))) + _tramos([5], (time(9), time(13))),
        "servicios": [
            ("Evaluación", "No sé qué tengo / quiero una revisión", 30, 0, 50, "Trae tus radiografías si tienes."),
            ("Limpieza dental", "Quiero una limpieza", 40, 10, 80, ""),
            ("Curación", "Tengo una caries", 45, 10, 100, ""),
            ("Extracción", "Necesito sacarme un diente", 45, 15, 120, "Come algo ligero antes de venir."),
            ("Endodoncia", "Me dijeron que necesito endodoncia", 120, 15, 450, ""),
            ("Blanqueamiento", "Quiero dientes más blancos", 60, 10, 350, ""),
            ("Urgencia por dolor", "Tengo dolor", 30, 10, 60, ""),
        ],
    },
    "barberia": {
        "nombre": "Barbería",
        "vocabulario": _voc(
            profesional="barbero", profesionales="barberos", local="barbería", el_local="la barbería",
            del_local="de la barbería",
        ),
        "titulo": ("Reserva tu corte en", "un minuto"),
        "pregunta_servicio": "¿Qué te quieres hacer?",
        "color": "#8a5a2b",
        "llegar_antes_min": 5,
        "salud": False,
        "confianza": _CONFIANZA_BELLEZA,
        "horario": _tramos(_LS, (time(9), time(20))) + _tramos([6], (time(9), time(14))),
        "servicios": [
            ("Corte clásico", "Corte de cabello", 30, 5, 20, ""),
            ("Corte + barba", "Corte y arreglo de barba", 45, 5, 30, ""),
            ("Perfilado de barba", "Solo la barba", 20, 5, 12, ""),
            ("Ondulado / permanente", "Quiero ondulado", 90, 10, 60, "Ven con el cabello limpio y seco."),
            ("Tinte", "Quiero cambiar de color", 60, 10, 40, ""),
            ("Corte para niño", "Corte para niño", 25, 5, 15, ""),
        ],
    },
    "peluqueria": {
        "nombre": "Peluquería / salón de belleza",
        "vocabulario": _voc(
            profesional="estilista", profesionales="estilistas", local="salón", el_local="el salón",
            del_local="del salón",
        ),
        "titulo": ("Reserva tu cita en el salón en", "un minuto"),
        "pregunta_servicio": "¿Qué te quieres hacer?",
        "color": "#b0417a",
        "llegar_antes_min": 10,
        "salud": False,
        "confianza": _CONFIANZA_BELLEZA,
        "horario": _tramos(_LS, (time(9), time(19))),
        "servicios": [
            ("Corte de dama", "Corte de cabello", 45, 5, 35, ""),
            ("Tinte", "Quiero cambiar de color", 120, 10, 90, ""),
            ("Mechas / balayage", "Quiero mechas", 150, 10, 150, ""),
            ("Laceado", "Quiero el cabello lacio", 180, 10, 180, "Ven con el cabello limpio y seco."),
            ("Peinado", "Peinado para un evento", 60, 5, 50, ""),
            ("Manicure", "Arreglo de uñas", 45, 5, 25, ""),
        ],
    },
    "estetica": {
        "nombre": "Estética / spa",
        "vocabulario": _voc(
            profesional="especialista", profesionales="especialistas", local="centro", el_local="el centro",
            del_local="del centro",
        ),
        "titulo": ("Reserva tu momento en", "un minuto"),
        "pregunta_servicio": "¿Qué te gustaría hacerte?",
        "color": "#5b8c6f",
        "llegar_antes_min": 10,
        "salud": False,
        "confianza": _CONFIANZA_BELLEZA,
        "horario": _tramos(_LS, (time(10), time(19))),
        "servicios": [
            ("Limpieza facial", "Limpieza de cutis", 60, 10, 70, ""),
            ("Masaje relajante", "Quiero un masaje", 60, 10, 80, ""),
            ("Depilación", "Depilación", 30, 5, 40, ""),
            ("Extensión de pestañas", "Pestañas", 90, 10, 90, ""),
            ("Uñas acrílicas", "Uñas", 90, 10, 60, ""),
        ],
    },
    "salud": {
        "nombre": "Salud (psicología, nutrición, terapia)",
        "vocabulario": _voc(
            cliente="paciente", clientes="pacientes", profesional="especialista", profesionales="especialistas",
            local="consultorio", el_local="el consultorio", del_local="del consultorio",
        ),
        "titulo": ("Reserva tu consulta en", "un minuto"),
        "pregunta_servicio": "¿Qué consulta necesitas?",
        "color": "#3c7d8c",
        "llegar_antes_min": 15,
        "salud": True,
        "confianza": _CONFIANZA_SALUD[2:] + [
            {"titulo": "Confidencialidad", "texto": "Tu consulta es privada. Solo guardamos tu nombre y tu celular para la cita."},
            {"titulo": "Puntualidad", "texto": "Respetamos tu hora: la sesión empieza y termina a tiempo."},
        ],
        "horario": _tramos(_LV, (time(9), time(13)), (time(15), time(19))),
        "servicios": [
            ("Primera consulta", "Es mi primera vez", 60, 10, 100, ""),
            ("Consulta de control", "Ya soy paciente", 45, 10, 80, ""),
            ("Sesión de terapia", "Sesión de terapia", 50, 10, 90, ""),
        ],
    },
    "veterinaria": {
        "nombre": "Veterinaria",
        "vocabulario": _voc(
            profesional="veterinario", profesionales="veterinarios", local="veterinaria", el_local="la veterinaria",
            del_local="de la veterinaria",
        ),
        "titulo": ("Reserva la cita de tu mascota en", "un minuto"),
        "pregunta_servicio": "¿Qué necesita tu mascota?",
        "color": "#c0702a",
        "llegar_antes_min": 10,
        "salud": False,
        "confianza": [
            {"titulo": "Trato con cariño", "texto": "Atendemos a tu mascota con calma y sin apuros."},
            {"titulo": "Instrumental limpio", "texto": "Esterilizamos el instrumental entre cada paciente."},
            {"titulo": "Sin esperas largas", "texto": "Con tu hora reservada, tu mascota no pasa horas en la sala."},
        ],
        "horario": _tramos(_LS, (time(9), time(19))),
        "servicios": [
            ("Consulta general", "Mi mascota está enferma / revisión", 30, 5, 50, "Trae su carné de vacunas."),
            ("Vacunación", "Vacunas", 20, 5, 60, "Trae su carné de vacunas."),
            ("Desparasitación", "Desparasitar", 20, 5, 30, ""),
            ("Baño", "Baño", 60, 10, 40, ""),
            ("Baño y corte", "Baño y corte de pelo", 90, 10, 60, ""),
        ],
    },
    "otro": {
        "nombre": "Otro negocio",
        "vocabulario": _voc(),
        "titulo": ("Reserva tu cita en", "un minuto"),
        "pregunta_servicio": "¿Qué necesitas?",
        "color": "#3d5a80",
        "llegar_antes_min": 10,
        "salud": False,
        "confianza": [
            {"titulo": "Atención puntual", "texto": "Con tu hora reservada te atendemos a tiempo."},
            {"titulo": "Sin colas", "texto": "Eliges tu horario y llegas directo a tu atención."},
            {"titulo": "Precios claros", "texto": "Ves el precio de referencia antes de reservar."},
        ],
        "horario": _tramos(_LV, (time(9), time(18))),
        "servicios": [
            ("Atención general", "Atención", 30, 5, None, ""),
        ],
    },
}

RUBRO_CHOICES = [(clave, datos["nombre"]) for clave, datos in RUBROS.items()]


def rubro(clave: str | None) -> dict:
    return RUBROS.get(clave or "", RUBROS["otro"])
