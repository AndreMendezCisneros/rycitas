"""Textos fijos de la plataforma. Cambian solo con el vocabulario del tipo de negocio y sus opciones."""
from django.conf import settings

from consultorios.models import Consultorio


def pasos_reserva(consultorio: Consultorio | None = None) -> list[tuple[str, str]]:
    voc = consultorio.vocabulario if consultorio else {"servicio": "motivo", "el_local": "el consultorio"}
    pasos = [
        (f"Elige el {voc['servicio']}", "Cuéntanos qué necesitas, con palabras simples."),
        ("Elige día y hora", "Solo ves los horarios que de verdad están libres."),
        ("Deja tus datos", "Tu nombre y tu WhatsApp. No tienes que crear una cuenta ni una contraseña."),
    ]
    if consultorio is not None and consultorio.opciones_efectivas["elegir_profesional"]:
        pasos.insert(1, ("Elige con quién", f"Elige a tu {voc['profesional']} o deja que te asignemos al primero libre."))
    if settings.VERIFICACION_WHATSAPP:
        pasos.append(("Confirma por WhatsApp", "Envías un mensaje ya escrito y tu cita queda lista."))
    else:
        pasos.append(
            ("Te escribimos por WhatsApp", f"{voc['el_local'].capitalize()} te escribe para confirmar. Te guardamos el horario.")
        )
    return pasos


# (id, pregunta). Las respuestas dependen de las reglas del negocio y se arman en preguntas_visibles.
PREGUNTAS = [
    ("costo", "¿Reservar cuesta algo?"),
    ("whatsapp", "¿Cómo se confirma mi cita?"),
    ("sin-whatsapp", "¿Y si no tengo WhatsApp?"),
    ("cambiar", "¿Puedo cambiar o cancelar mi cita?"),
    ("pago", "¿Cuándo y cómo pago?"),
    ("precio", "¿Puedo ofrecer otro precio?"),
    ("llegar", "¿Con cuánta anticipación llego?"),
    ("dolor", "Tengo mucho dolor, ¿qué hago?"),
]


def preguntas_visibles(consultorio: Consultorio) -> list[dict]:
    contenido = consultorio.contenido
    voc = consultorio.vocabulario
    opciones = consultorio.opciones_efectivas
    formas = ", ".join(contenido["formas_de_pago"])
    local = voc["el_local"]
    al_local = "al " + local[3:] if local.startswith("el ") else "a " + local  # «al consultorio», «a la barbería»
    if settings.VERIFICACION_WHATSAPP:
        horas = consultorio.reglas_efectivas["limite_cancelacion_horas"]
        confirmacion = {
            "whatsapp": "Envías un mensaje ya escrito por WhatsApp. Así comprobamos que el número es tuyo y que nadie reserve en tu nombre.",
            "sin-whatsapp": f"Al confirmar verás la opción «No tengo WhatsApp». Tu reserva queda por aprobar y {local} la revisa.",
            "cambiar": (
                f"Sí, desde este mismo celular o desde tu enlace, hasta {horas} horas antes. "
                f"Después de ese plazo, escríbele {al_local} por WhatsApp."
            ),
        }
    else:
        confirmacion = {
            "whatsapp": (
                f"Al reservar te guardamos el horario y {local} te escribe por WhatsApp para confirmarla "
                "con todos los datos de tu cita. El día anterior también te la recuerda."
            ),
            "sin-whatsapp": f"Reserva igual con tu celular y llama {al_local} para confirmar tu cita.",
            "cambiar": f"Sí. Escríbele {al_local} por WhatsApp y te ayudan a cambiarla o cancelarla.",
        }
    respuestas = {
        "costo": "No. Reservar es gratis y no tiene ningún costo adicional.",
        **confirmacion,
        "pago": f"Pagas en {local}, después de tu atención.{f' Aceptamos: {formas}.' if formas else ''}",
        "precio": (
            "Sí. Al reservar ves el precio de referencia y puedes ofrecer otro. "
            f"{local.capitalize()} acepta tu oferta o te propone el precio final al confirmar por WhatsApp."
        ),
        "llegar": f"Te pedimos llegar {opciones['llegar_antes_min']} minutos antes de tu hora, por si acaso.",
        "dolor": "Elige el motivo de dolor y toma la primera hora libre. Si no hay una pronto, escríbele al consultorio por WhatsApp.",
    }
    aplica = {
        "precio": opciones["precio_ofertable"],
        "llegar": bool(opciones["llegar_antes_min"]),
        "dolor": consultorio.rubro == "odontologia",
    }
    ocultas = set(contenido["faq_ocultas"])
    return [
        {"pregunta": p, "respuesta": respuestas[i]}
        for i, p in PREGUNTAS
        if i not in ocultas and aplica.get(i, True)
    ]
