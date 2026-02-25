import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/i18n_service.dart';
import '../passenger/home_screen.dart';
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
  bool _resending = false;

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
      final result = await AuthService.verifyOtp(widget.email, code);

      if (result['user'] != null) {
        await AuthService.saveUserFromMap(result['user'] as Map<String, dynamic>);
      }

      // ✅ Vérifier qu'on a bien un token avant de continuer
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        setState(() => _error = loc.t('verify_failed'));
        return;
      }

      await SocketService.connect();

      if (!mounted) return;
      _navigateHome();

    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 0;
      if (statusCode == 0) {
        setState(() => _error = loc.t('network_error'));
      } else if (statusCode == 400 || statusCode == 401) {
        setState(() => _error = loc.t('incorrect_code'));
      } else {
        final msg = e.response?.data?['message'] ?? loc.t('incorrect_code');
        setState(() => _error = msg.toString());
      }
    } catch (e) {
      // ✅ PLUS de bypass : on affiche l'erreur, on ne navigue JAMAIS sans token
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() { _resending = true; _error = null; });
    try {
      await ApiService.dio.post('/auth/resend-otp', data: {'email': widget.email});
    } catch (_) {
      // Si l'endpoint n'existe pas, on reset juste le countdown
    } finally {
      if (mounted) {
        setState(() {
          _countdown = 59;
          _resending = false;
        });
        _startCountdown();
        for (final c in _ctrl) c.clear();
        _focus[0].requestFocus();
      }
    }
  }

  void _navigateHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => widget.isPassenger
            ? const PassengerHomeScreen()
            : const VehicleRegistrationScreen(),
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
                  Text(loc.t('otp_title'), style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
              Text(loc.t('otp_verify_title'), style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: '${loc.t('otp_sent_to')}\n',
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight, height: 1.5),
                  children: [
                    TextSpan(
                      text: widget.email,
                      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Avertissement spam
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFD54F)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.t('check_spam'),
                        style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              KoogweButton(
                label: loc.t('verify_btn'),
                onPressed: _loading ? null : _verify,
                loading: _loading,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${loc.t('otp_resend')} ? ', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight)),
                  _countdown > 0
                      ? Text(
                          '0:${_countdown.toString().padLeft(2, '0')}',
                          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textLight),
                        )
                      : _resending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                          : GestureDetector(
                              onTap: _resendCode,
                              child: Text(
                                loc.t('otp_resend'),
                                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
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