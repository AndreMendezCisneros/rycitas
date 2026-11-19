import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../shared/modelos.dart' show DiaLibre;

/// Datos de la app del cliente. Son lecturas simples de /cliente/v1: se guardan como mapas tipados a mano para no
/// mezclarlos con los modelos del negocio.
typedef Json = Map<String, dynamic>;

List<Json> lista(Object? valor) => (valor as List? ?? const []).cast<Json>();

final yoProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiClienteProvider).get('/yo'));

final misNegociosProvider = FutureProvider.autoDispose<Json>(
  (ref) => ref.read(apiClienteProvider).get('/mis-negocios'),
);

typedef Busqueda = ({String q, String rubro});

final busquedaProvider = FutureProvider.autoDispose.family<Json, Busqueda>(
  (ref, b) =>
      ref.read(apiClienteProvider).get('/negocios', params: {'q': b.q, if (b.rubro.isNotEmpty) 'rubro': b.rubro}),
);

final negocioClienteProvider = FutureProvider.autoDispose.family<Json, String>(
  (ref, slug) => ref.read(apiClienteProvider).get('/negocios/$slug'),
);

typedef ConsultaCliente = ({String slug, String motivo, int? profesional});

/// La respuesta completa: días con horas y, si hoy no tiene, por qué (`motivo_hoy`).
final disponibilidadClienteProvider = FutureProvider.autoDispose.family<Json, ConsultaCliente>(
  (ref, c) => ref
      .read(apiClienteProvider)
      .get('/negocios/${c.slug}/disponibilidad', params: {'motivo': c.motivo, 'profesional': ?c.profesional}),
);

final horasClienteProvider = FutureProvider.autoDispose.family<List<DiaLibre>, ConsultaCliente>((ref, c) async {
  final datos = await ref.watch(disponibilidadClienteProvider(c).future);
  return lista(datos['dias']).map(DiaLibre.fromJson).toList();
});

final misCitasProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiClienteProvider).get('/mis-citas'));

final beneficiosProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiClienteProvider).get('/beneficios'));

/// Logros, racha y nivel global.
final logrosProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiClienteProvider).get('/logros'));

/// Tras reservar, canjear o cambiar algo: todo lo que depende de las citas y los sellos se vuelve a pedir.
void refrescarCliente(WidgetRef ref) {
  ref
    ..invalidate(misNegociosProvider)
    ..invalidate(misCitasProvider)
    ..invalidate(beneficiosProvider)
    ..invalidate(logrosProvider);
}
