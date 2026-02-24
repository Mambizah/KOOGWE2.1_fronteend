import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import 'register_screen.dart';
import '../passenger/home_screen.dart';
import '../driver/driver_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Veuillez remplir tous les champs');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final data = await AuthService.login(_emailCtrl.text.trim(), _passCtrl.text);
      final role = data['user']['role'] as String;

      // ✅ FIX BUG #2 : await la connexion socket avant navigation
      await SocketService.connect();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => role == 'DRIVER' ? const DriverHomeScreen() : const PassengerHomeScreen(),
        ),
        (route) => false,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Connexion impossible. Vérifiez vos identifiants.';
      setState(() => _error = msg is List ? msg.join(', ') : msg.toString());
    } catch (e) {
      setState(() => _error = 'Erreur de connexion au serveur');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textDark),
                    ),
                  ),
                  const Spacer(),
                  Text('Connexion', style: GoogleFonts.dmSans(
                    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark,
                  )),
                  const Spacer(),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 40),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.directions_car_filled, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 24),
              Text('Bon retour !', style: GoogleFonts.dmSans(
                fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark,
              )),
              const SizedBox(height: 6),
              Text(
                'Entrez vos informations pour accéder\nà votre compte KOOGWE',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight, height: 1.5),
              ),
              const SizedBox(height: 36),
              KoogweInput(
                label: 'Email',
                hint: 'nom@exemple.com',
                prefixIcon: Icons.mail_outline,
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              KoogweInput(
                label: 'Mot de passe',
                hint: '••••••••',
                obscure: true,
                prefixIcon: Icons.lock_outline,
                controller: _passCtrl,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: GoogleFonts.dmSans(
                        fontSize: 13, color: AppColors.error,
                      ))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              KoogweButton(
                label: 'Se connecter',
                onPressed: _login,
                loading: _loading,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen(isPassenger: true)),
                ),
                child: RichText(
                  text: TextSpan(
                    text: 'Nouveau sur KOOGWE ? ',
                    style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight),
                    children: [
                      TextSpan(
                        text: 'Créer un compte',
                        style: GoogleFonts.dmSans(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
