import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/modo.dart';
import '../../core/tema.dart';
import 'sesion_cliente.dart';

/// Primera pantalla: la misma app sirve para reservar y para atender un negocio.
class BienvenidaPantalla extends ConsumerWidget {
  const BienvenidaPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      body: _Fondo(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            const _Logo(),
            const SizedBox(height: 20),
            Text('RyCitas', textAlign: TextAlign.center, style: textos.headlineLarge),
            const SizedBox(height: 6),
            Text(
              '¿Cómo vas a usar la app?',
              textAlign: TextAlign.center,
              style: textos.bodyLarge?.copyWith(color: esquema.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            _Opcion(
              key: const Key('modo-cliente'),
              icono: Icons.event_available_rounded,
              titulo: 'Quiero reservar',
              detalle: 'Reserva en tus lugares favoritos, junta sellos y recibe cupones.',
              alTocar: () => ref.read(modoProvider.notifier).elegir(ModoApp.cliente),
            ),
            const SizedBox(height: 12),
            _Opcion(
              key: const Key('modo-negocio'),
              icono: Icons.storefront_rounded,
              titulo: 'Tengo un negocio',
              detalle: 'Tu agenda del día, las reservas por confirmar y tus clientes.',
              alTocar: () => ref.read(modoProvider.notifier).elegir(ModoApp.negocio),
            ),
          ],
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({super.key, required this.icono, required this.titulo, required this.detalle, required this.alTocar});

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: esquema.primaryContainer, borderRadius: BorderRadius.circular(16)),
                child: Icon(icono, color: esquema.onPrimaryContainer, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(detalle, style: TextStyle(color: esquema.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fondo extends StatelessWidget {
  const _Fondo({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colorMarca.withValues(alpha: 0.16), esquema.surface, esquema.surface],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: child),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: colorMarca.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset('assets/logo.png', width: 76, height: 76),
        ),
      ),
    );
  }
}

/// Registro y entrada del cliente: correo, nombre y WhatsApp. Sin contraseña.
class RegistroClientePantalla extends ConsumerStatefulWidget {
  const RegistroClientePantalla({super.key});

  @override
  ConsumerState<RegistroClientePantalla> createState() => _RegistroClienteState();
}

class _RegistroClienteState extends ConsumerState<RegistroClientePantalla> {
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _celular = TextEditingController();
  final _referido = TextEditingController();
  final _codigo = TextEditingController();
  bool _acepta = false;
  bool _publicidad = false;
  bool _conInvitacion = false;
  bool _faltaCodigo = false;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _correo, _celular, _referido, _codigo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_nombre.text.trim().length < 2 || !_correo.text.contains('@') || _celular.text.trim().length < 9) {
      setState(() => _error = 'Completa tu nombre, tu correo y tu WhatsApp.');
      return;
    }
    if (!_acepta) {
      setState(() => _error = 'Acepta la política de datos para continuar.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final sesion = ref.read(sesionClienteProvider.notifier);
    try {
      if (_faltaCodigo) {
        await sesion.verificar(correo: _correo.text, celular: _celular.text, codigo: _codigo.text);
      } else {
        final r = await sesion.registrar(
          nombre: _nombre.text,
          correo: _correo.text,
          celular: _celular.text,
          referido: _referido.text,
          aceptaPublicidad: _publicidad,
        );
        if (r == ResultadoRegistro.faltaCodigo && mounted) setState(() => _faltaCodigo = true);
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      body: _Fondo(
        child: AutofillGroup(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const _Logo(),
              const SizedBox(height: 16),
              Text('Reserva con RyCitas', textAlign: TextAlign.center, style: textos.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Usa el mismo WhatsApp con el que reservas: así aparecen solos los lugares donde ya te atendiste.',
                textAlign: TextAlign.center,
                style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const Key('cliente-nombre'),
                        controller: _nombre,
                        enabled: !_faltaCodigo,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Tu nombre',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('cliente-correo'),
                        controller: _correo,
                        enabled: !_faltaCodigo,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.alternate_email)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('cliente-celular'),
                        controller: _celular,
                        enabled: !_faltaCodigo,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp',
                          hintText: '987 654 321',
                          prefixIcon: Icon(Icons.chat_outlined),
                        ),
                      ),
                      if (_faltaCodigo) ...[
                        const SizedBox(height: 12),
                        Text('Te enviamos un código de 6 dígitos a tu correo.', style: textos.bodySmall),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('cliente-codigo'),
                          controller: _codigo,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(labelText: 'Código', prefixIcon: Icon(Icons.pin_outlined)),
                        ),
                      ] else ...[
                        if (_conInvitacion) ...[
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('cliente-referido'),
                            controller: _referido,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Código de invitación',
                              prefixIcon: Icon(Icons.card_giftcard_rounded),
                            ),
                          ),
                        ] else
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(() => _conInvitacion = true),
                              icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                              label: const Text('Tengo un código de invitación'),
                            ),
                          ),
                        CheckboxListTile(
                          key: const Key('cliente-acepta'),
                          value: _acepta,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (v) => setState(() => _acepta = v ?? false),
                          title: const Text('Acepto que los negocios donde reservo usen mis datos para atenderme.'),
                          subtitle: GestureDetector(
                            onTap: () => launchUrl(Uri.parse('$apiUrl/privacidad/')),
                            child: Text(
                              'Ver la política de datos',
                              style: TextStyle(color: esquema.primary, decoration: TextDecoration.underline),
                            ),
                          ),
                        ),
                        // Permiso aparte y opcional (Ley 29733): sin marcarlo, la cuenta funciona igual.
                        CheckboxListTile(
                          key: const Key('cliente-publicidad'),
                          value: _publicidad,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (v) => setState(() => _publicidad = v ?? false),
                          title: const Text('Quiero recibir promociones de los negocios donde reservo (opcional).'),
                        ),
                      ],
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: esquema.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(_error!, style: TextStyle(color: esquema.onErrorContainer)),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('cliente-entrar'),
                        onPressed: _enviando ? null : _entrar,
                        child: Text(_enviando ? 'Entrando…' : (_faltaCodigo ? 'Verificar' : 'Entrar')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(modoProvider.notifier).elegir(ModoApp.negocio),
                child: const Text('¿Tienes un negocio? Entra aquí'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
