import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// Todo se muestra en hora de Lima, aunque el teléfono esté en otra zona (RNF-16).
class Fechas {
  Fechas._();

  static tz.Location get lima => tz.getLocation('America/Lima');

  static tz.TZDateTime enLima(String iso) => tz.TZDateTime.from(DateTime.parse(iso), lima);

  static tz.TZDateTime relojReal() => tz.TZDateTime.now(lima);

  /// Se reemplaza en las pruebas para fijar la hora.
  static tz.TZDateTime Function() reloj = relojReal;

  static tz.TZDateTime ahora() => reloj();

  static String hora(String iso) => DateFormat('HH:mm', 'es').format(enLima(iso));

  static String diaHora(String iso) => DateFormat("EEE d MMM, HH:mm", 'es').format(enLima(iso));

  /// [fecha] en formato AAAA-MM-DD: se formatea sin cambiar de zona, así el día nunca se corre.
  static String diaLargo(String fecha) => DateFormat("EEEE d 'de' MMMM", 'es').format(DateTime.parse(fecha));

  static String diaCorto(String fecha) => DateFormat('EEE d', 'es').format(DateTime.parse(fecha));

  static String fechaApi(DateTime fecha) => DateFormat('yyyy-MM-dd').format(fecha);

  /// Instante exacto para la API, armado desde una fecha y hora de Lima.
  static String instanteApi(DateTime fecha, TimeOfDay hora) {
    return tz.TZDateTime(lima, fecha.year, fecha.month, fecha.day, hora.hour, hora.minute).toUtc().toIso8601String();
  }

  static String horaDe(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay timeOfDay(String texto) {
    final partes = texto.split(':');
    return TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]));
  }

  static const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
}
