import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/modo.dart';
import '../../core/tema.dart';
import 'sesion.dart';

class LoginPantalla extends ConsumerStatefulWidget {
  const LoginPantalla({super.key});

  @override
  ConsumerState<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends ConsumerState<LoginPantalla> {
  final _correo = TextEditingController();
  final _password = TextEditingController();
  bool _enviando = false;
  bool _oculta = true;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_correo.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Escribe tu correo y tu contraseña.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref.read(sesionProvider.notifier).iniciar(_correo.text, _password.text);
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
      body: DecoratedBox(
        // Degradado suave de la marca detrás del formulario.
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: colorMarca.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset('assets/logo.png', width: 84, height: 84),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('RyCitas', textAlign: TextAlign.center, style: textos.headlineLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Tu agenda del día, en tu celular.',
                      textAlign: TextAlign.center,
                      style: textos.bodyLarge?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _correo,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Correo',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _password,
                              obscureText: _oculta,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => _entrar(),
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
                                  onPressed: () => setState(() => _oculta = !_oculta),
                                  icon: Icon(_oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                ),
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              child: _error == null
                                  ? const SizedBox(width: double.infinity)
                                  : Container(
                                      margin: const EdgeInsets.only(top: 14),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: esquema.errorContainer,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.error_outline_rounded, color: esquema.onErrorContainer, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(_error!, style: TextStyle(color: esquema.onErrorContainer)),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _enviando ? null : _entrar,
                              child: _enviando
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                                        SizedBox(width: 10),
                                        Text('Entrando…'),
                                      ],
                                    )
                                  : const Text('Entrar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tu cuenta la crea el equipo de RyCitas.',
                      textAlign: TextAlign.center,
                      style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                    TextButton(
                      key: const Key('ir-a-cliente'),
                      onPressed: () => ref.read(modoProvider.notifier).elegir(ModoApp.cliente),
                      child: const Text('¿Quieres reservar? Entra como cliente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
