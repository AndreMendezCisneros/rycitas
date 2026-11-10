import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';

/// La misma app sirve al negocio («Tengo un negocio») y a sus clientes («Quiero reservar»).
enum ModoApp { cargando, ninguno, negocio, cliente }

const claveModo = 'modo_app';

class Modo extends Notifier<ModoApp> {
  @override
  ModoApp build() {
    Future.microtask(_restaurar);
    return ModoApp.cargando;
  }

  Future<void> _restaurar() async {
    final almacen = ref.read(almacenProvider);
    final guardado = await almacen.leer(claveModo);
    state = switch (guardado) {
      'negocio' => ModoApp.negocio,
      'cliente' => ModoApp.cliente,
      // Quien ya usaba la app del negocio antes de que existiera el modo cliente sigue entrando directo.
      _ => await almacen.leer(claveRenovacion) != null ? ModoApp.negocio : ModoApp.ninguno,
    };
  }

  Future<void> elegir(ModoApp modo) async {
    final almacen = ref.read(almacenProvider);
    if (modo == ModoApp.ninguno) {
      await almacen.borrar(claveModo);
    } else {
      await almacen.escribir(claveModo, modo.name);
    }
    state = modo;
  }
}

final modoProvider = NotifierProvider<Modo, ModoApp>(Modo.new);
