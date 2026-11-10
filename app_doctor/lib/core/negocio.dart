import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/sesion.dart';
import 'api.dart';

/// Las palabras del negocio: «paciente» o «cliente», «tratamiento» o «servicio», «doctor» o «barbero».
class Vocabulario {
  const Vocabulario({
    this.cliente = 'paciente',
    this.clientes = 'pacientes',
    this.servicio = 'tratamiento',
    this.servicios = 'tratamientos',
    this.profesional = 'doctor',
    this.profesionales = 'doctores',
    this.local = 'consultorio',
    this.elLocal = 'el consultorio',
  });

  factory Vocabulario.fromJson(Map<String, dynamic> j) {
    const d = Vocabulario();
    String t(String clave, String defecto) => (j[clave] as String?) ?? defecto;
    return Vocabulario(
      cliente: t('cliente', d.cliente),
      clientes: t('clientes', d.clientes),
      servicio: t('servicio', d.servicio),
      servicios: t('servicios', d.servicios),
      profesional: t('profesional', d.profesional),
      profesionales: t('profesionales', d.profesionales),
      local: t('local', d.local),
      elLocal: t('el_local', d.elLocal),
    );
  }

  final String cliente;
  final String clientes;
  final String servicio;
  final String servicios;
  final String profesional;
  final String profesionales;
  final String local;
  final String elLocal;

  /// «Paciente», «Clientes»: para títulos y botones.
  static String may(String palabra) => palabra.isEmpty ? palabra : palabra[0].toUpperCase() + palabra.substring(1);
}

class ProfesionalNegocio {
  const ProfesionalNegocio({required this.id, required this.nombre, this.detalle = '', this.servicios = const []});

  final int id;
  final String nombre;
  final String detalle;

  /// Vacío: hace todos los servicios.
  final List<int> servicios;

  bool hace(int servicioId) => servicios.isEmpty || servicios.contains(servicioId);
}

/// Cómo se divide el día en la agenda: cada turno termina en [hasta] («13:00»); el último, a las «24:00».
class TurnoNegocio {
  const TurnoNegocio({required this.nombre, required this.hasta});

  final String nombre;
  final String hasta;

  Map<String, dynamic> toJson() => {'nombre': nombre, 'hasta': hasta};
}

const turnosPorDefecto = [TurnoNegocio(nombre: 'Mañana', hasta: '13:00'), TurnoNegocio(nombre: 'Tarde', hasta: '24:00')];

class Negocio {
  const Negocio({
    this.nombre = '',
    this.rubro = 'odontologia',
    this.color,
    this.voc = const Vocabulario(),
    this.modoAgenda = 'compartida',
    this.precioOfertable = false,
    this.adelantos = false,
    this.toleranciaInasistenciaMin = 15,
    this.profesionales = const [],
    this.miProfesionalId,
    this.suspendido = false,
    this.turnos = turnosPorDefecto,
  });

  factory Negocio.fromJson(Map<String, dynamic> j) {
    final opciones = (j['opciones'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cuenta = (j['cuenta'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Negocio(
      nombre: (j['nombre'] as String?) ?? '',
      rubro: (j['rubro'] as String?) ?? 'odontologia',
      color: _color(j['color'] as String?),
      voc: Vocabulario.fromJson((j['vocabulario'] as Map?)?.cast<String, dynamic>() ?? const {}),
      modoAgenda: (opciones['modo_agenda'] as String?) ?? 'compartida',
      precioOfertable: opciones['precio_ofertable'] == true,
      adelantos: opciones['adelantos'] == true,
      toleranciaInasistenciaMin: (opciones['tolerancia_inasistencia_min'] as num?)?.toInt() ?? 15,
      profesionales: [
        for (final p in (j['profesionales'] as List? ?? const []))
          ProfesionalNegocio(
            id: (p as Map)['id'] as int,
            nombre: p['nombre'] as String,
            detalle: (p['detalle'] as String?) ?? '',
            servicios: [for (final s in (p['servicios'] as List? ?? const [])) s as int],
          ),
      ],
      turnos: [
        for (final t in (opciones['turnos'] as List? ?? const []))
          TurnoNegocio(nombre: (t as Map)['nombre'] as String, hasta: t['hasta'] as String),
      ].ifEmpty(turnosPorDefecto),
      miProfesionalId: cuenta['profesional_id'] as int?,
      suspendido: j['suspendido'] == true,
    );
  }

  final String nombre;
  final String rubro;
  final Color? color;
  final Vocabulario voc;
  final String modoAgenda;
  final bool precioOfertable;
  final bool adelantos;
  final int toleranciaInasistenciaMin;
  final List<ProfesionalNegocio> profesionales;
  final int? miProfesionalId;
  final bool suspendido;
  final List<TurnoNegocio> turnos;

  /// La cuenta general (encargado o recepción) ve y gestiona a todos; la de un profesional, solo lo suyo.
  bool get esGeneral => miProfesionalId == null;

  /// Varios atienden en paralelo: la agenda se puede filtrar y cada cita dice con quién es.
  bool get porProfesional => modoAgenda == 'por_profesional' && profesionales.length > 1;

  static Color? _color(String? hex) {
    if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }
}

extension _SiVacia<T> on List<T> {
  List<T> ifEmpty(List<T> otra) => isEmpty ? otra : this;
}

const claveNegocioGuardado = 'negocio_guardado';

/// Se descarga al entrar. Sin señal usa el último guardado; si nunca bajó, habla como un consultorio.
final negocioProvider = FutureProvider<Negocio>((ref) async {
  if (ref.watch(sesionProvider) != EstadoSesion.activa) return const Negocio();
  final almacen = ref.read(almacenProvider);
  try {
    final datos = await ref.read(apiProvider).get('/negocio');
    await almacen.escribir(claveNegocioGuardado, jsonEncode(datos));
    return Negocio.fromJson(datos);
  } on ApiError {
    final guardado = await almacen.leer(claveNegocioGuardado);
    if (guardado == null) return const Negocio();
    return Negocio.fromJson(jsonDecode(guardado) as Map<String, dynamic>);
  }
});

/// Acceso directo que nunca espera: mientras carga, el vocabulario por defecto.
final negocioActualProvider = Provider<Negocio>((ref) => ref.watch(negocioProvider).value ?? const Negocio());

final vocProvider = Provider<Vocabulario>((ref) => ref.watch(negocioActualProvider).voc);

/// Filtro de la agenda. `null`: la mía (o todo, si la cuenta es de encargado). `0`: todos. Otro: ese profesional.
final filtroProfesionalProvider = StateProvider<int?>((ref) => null);

/// Parámetro `profesional` para /agenda y /agenda/semana, o null si no hace falta.
final parametroProfesionalProvider = Provider<Map<String, dynamic>>((ref) {
  final filtro = ref.watch(filtroProfesionalProvider);
  return filtro == null ? const {} : {'profesional': filtro};
});

/// Para funciones con solo un [BuildContext] (diálogos, hojas): el vocabulario del negocio actual.
Vocabulario vocDe(BuildContext context) => ProviderScope.containerOf(context, listen: false).read(vocProvider);
