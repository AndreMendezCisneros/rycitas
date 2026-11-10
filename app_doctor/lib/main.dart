import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:timezone/data/latest_10y.dart' as zonas;

import 'core/negocio.dart';
import 'core/rutas.dart';
import 'core/tema.dart';
import 'features/auth/bloqueo.dart';

const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  zonas.initializeTimeZones();
  await initializeDateFormatting('es');

  const app = ProviderScope(child: RyCitasApp());
  if (_sentryDsn.isEmpty) {
    runApp(app);
    return;
  }
  await SentryFlutter.init((opciones) {
    opciones.dsn = _sentryDsn;
    opciones.sendDefaultPii = false; // datos de pacientes fuera del reporte de errores (RNF-09)
  }, appRunner: () => runApp(app));
}

class RyCitasApp extends ConsumerWidget {
  const RyCitasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'RyCitas',
      theme: temaRyCitas(ref.watch(negocioActualProvider.select((n) => n.color))),
      darkTheme: temaRyCitas(ref.watch(negocioActualProvider.select((n) => n.color)), Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(rutasProvider),
      builder: (_, child) => CapaBloqueo(child: child ?? const SizedBox.shrink()),
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
