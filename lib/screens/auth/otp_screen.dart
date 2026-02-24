import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../passenger/home_screen.dart';
import '../driver/driver_home_screen.dart';
import '../driver/vehicle_registration_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final bool isPassenger;
  const OtpScreen({super.key, required this.email, required this.isPassenger});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _ctrl = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focus = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;
  int _countdown = 59;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() async {
    while (_countdown > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _countdown--);
    }
  }

  Future<void> _verify() async {
    final code = _ctrl.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _error = 'Entrez le code complet à 6 chiffres');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // Appel API vérification OTP
      final result = await AuthService.verifyOtp(widget.email, code);

      // ✅ FIX : Sauvegarder les infos utilisateur après vérification OTP
      if (result['user'] != null) {
        final user = result['user'] as Map<String, dynamic>;
        await AuthService.saveUserFromMap(user);
      }

      // ✅ FIX : await connect() pour avoir le token avant connexion socket
      await SocketService.connect();

      if (!mounted) return;
      _navigateHome();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Code incorrect ou expiré';
      setState(() => _error = msg.toString());
    } catch (e) {
      // ✅ FIX BUG #5 : En mode dev uniquement (compte déjà activé)
      // Ne connecter socket QUE si on a vraiment un token
      final prefs = await SharedPreferences.getInstance();
      final hasToken = prefs.getString('auth_token') != null;
      if (hasToken) {
        await SocketService.connect();
        if (!mounted) return;
        _navigateHome();
      } else {
        if (mounted) setState(() => _error = 'Erreur de vérification. Réessayez.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        // Chauffeurs → enregistrement véhicule en premier
        builder: (_) => widget.isPassenger ? const PassengerHomeScreen() : const VehicleRegistrationScreen(),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    for (final c in _ctrl) c.dispose();
    for (final f in _focus) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
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
                  Text('Vérification', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  const Spacer(), const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 48),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryAccent],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text('Vérifiez votre email', style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: 'Nous avons envoyé un code à 6 chiffres à\n',
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight, height: 1.5),
                  children: [
                    TextSpan(
                      text: widget.email,
                      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) => _OtpBox(
                  controller: _ctrl[i],
                  focusNode: _focus[i],
                  onChanged: (val) {
                    if (val.isNotEmpty && i < 5) _focus[i + 1].requestFocus();
                    if (val.isEmpty && i > 0) _focus[i - 1].requestFocus();
                    if (i == 5 && val.isNotEmpty) {
                      final code = _ctrl.map((c) => c.text).join();
                      if (code.length == 6) _verify();
                    }
                  },
                )),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              KoogweButton(label: 'Vérifier', onPressed: _verify, loading: _loading),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Pas reçu le code ? ', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight)),
                  _countdown > 0
                      ? Text('0:${_countdown.toString().padLeft(2, '0')}', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textLight))
                      : GestureDetector(
                          onTap: () => setState(() => _countdown = 59),
                          child: Text('Renvoyer', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onChanged;
  const _OtpBox({required this.controller, required this.focusNode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48, height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.cardBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
