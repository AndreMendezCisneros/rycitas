"""Fotos a WebP al subirlas, para respetar el presupuesto de RWN-01: 150 KB por foto."""
from io import BytesIO

from django.core.files.base import ContentFile
from PIL import Image, ImageOps

MAX_BYTES = 150 * 1024


def a_webp(archivo, lado_maximo: int = 1200) -> ContentFile:
    imagen = ImageOps.exif_transpose(Image.open(archivo))
    imagen = imagen.convert("RGBA" if "A" in imagen.getbands() else "RGB")
    imagen.thumbnail((lado_maximo, lado_maximo))
    while True:
        for calidad in (82, 70, 58, 46, 34):
            salida = BytesIO()
            imagen.save(salida, "WEBP", quality=calidad, method=6)
            if salida.tell() <= MAX_BYTES:
                return ContentFile(salida.getvalue())
        imagen.thumbnail((imagen.width * 3 // 4, imagen.height * 3 // 4))
