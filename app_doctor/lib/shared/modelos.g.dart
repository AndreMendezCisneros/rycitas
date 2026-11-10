// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'modelos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TratamientoRef _$TratamientoRefFromJson(Map<String, dynamic> json) =>
    _TratamientoRef(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String,
    );

Map<String, dynamic> _$TratamientoRefToJson(_TratamientoRef instance) =>
    <String, dynamic>{'id': instance.id, 'nombre': instance.nombre};

_ProfesionalRef _$ProfesionalRefFromJson(Map<String, dynamic> json) =>
    _ProfesionalRef(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String,
    );

Map<String, dynamic> _$ProfesionalRefToJson(_ProfesionalRef instance) =>
    <String, dynamic>{'id': instance.id, 'nombre': instance.nombre};

_CuponCita _$CuponCitaFromJson(Map<String, dynamic> json) => _CuponCita(
  codigo: json['codigo'] as String,
  titulo: json['titulo'] as String,
  descuento: json['descuento'] as String? ?? '',
);

Map<String, dynamic> _$CuponCitaToJson(_CuponCita instance) =>
    <String, dynamic>{
      'codigo': instance.codigo,
      'titulo': instance.titulo,
      'descuento': instance.descuento,
    };

_PacienteRef _$PacienteRefFromJson(Map<String, dynamic> json) => _PacienteRef(
  id: (json['id'] as num).toInt(),
  nombre: json['nombre'] as String,
  celular: json['celular'] as String,
  inasistencias: (json['inasistencias'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$PacienteRefToJson(_PacienteRef instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'celular': instance.celular,
      'inasistencias': instance.inasistencias,
    };

_Cita _$CitaFromJson(Map<String, dynamic> json) => _Cita(
  id: (json['id'] as num).toInt(),
  estado: json['estado'] as String,
  estadoTexto: json['estado_texto'] as String,
  origen: json['origen'] as String? ?? 'web',
  inicio: json['inicio'] as String,
  fin: json['fin'] as String,
  inicioEstimado: json['inicio_estimado'] as String?,
  finEstimado: json['fin_estimado'] as String?,
  retrasoMin: (json['retraso_min'] as num?)?.toInt() ?? 0,
  minutosExtra: (json['minutos_extra'] as num?)?.toInt() ?? 0,
  inicioReal: json['inicio_real'] as String?,
  finReal: json['fin_real'] as String?,
  recordatorioEnviadoEn: json['recordatorio_enviado_en'] as String?,
  asistenciaConfirmada: json['asistencia_confirmada'] as bool?,
  llegadaEn: json['llegada_en'] as String?,
  profesional: json['profesional'] == null
      ? null
      : ProfesionalRef.fromJson(json['profesional'] as Map<String, dynamic>),
  precioReferencia: (json['precio_referencia'] as num?)?.toInt(),
  precioOfrecido: (json['precio_ofrecido'] as num?)?.toInt(),
  precioAcordado: (json['precio_acordado'] as num?)?.toInt(),
  precioTexto: json['precio_texto'] as String?,
  whatsappUrl: json['whatsapp_url'] as String?,
  tratamiento: TratamientoRef.fromJson(
    json['tratamiento'] as Map<String, dynamic>,
  ),
  paciente: PacienteRef.fromJson(json['paciente'] as Map<String, dynamic>),
  cupon: json['cupon'] == null
      ? null
      : CuponCita.fromJson(json['cupon'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CitaToJson(_Cita instance) => <String, dynamic>{
  'id': instance.id,
  'estado': instance.estado,
  'estado_texto': instance.estadoTexto,
  'origen': instance.origen,
  'inicio': instance.inicio,
  'fin': instance.fin,
  'inicio_estimado': instance.inicioEstimado,
  'fin_estimado': instance.finEstimado,
  'retraso_min': instance.retrasoMin,
  'minutos_extra': instance.minutosExtra,
  'inicio_real': instance.inicioReal,
  'fin_real': instance.finReal,
  'recordatorio_enviado_en': instance.recordatorioEnviadoEn,
  'asistencia_confirmada': instance.asistenciaConfirmada,
  'llegada_en': instance.llegadaEn,
  'profesional': instance.profesional?.toJson(),
  'precio_referencia': instance.precioReferencia,
  'precio_ofrecido': instance.precioOfrecido,
  'precio_acordado': instance.precioAcordado,
  'precio_texto': instance.precioTexto,
  'whatsapp_url': instance.whatsappUrl,
  'tratamiento': instance.tratamiento.toJson(),
  'paciente': instance.paciente.toJson(),
  'cupon': instance.cupon?.toJson(),
};

_Hueco _$HuecoFromJson(Map<String, dynamic> json) =>
    _Hueco(inicio: json['inicio'] as String, fin: json['fin'] as String);

Map<String, dynamic> _$HuecoToJson(_Hueco instance) => <String, dynamic>{
  'inicio': instance.inicio,
  'fin': instance.fin,
};

_Turno _$TurnoFromJson(Map<String, dynamic> json) => _Turno(
  nombre: json['nombre'] as String,
  desde: (json['desde'] as num).toInt(),
  hasta: (json['hasta'] as num).toInt(),
  citas: (json['citas'] as num?)?.toInt() ?? 0,
  porConfirmar: (json['por_confirmar'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TurnoToJson(_Turno instance) => <String, dynamic>{
  'nombre': instance.nombre,
  'desde': instance.desde,
  'hasta': instance.hasta,
  'citas': instance.citas,
  'por_confirmar': instance.porConfirmar,
};

_Agenda _$AgendaFromJson(Map<String, dynamic> json) => _Agenda(
  fecha: json['fecha'] as String,
  retrasoMin: (json['retraso_min'] as num?)?.toInt() ?? 0,
  porAprobar: (json['por_aprobar'] as num?)?.toInt() ?? 0,
  citas:
      (json['citas'] as List<dynamic>?)
          ?.map((e) => Cita.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  huecos:
      (json['huecos'] as List<dynamic>?)
          ?.map((e) => Hueco.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  turnos:
      (json['turnos'] as List<dynamic>?)
          ?.map((e) => Turno.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  generadoEn: json['generado_en'] as String?,
);

Map<String, dynamic> _$AgendaToJson(_Agenda instance) => <String, dynamic>{
  'fecha': instance.fecha,
  'retraso_min': instance.retrasoMin,
  'por_aprobar': instance.porAprobar,
  'citas': instance.citas.map((e) => e.toJson()).toList(),
  'huecos': instance.huecos.map((e) => e.toJson()).toList(),
  'turnos': instance.turnos.map((e) => e.toJson()).toList(),
  'generado_en': instance.generadoEn,
};

_Bloqueo _$BloqueoFromJson(Map<String, dynamic> json) => _Bloqueo(
  id: (json['id'] as num).toInt(),
  inicio: json['inicio'] as String,
  fin: json['fin'] as String,
  motivo: json['motivo'] as String? ?? '',
);

Map<String, dynamic> _$BloqueoToJson(_Bloqueo instance) => <String, dynamic>{
  'id': instance.id,
  'inicio': instance.inicio,
  'fin': instance.fin,
  'motivo': instance.motivo,
};

_DiaSemana _$DiaSemanaFromJson(Map<String, dynamic> json) => _DiaSemana(
  fecha: json['fecha'] as String,
  citas:
      (json['citas'] as List<dynamic>?)
          ?.map((e) => Cita.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  bloqueos:
      (json['bloqueos'] as List<dynamic>?)
          ?.map((e) => Bloqueo.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  turnos:
      (json['turnos'] as List<dynamic>?)
          ?.map((e) => Turno.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$DiaSemanaToJson(_DiaSemana instance) =>
    <String, dynamic>{
      'fecha': instance.fecha,
      'citas': instance.citas.map((e) => e.toJson()).toList(),
      'bloqueos': instance.bloqueos.map((e) => e.toJson()).toList(),
      'turnos': instance.turnos.map((e) => e.toJson()).toList(),
    };

_DiaMes _$DiaMesFromJson(Map<String, dynamic> json) => _DiaMes(
  fecha: json['fecha'] as String,
  citas: (json['citas'] as num?)?.toInt() ?? 0,
  porConfirmar: (json['por_confirmar'] as num?)?.toInt() ?? 0,
  bloqueo: json['bloqueo'] as bool? ?? false,
);

Map<String, dynamic> _$DiaMesToJson(_DiaMes instance) => <String, dynamic>{
  'fecha': instance.fecha,
  'citas': instance.citas,
  'por_confirmar': instance.porConfirmar,
  'bloqueo': instance.bloqueo,
};

_Siguiente _$SiguienteFromJson(Map<String, dynamic> json) => _Siguiente(
  citaId: (json['cita_id'] as num).toInt(),
  paciente: json['paciente'] as String,
  inicio: json['inicio'] as String,
  whatsappUrl: json['whatsapp_url'] as String,
);

Map<String, dynamic> _$SiguienteToJson(_Siguiente instance) =>
    <String, dynamic>{
      'cita_id': instance.citaId,
      'paciente': instance.paciente,
      'inicio': instance.inicio,
      'whatsapp_url': instance.whatsappUrl,
    };

_DiaLibre _$DiaLibreFromJson(Map<String, dynamic> json) => _DiaLibre(
  fecha: json['fecha'] as String,
  horas: (json['horas'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$DiaLibreToJson(_DiaLibre instance) => <String, dynamic>{
  'fecha': instance.fecha,
  'horas': instance.horas,
};

_Tramo _$TramoFromJson(Map<String, dynamic> json) => _Tramo(
  diaSemana: (json['dia_semana'] as num).toInt(),
  horaInicio: json['hora_inicio'] as String,
  horaFin: json['hora_fin'] as String,
);

Map<String, dynamic> _$TramoToJson(_Tramo instance) => <String, dynamic>{
  'dia_semana': instance.diaSemana,
  'hora_inicio': instance.horaInicio,
  'hora_fin': instance.horaFin,
};

_Tratamiento _$TratamientoFromJson(Map<String, dynamic> json) => _Tratamiento(
  id: (json['id'] as num?)?.toInt(),
  nombre: json['nombre'] as String,
  motivoPaciente: json['motivo_paciente'] as String? ?? '',
  descripcion: json['descripcion'] as String? ?? '',
  indicaciones: json['indicaciones'] as String? ?? '',
  duracionMin: (json['duracion_min'] as num?)?.toInt() ?? 30,
  margenMin: (json['margen_min'] as num?)?.toInt() ?? 0,
  precioDesde: json['precio_desde'] as String?,
  reservable: json['reservable'] as bool? ?? true,
  visible: json['visible'] as bool? ?? true,
  orden: (json['orden'] as num?)?.toInt() ?? 0,
  duracionRealMin: (json['duracion_real_min'] as num?)?.toInt(),
  duracionRealCitas: (json['duracion_real_citas'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TratamientoToJson(_Tratamiento instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'motivo_paciente': instance.motivoPaciente,
      'descripcion': instance.descripcion,
      'indicaciones': instance.indicaciones,
      'duracion_min': instance.duracionMin,
      'margen_min': instance.margenMin,
      'precio_desde': instance.precioDesde,
      'reservable': instance.reservable,
      'visible': instance.visible,
      'orden': instance.orden,
      'duracion_real_min': instance.duracionRealMin,
      'duracion_real_citas': instance.duracionRealCitas,
    };

_Paciente _$PacienteFromJson(Map<String, dynamic> json) => _Paciente(
  id: (json['id'] as num).toInt(),
  nombre: json['nombre'] as String,
  celular: json['celular'] as String,
  inasistencias: (json['inasistencias'] as num?)?.toInt() ?? 0,
  bloqueado: json['bloqueado'] as bool? ?? false,
  verificado: json['verificado'] as bool? ?? false,
  citas:
      (json['citas'] as List<dynamic>?)
          ?.map((e) => Cita.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$PacienteToJson(_Paciente instance) => <String, dynamic>{
  'id': instance.id,
  'nombre': instance.nombre,
  'celular': instance.celular,
  'inasistencias': instance.inasistencias,
  'bloqueado': instance.bloqueado,
  'verificado': instance.verificado,
  'citas': instance.citas.map((e) => e.toJson()).toList(),
};
