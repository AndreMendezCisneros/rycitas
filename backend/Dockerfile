FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
# Los valores solo existen durante la construcción: collectstatic no usa la base ni los secretos reales.
RUN DJANGO_SECRET_KEY=solo-para-construir python manage.py collectstatic --noinput

RUN useradd --create-home --uid 1000 denticita && mkdir -p /media && chown denticita /media
USER denticita

EXPOSE 8000
# --graceful-timeout: al detenerse termina lo que está atendiendo (compose le da 35 s). --max-requests recicla cada
# worker de a poco para que una fuga de memoria no llegue al límite del contenedor.
CMD ["gunicorn", "denticita.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2", "--threads", "4", \
     "--timeout", "30", "--graceful-timeout", "25", "--max-requests", "1000", "--max-requests-jitter", "100", \
     "--access-logfile", "-"]
