import 'package:freezed_annotation/freezed_annotation.dart';

part 'modelos.freezed.dart';
part 'modelos.g.dart';

@freezed
abstract class TratamientoRef with _$TratamientoRef {
  const factory TratamientoRef({required int id, required String nombre}) = _TratamientoRef;
  factory TratamientoRef.fromJson(Map<String, dynamic> json) => _$TratamientoRefFromJson(json);
}

@freezed
abstract class ProfesionalRef with _$ProfesionalRef {
  const factory ProfesionalRef({required int id, required String nombre}) = _ProfesionalRef;
  factory ProfesionalRef.fromJson(Map<String, dynamic> json) => _$ProfesionalRefFromJson(json);
}

@freezed
abstract class CuponCita with _$CuponCita {
  const factory CuponCita({required String codigo, required String titulo, @Default('') String descuento}) = _CuponCita;
  factory CuponCita.fromJson(Map<String, dynamic> json) => _$CuponCitaFromJson(json);
}

@freezed
abstract class PacienteRef with _$PacienteRef {
  const factory PacienteRef({
    required int id,
    required String nombre,
    required String celular,
    @Default(0) int inasistencias,
  }) = _PacienteRef;
  factory PacienteRef.fromJson(Map<String, dynamic> json) => _$PacienteRefFromJson(json);
}

@freezed
abstract class Cita with _$Cita {
  const Cita._();

  const factory Cita({
    required int id,
    required String estado,
    required String estadoTexto,
    @Default('web') String origen,
    required String inicio,
    required String fin,
    String? inicioEstimado,
    String? finEstimado,
    @Default(0) int retrasoMin,
    @Default(0) int minutosExtra,
    String? inicioReal,
    String? finReal,
    String? recordatorioEnviadoEn,
    bool? asistenciaConfirmada,

    /// «Llegó»: el cliente está en la sala de espera.
    String? llegadaEn,
    ProfesionalRef? profesional,

    /// Precios en céntimos. El ofrecido lo propone el cliente (precio ofertable); el acordado lo fija el negocio.
    int? precioReferencia,
    int? precioOfrecido,
    int? precioAcordado,
    String? precioTexto,

    /// Solo en /citas/recordatorios: el WhatsApp con el recordatorio ya escrito.
    String? whatsappUrl,
    required TratamientoRef tratamiento,
    required PacienteRef paciente,

    /// Cupón que el cliente eligió al reservar desde la app.
    CuponCita? cupon,
  }) = _Cita;

  factory Cita.fromJson(Map<String, dynamic> json) => _$CitaFromJson(json);

  bool get programada => estado == 'programada';
  bool get enCurso => estado == 'en_curso';
  bool get porAprobar => estado == 'por_aprobar';
  bool get cerrada => estado == 'terminada' || estado == 'no_asistio';
  bool get llego => llegadaEn != null;

  /// El cliente ofreció otro precio y el negocio aún no fijó uno.
  bool get tieneOferta => precioOfrecido != null && precioAcordado == null;
}

/// «S/ 18» o «S/ 18.50» a partir de céntimos.
String soles(int centimos) {
  final entero = centimos ~/ 100;
  final resto = centimos % 100;
  return resto == 0 ? 'S/ $entero' : 'S/ $entero.${resto.toString().padLeft(2, '0')}';
}

@freezed
abstract class Hueco with _$Hueco {
  const factory Hueco({required String inicio, required String fin}) = _Hueco;
  factory Hueco.fromJson(Map<String, dynamic> json) => _$HuecoFromJson(json);
}

/// Un turno del día (mañana, tarde…): minutos del día en Lima, con cuántas citas y cuántas por confirmar tiene.
@freezed
abstract class Turno with _$Turno {
  const Turno._();

  const factory Turno({
    required String nombre,
    required int desde,
    required int hasta,
    @Default(0) int citas,
    @Default(0) int porConfirmar,
  }) = _Turno;
  factory Turno.fromJson(Map<String, dynamic> json) => _$TurnoFromJson(json);

  bool contiene(int minuto) => minuto >= desde && minuto < hasta;
}

@freezed
abstract class Agenda with _$Agenda {
  const factory Agenda({
    required String fecha,
    @Default(0) int retrasoMin,
    @Default(0) int porAprobar,
    @Default([]) List<Cita> citas,
    @Default([]) List<Hueco> huecos,
    @Default([]) List<Turno> turnos,
    String? generadoEn,
  }) = _Agenda;
  factory Agenda.fromJson(Map<String, dynamic> json) => _$AgendaFromJson(json);
}

@freezed
abstract class Bloqueo with _$Bloqueo {
  const factory Bloqueo({required int id, required String inicio, required String fin, @Default('') String motivo}) =
      _Bloqueo;
  factory Bloqueo.fromJson(Map<String, dynamic> json) => _$BloqueoFromJson(json);
}

@freezed
abstract class DiaSemana with _$DiaSemana {
  const factory DiaSemana({
    required String fecha,
    @Default([]) List<Cita> citas,
    @Default([]) List<Bloqueo> bloqueos,
    @Default([]) List<Turno> turnos,
  }) = _DiaSemana;
  factory DiaSemana.fromJson(Map<String, dynamic> json) => _$DiaSemanaFromJson(json);
}

@freezed
abstract class DiaMes with _$DiaMes {
  const factory DiaMes({
    required String fecha,
    @Default(0) int citas,
    @Default(0) int porConfirmar,
    @Default(false) bool bloqueo,
  }) = _DiaMes;
  factory DiaMes.fromJson(Map<String, dynamic> json) => _$DiaMesFromJson(json);
}

/// Paciente de ese día al que se le puede ofrecer el espacio que quedó libre.
@freezed
abstract class Siguiente with _$Siguiente {
  const factory Siguiente({
    required int citaId,
    required String paciente,
    required String inicio,
    required String whatsappUrl,
  }) = _Siguiente;
  factory Siguiente.fromJson(Map<String, dynamic> json) => _$SiguienteFromJson(json);
}

@freezed
abstract class DiaLibre with _$DiaLibre {
  const factory DiaLibre({required String fecha, required List<String> horas}) = _DiaLibre;
  factory DiaLibre.fromJson(Map<String, dynamic> json) => _$DiaLibreFromJson(json);
}

@freezed
abstract class Tramo with _$Tramo {
  const factory Tramo({required int diaSemana, required String horaInicio, required String horaFin}) = _Tramo;
  factory Tramo.fromJson(Map<String, dynamic> json) => _$TramoFromJson(json);
}

@freezed
abstract class Tratamiento with _$Tratamiento {
  const factory Tratamiento({
    int? id,
    required String nombre,
    @Default('') String motivoPaciente,
    @Default('') String descripcion,
    @Default('') String indicaciones,
    @Default(30) int duracionMin,
    @Default(0) int margenMin,
    String? precioDesde,
    @Default(true) bool reservable,
    @Default(true) bool visible,
    @Default(0) int orden,

    /// Mediana de lo que de verdad duraron las últimas citas terminadas (Iniciar → Terminar).
    int? duracionRealMin,
    @Default(0) int duracionRealCitas,
  }) = _Tratamiento;
  factory Tratamiento.fromJson(Map<String, dynamic> json) => _$TratamientoFromJson(json);
}

@freezed
abstract class Paciente with _$Paciente {
  const factory Paciente({
    required int id,
    required String nombre,
    required String celular,
    @Default(0) int inasistencias,
    @Default(false) bool bloqueado,
    @Default(false) bool verificado,
    @Default([]) List<Cita> citas,
  }) = _Paciente;
  factory Paciente.fromJson(Map<String, dynamic> json) => _$PacienteFromJson(json);
}

/// «Me demoro»: a quién avisar, con su nueva hora y el WhatsApp ya escrito.
class AvisoDemora {
  const AvisoDemora({
    required this.citaId,
    required this.paciente,
    required this.inicio,
    required this.inicioEstimado,
    required this.retrasoMin,
    required this.whatsappUrl,
  });

  factory AvisoDemora.fromJson(Map<String, dynamic> j) => AvisoDemora(
    citaId: (j['cita_id'] as num).toInt(),
    paciente: j['paciente'] as String,
    inicio: j['inicio'] as String,
    inicioEstimado: j['inicio_estimado'] as String,
    retrasoMin: (j['retraso_min'] as num).toInt(),
    whatsappUrl: j['whatsapp_url'] as String,
  );

  final int citaId;
  final String paciente;
  final String inicio;
  final String inicioEstimado;
  final int retrasoMin;
  final String whatsappUrl;
}
