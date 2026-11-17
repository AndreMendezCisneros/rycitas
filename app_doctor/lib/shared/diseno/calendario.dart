import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'paleta.dart';
import 'vidrio.dart';

/// Lo que se marca en un día del calendario.
class MarcaDia {
  const MarcaDia({this.citas = 0, this.porConfirmar = 0, this.bloqueo = false, this.colores = const []});

  final int citas;
  final int porConfirmar;
  final bool bloqueo;

  /// Un punto por cita (máximo 3 se dibujan), con el color de su estado.
  final List<Color> colores;
}

String fechaClave(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String tituloMes(DateTime mes) {
  final texto = DateFormat('MMMM yyyy', 'es').format(mes);
  return texto[0].toUpperCase() + texto.substring(1);
}

/// Calendario de un mes, compartido por el negocio y el cliente.
/// - Se desliza a los lados para cambiar de mes (o con las flechas).
/// - Cada día muestra puntos por sus citas y se tiñe de rosa según qué tan lleno está.
/// - Hoy lleva borde; el día elegido, la píldora con degradado.
class CalendarioMes extends StatefulWidget {
  const CalendarioMes({
    super.key,
    required this.mes,
    required this.marcas,
    required this.alCambiarMes,
    required this.alTocarDia,
    this.hoy,
    this.seleccionado,
    this.habilitado,
    this.cargando = false,
    this.acciones = const [],
  });

  final DateTime mes;
  final Map<String, MarcaDia> marcas;
  final ValueChanged<int> alCambiarMes;
  final ValueChanged<DateTime> alTocarDia;
  final DateTime? hoy;
  final DateTime? seleccionado;

  /// Días que se pueden tocar (por ejemplo, solo los que tienen horas libres). Null: todos.
  final bool Function(DateTime dia)? habilitado;
  final bool cargando;

  /// Botones extra junto al título (filtro de profesional, etc.).
  final List<Widget> acciones;

  @override
  State<CalendarioMes> createState() => _CalendarioMesState();
}

class _CalendarioMesState extends State<CalendarioMes> {
  int _direccion = 1;

  void _cambiar(int paso) {
    HapticFeedback.selectionClick();
    setState(() => _direccion = paso);
    widget.alCambiarMes(paso);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final sinAnimar = sinEfectos(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: sinAnimar ? Duration.zero : const Duration(milliseconds: 250),
                child: Text(
                  tituloMes(widget.mes),
                  key: ValueKey(widget.mes),
                  style: textos.titleLarge,
                ),
              ),
            ),
            ...widget.acciones,
            _Flecha(icono: Icons.chevron_left_rounded, tooltip: 'Mes anterior', alTocar: () => _cambiar(-1)),
            const SizedBox(width: 6),
            _Flecha(icono: Icons.chevron_right_rounded, tooltip: 'Mes siguiente', alTocar: () => _cambiar(1)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final d in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: textos.labelMedium?.copyWith(color: Paleta.textoSuave, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() > 200) _cambiar(v < 0 ? 1 : -1);
          },
          child: AnimatedSwitcher(
            duration: sinAnimar ? Duration.zero : const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (hijo, animacion) {
              final entrando = hijo.key == ValueKey(widget.mes);
              final desde = Offset(entrando ? 0.25 * _direccion : -0.25 * _direccion, 0);
              return FadeTransition(
                opacity: animacion,
                child: SlideTransition(
                  position: Tween(begin: desde, end: Offset.zero).animate(animacion),
                  child: hijo,
                ),
              );
            },
            layoutBuilder: (actual, previos) => Stack(
              alignment: Alignment.topCenter,
              children: [...previos, ?actual],
            ),
            child: _Cuadricula(
              key: ValueKey(widget.mes),
              mes: widget.mes,
              marcas: widget.marcas,
              hoy: widget.hoy ?? DateTime.now(),
              seleccionado: widget.seleccionado,
              habilitado: widget.habilitado,
              alTocar: (dia) {
                HapticFeedback.lightImpact();
                widget.alTocarDia(dia);
              },
            ),
          ),
        ),
        // Solo existe mientras carga: una barra indeterminada invisible seguiría animándose (y gastando batería).
        SizedBox(
          height: 8,
          child: widget.cargando
              ? const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(minHeight: 2, color: Paleta.frambuesa, backgroundColor: Paleta.rosa),
                )
              : null,
        ),
      ],
    );
  }
}

class _Flecha extends StatelessWidget {
  const _Flecha({required this.icono, required this.tooltip, required this.alTocar});

  final IconData icono;
  final String tooltip;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: tooltip,
    onPressed: alTocar,
    style: IconButton.styleFrom(backgroundColor: Paleta.rosa, foregroundColor: Paleta.frambuesa),
    icon: Icon(icono),
  );
}

class _Cuadricula extends StatelessWidget {
  const _Cuadricula({
    super.key,
    required this.mes,
    required this.marcas,
    required this.hoy,
    required this.seleccionado,
    required this.habilitado,
    required this.alTocar,
  });

  final DateTime mes;
  final Map<String, MarcaDia> marcas;
  final DateTime hoy;
  final DateTime? seleccionado;
  final bool Function(DateTime)? habilitado;
  final ValueChanged<DateTime> alTocar;

  @override
  Widget build(BuildContext context) {
    final primero = DateTime(mes.year, mes.month);
    final diasMes = DateTime(mes.year, mes.month + 1, 0).day;
    final vacios = primero.weekday - 1; // la semana empieza en lunes
    final maximo = marcas.values.fold<int>(1, (m, x) => x.citas > m ? x.citas : m);
    final hoyClave = fechaClave(hoy);
    final selClave = seleccionado == null ? null : fechaClave(seleccionado!);
    final celdas = <Widget>[
      for (var i = 0; i < vacios; i++) const SizedBox.shrink(),
      for (var d = 1; d <= diasMes; d++)
        Builder(
          builder: (_) {
            final dia = DateTime(mes.year, mes.month, d);
            final clave = fechaClave(dia);
            return _CeldaDia(
              dia: dia,
              clave: clave,
              marca: marcas[clave],
              lleno: (marcas[clave]?.citas ?? 0) / maximo,
              esHoy: clave == hoyClave,
              elegido: clave == selClave,
              activo: habilitado?.call(dia) ?? true,
              alTocar: () => alTocar(dia),
            );
          },
        ),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 4,
      childAspectRatio: 0.82,
      children: celdas,
    );
  }
}

class _CeldaDia extends StatelessWidget {
  const _CeldaDia({
    required this.dia,
    required this.clave,
    required this.marca,
    required this.lleno,
    required this.esHoy,
    required this.elegido,
    required this.activo,
    required this.alTocar,
  });

  final DateTime dia;
  final String clave;
  final MarcaDia? marca;
  final double lleno;
  final bool esHoy;
  final bool elegido;
  final bool activo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final m = marca;
    final citas = m?.citas ?? 0;
    final bloqueo = m?.bloqueo ?? false;
    final fondo = elegido
        ? null
        : bloqueo
        ? const Color(0xFFF1ECEE)
        : citas > 0
        ? Color.lerp(Paleta.rosaClaro, Paleta.rosa, lleno.clamp(0, 1))
        : null;
    final colorNumero = elegido
        ? Colors.white
        : !activo
        ? Paleta.textoSuave.withValues(alpha: 0.45)
        : Paleta.texto;
    final puntos = (m?.colores ?? const <Color>[]).take(3).toList();
    return Semantics(
      button: activo,
      selected: elegido,
      label: '${DateFormat("EEEE d 'de' MMMM", 'es').format(dia)}${citas > 0 ? ', $citas citas' : ''}',
      excludeSemantics: true,
      child: AnimatedScale(
        scale: elegido ? 1.06 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: activo ? alTocar : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: fondo,
                gradient: elegido ? Paleta.degradado : null,
                borderRadius: BorderRadius.circular(16),
                border: esHoy && !elegido ? Border.all(color: Paleta.frambuesa, width: 1.6) : null,
                boxShadow: elegido
                    ? [BoxShadow(color: Paleta.frambuesa.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${dia.day}',
                    style: TextStyle(
                      fontWeight: esHoy || elegido ? FontWeight.w800 : FontWeight.w600,
                      color: colorNumero,
                      decoration: bloqueo && citas == 0 ? TextDecoration.lineThrough : null,
                      decorationColor: Paleta.textoSuave,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 12,
                    child: citas > 0
                        ? Row(
                            key: Key('citas-$clave'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (puntos.isEmpty)
                                Text(
                                  '$citas',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: elegido ? Colors.white : Paleta.frambuesa,
                                  ),
                                )
                              else
                                for (final c in puntos)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                    decoration: BoxDecoration(
                                      color: elegido ? Colors.white : c,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              if ((m?.porConfirmar ?? 0) > 0) ...[
                                const SizedBox(width: 3),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: elegido ? Colors.white : Paleta.ambar,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Leyenda breve bajo el calendario.
class LeyendaCalendario extends StatelessWidget {
  const LeyendaCalendario({super.key, required this.items});

  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 14,
    runSpacing: 6,
    children: [
      for (final (color, texto) in items)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(texto, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Paleta.textoSuave)),
          ],
        ),
    ],
  );
}
