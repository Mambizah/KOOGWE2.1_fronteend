import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/i18n_service.dart';
import 'welcome_screen.dart';
import 'language_screen.dart';
import 'passenger/home_screen.dart';
import 'driver/driver_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    Future.delayed(const Duration(seconds: 2), _checkAuth);
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasLanguage = prefs.containsKey('app_language');

    // ✅ Premier lancement → sélection de langue
    if (!hasLanguage) {
      _navigate(const LanguageScreen());
      return;
    }

    final isLoggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;

    if (isLoggedIn) {
      try {
        final profile = await AuthService.getProfile();
        final role = profile['role'] as String;

        // ✅ Connecter le socket avec le token valide
        if (!SocketService.isConnected) {
          await SocketService.connect();
        }

        if (!mounted) return;
        _navigate(role == 'DRIVER' ? const DriverHomeScreen() : const PassengerHomeScreen());
      } catch (_) {
        await AuthService.logout();
        _navigate(const WelcomeScreen());
      }
    } else {
      _navigate(const WelcomeScreen());
    }
  }

  void _navigate(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E2E), Color(0xFF1A2070), Color(0xFF2B40F0)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    children: [
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 16))],
                        ),
                        child: Center(
                          child: Text('K', style: GoogleFonts.dmSans(fontSize: 52, fontWeight: FontWeight.w900, color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('KOOGWE', style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4)),
                      const SizedBox(height: 6),
                      Text('Transport Premium · Lomé, Togo', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white.withOpacity(0.7), letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                SizedBox(
                  width: 40, height: 40,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.5))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
