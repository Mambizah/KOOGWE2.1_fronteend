import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'services/i18n_service.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';

/// GlobalKey pour naviguer depuis les interceptors (401 → login)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Charger la langue sauvegardée
  await I18n.instance.load();

  // ✅ ApiService.init() appelé UNE SEULE FOIS ici
  await ApiService.init();

  // ✅ Callback 401 → rediriger vers WelcomeScreen
  ApiService.setOnUnauthorized(() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  });

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(
    ChangeNotifierProvider.value(
      value: I18n.instance,
      child: const KoogweApp(),
    ),
  );
}

class KoogweApp extends StatelessWidget {
  const KoogweApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Écouter les changements de langue pour rebuild l'app
    context.watch<I18n>();

    return MaterialApp(
      title: 'KOOGWE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: navigatorKey,
      home: const SplashScreen(),
    );
  }
}
