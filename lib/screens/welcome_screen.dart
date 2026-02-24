import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/koogwe_widgets.dart';
import '../services/i18n_service.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'language_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  String get _langLabel {
    switch (loc.lang) {
      case 'en': return 'English';
      case 'es': return 'Español';
      case 'pt': return 'Português';
      default: return 'Français (FR)';
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image / gradient
          Container(
            height: MediaQuery.of(context).size.height * 0.55,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0E2E), Color(0xFF1A2070), Color(0xFF2B40F0)],
              ),
            ),
          ),
          // Car illustration
          Positioned(
            top: 60,
            left: 0, right: 0,
            child: Center(
              child: Container(
                width: 280,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 30, offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: Colors.transparent,
                    child: const _CarIllustration(),
                  ),
                ),
              ),
            ),
          ),
          // Logo
          Positioned(
            top: 52,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.star, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'KOOGWE',
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Votre trajet premium\ncommence ici.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Voyagez avec des chauffeurs professionnels\net des véhicules haut de gamme.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: AppColors.textLight,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      KoogweButton(
                        label: loc.t('passenger'),
                        icon: Icons.person,
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const RegisterScreen(isPassenger: true),
                          ));
                        },
                      ),
                      const SizedBox(height: 12),
                      KoogweOutlinedButton(
                        label: loc.t('driver'),
                        icon: Icons.directions_car,
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const RegisterScreen(isPassenger: false),
                          ));
                        },
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        )),
                        child: RichText(
                          text: TextSpan(
                            text: loc.t('already_account'),
                            style: GoogleFonts.dmSans(
                              fontSize: 14, color: AppColors.textLight,
                            ),
                            children: [
                              TextSpan(
                                text: loc.t('sign_in'),
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── Sélecteur de langue ──────────────────────────────
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LanguageScreen()),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.language, size: 14, color: AppColors.textLight),
                            const SizedBox(width: 4),
                            Text(
                              _langLabel,
                              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textLight),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textLight),
                            Container(margin: const EdgeInsets.symmetric(horizontal: 8), width: 4, height: 4,
                              decoration: BoxDecoration(color: AppColors.textHint, shape: BoxShape.circle)),
                            Text('Centre d\'aide', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textLight)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarIllustration extends StatelessWidget {
  const _CarIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2070), Color(0xFF0A0E2E)],
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Road lines
            Positioned(
              bottom: 20,
              left: 0, right: 0,
              child: Container(height: 3, color: Colors.white.withOpacity(0.2)),
            ),
            Positioned(
              bottom: 26,
              left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(8, (i) => Container(
                  width: 20, height: 2,
                  color: Colors.white.withOpacity(0.4),
                )),
              ),
            ),
            // Car body
            Container(
              width: 180,
              height: 90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2B40F0), Color(0xFF1A2DD4)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 20),
                ],
              ),
              child: Stack(
                children: [
                  // Windows
                  Positioned(
                    top: 12, left: 30, right: 30,
                    child: Container(
                      height: 35,
                      decoration: BoxDecoration(
                        color: Colors.lightBlueAccent.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                    ),
                  ),
                  // Headlights
                  Positioned(
                    right: 8, top: 30,
                    child: Container(
                      width: 16, height: 10,
                      decoration: BoxDecoration(
                        color: Colors.yellow.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [BoxShadow(color: Colors.yellow.withOpacity(0.7), blurRadius: 8)],
                      ),
                    ),
                  ),
                  // Taillights
                  Positioned(
                    left: 8, top: 30,
                    child: Container(
                      width: 16, height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Wheels
            Positioned(
              bottom: 18,
              left: 40,
              child: _Wheel(),
            ),
            Positioned(
              bottom: 18,
              right: 40,
              child: _Wheel(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A1A2E),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
      ),
      child: Center(
        child: Container(
          width: 14, height: 14,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}
