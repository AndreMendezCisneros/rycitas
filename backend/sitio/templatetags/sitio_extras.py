from django import template
from django.utils.safestring import mark_safe

from sitio.seguridad import css_esencial as leer_css

register = template.Library()


@register.simple_tag
def css_esencial():
    return mark_safe(leer_css())  # archivo propio del proyecto, nunca datos de usuarios
