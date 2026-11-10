import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../core/negocio.dart';
import '../../core/push.dart';
import '../../shared/modelos.dart';
import '../auth/sesion.dart';

class EstadoAgenda {
  const EstadoAgenda(this.agenda, {this.sinConexion = false});

  final Agenda agenda;

  /// Agenda guardada: se puede consultar, pero no modificar.
  final bool sinConexion;
}

enum AccionConsulta {
  iniciar('iniciar'),
  llego('llego'),
  terminar('terminar'),
  noAsistio('no-asistio'),
  mas10('extender'),
  mas20('extender');

  const AccionConsulta(this.ruta);
  final String ruta;
}

/// Se refresca cada 30 s mientras la app está abierta, al recibir un push y al deslizar.
class AgendaControlador extends AsyncNotifier<EstadoAgenda> {
  static const intervalo = Duration(seconds: 30);

  Timer? _temporizador;
  AppLifecycleListener? _ciclo;
  int _generacion = 0;

  @override
  Future<EstadoAgenda> build() async {
    final sesion = ref.watch(sesionProvider);
    ref.watch(parametroProfesionalProvider); // cambiar el filtro vuelve a descargar
    ref.listen(avisoPushProvider, (_, _) => refrescar());
    ref.onDispose(() {
      _temporizador?.cancel();
      _ciclo?.dispose();
    });
    if (sesion != EstadoSesion.activa) {
      return EstadoAgenda(Agenda(fecha: Fechas.fechaApi(Fechas.ahora())));
    }
    _programar();
    _ciclo = AppLifecycleListener(
      onPause: () => _temporizador?.cancel(),
      onResume: () {
        _programar();
        refrescar();
      },
    );
    return _descargar();
  }

  void _programar() {
    _temporizador?.cancel();
    _temporizador = Timer.periodic(intervalo, (_) => refrescar());
  }

  Future<EstadoAgenda> _descargar() async {
    final api = ref.read(apiProvider);
    final almacen = ref.read(almacenProvider);
    try {
      final datos = await api.get('/agenda', params: ref.read(parametroProfesionalProvider));
      await almacen.escribir(claveAgendaGuardada, jsonEncode(datos));
      return EstadoAgenda(Agenda.fromJson(datos));
    } on ApiError catch (e) {
      if (!e.sinConexion) rethrow;
      final guardada = await almacen.leer(claveAgendaGuardada);
      if (guardada == null) rethrow;
      return EstadoAgenda(Agenda.fromJson(jsonDecode(guardada) as Map<String, dynamic>), sinConexion: true);
    }
  }

  Future<void> refrescar() async {
    final generacion = _generacion;
    try {
      final nuevo = await _descargar();
      // Una acción empezó mientras se descargaba: esta respuesta ya es vieja y desharía lo que el doctor tocó.
      if (generacion == _generacion) state = AsyncData(nuevo);
    } on ApiError catch (e, pila) {
      if (generacion == _generacion && !state.hasValue) state = AsyncError(e, pila);
    }
  }

  /// Se ve al instante y se revierte si el servidor no responde. Devuelve el error o null.
  /// [alResponder] recibe la respuesta completa (por ejemplo, los siguientes pacientes tras «No vino»).
  Future<String?> accion(AccionConsulta accion, int citaId, {void Function(Map<String, dynamic>)? alResponder}) async {
    final anterior = state.value;
    if (anterior == null) return 'La agenda aún no carga.';
    if (anterior.sinConexion) return 'Sin conexión: la agenda está en modo lectura.';

    _generacion++;
    state = AsyncData(EstadoAgenda(_optimista(anterior.agenda, accion, citaId)));
    try {
      final datos = await ref.read(apiProvider).post('/citas/$citaId/${accion.ruta}', switch (accion) {
        AccionConsulta.mas10 => {'minutos': 10},
        AccionConsulta.mas20 => {'minutos': 20},
        _ => null,
      });
      aplicarAgenda(datos['agenda'] as Map<String, dynamic>);
      alResponder?.call(datos);
      return null;
    } on ApiError catch (e) {
      _generacion++;
      state = AsyncData(anterior);
      return e.mensaje;
    }
  }

  /// «Me demoro N min»: corre la hora estimada y devuelve a quiénes conviene avisar. Devuelve (error, avisos).
  Future<(String?, List<AvisoDemora>)> demorar(int citaId, int minutos) async {
    final actual = state.value;
    if (actual == null) return ('La agenda aún no carga.', const <AvisoDemora>[]);
    if (actual.sinConexion) return ('Sin conexión: la agenda está en modo lectura.', const <AvisoDemora>[]);
    try {
      final datos = await ref.read(apiProvider).post('/citas/$citaId/demora', {'minutos': minutos});
      aplicarAgenda(datos['agenda'] as Map<String, dynamic>);
      return (
        null,
        [for (final a in (datos['avisos'] as List? ?? const [])) AvisoDemora.fromJson(a as Map<String, dynamic>)],
      );
    } on ApiError catch (e) {
      return (e.mensaje, const <AvisoDemora>[]);
    }
  }

  /// Las acciones devuelven la agenda propia de la cuenta. Con otro filtro elegido se vuelve a pedir la vista
  /// filtrada para no cambiarle la pantalla al encargado.
  void aplicarAgenda(Map<String, dynamic> datos) {
    if (ref.read(filtroProfesionalProvider) != null) {
      _generacion++;
      refrescar();
      return;
    }
    _generacion++;
    state = AsyncData(EstadoAgenda(Agenda.fromJson(datos)));
    ref.read(almacenProvider).escribir(claveAgendaGuardada, jsonEncode(datos));
  }

  Agenda _optimista(Agenda agenda, AccionConsulta accion, int citaId) {
    final ahora = Fechas.ahora().toIso8601String();
    return agenda.copyWith(
      citas: [
        for (final c in agenda.citas)
          if (c.id != citaId)
            c
          else
            switch (accion) {
              AccionConsulta.iniciar => c.copyWith(
                estado: 'en_curso',
                estadoTexto: 'En curso',
                inicioReal: ahora,
                llegadaEn: c.llegadaEn ?? ahora,
              ),
              AccionConsulta.llego => c.copyWith(llegadaEn: ahora),
              // Sin «Iniciar» («Atendida») no hay duración que guardar.
              AccionConsulta.terminar => c.copyWith(
                estado: 'terminada',
                estadoTexto: 'Terminada',
                finReal: c.enCurso ? ahora : null,
              ),
              AccionConsulta.noAsistio => c.copyWith(estado: 'no_asistio', estadoTexto: 'No asistió'),
              AccionConsulta.mas10 => c.copyWith(minutosExtra: c.minutosExtra + 10),
              AccionConsulta.mas20 => c.copyWith(minutosExtra: c.minutosExtra + 20),
            },
      ],
    );
  }
}

final agendaProvider = AsyncNotifierProvider<AgendaControlador, EstadoAgenda>(AgendaControlador.new);
