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
CMD ["gunicorn", "denticita.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2", "--threads", "4", "--timeout", "30", "--access-logfile", "-"]
