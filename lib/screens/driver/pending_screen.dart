import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';
import '../../services/i18n_service.dart';
import '../auth/login_screen.dart';
import 'driver_document_screen.dart';
import 'driver_home_screen.dart';

class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _fadeAnim;

  String _driverName = 'Chauffeur';
  Timer? _pollTimer;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _setupAnimations();
    _startPolling();
  }

  void _setupAnimations() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _floatAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  Future<void> _loadUser() async {
    final name = await AuthService.getUserName();
    if (mounted) setState(() => _driverName = name ?? 'Chauffeur');
  }

  // ── Polling du statut toutes les 30 secondes ──────────────────────────────
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkApprovalStatus();
    });
    // Premier check immédiat
    Future.delayed(const Duration(seconds: 2), _checkApprovalStatus);
  }

  Future<void> _checkApprovalStatus() async {
    if (_isPolling || !mounted) return;
    _isPolling = true;
    try {
      final status = await UsersService.getDriverStatus();
      if (status['adminApproved'] == true && mounted) {
        _pollTimer?.cancel();
        _showApprovedDialog();
      }
    } catch (_) {}
    _isPolling = false;
  }

  void _showApprovedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 20),
            Text('Compte approuvé ! 🎉',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text('Votre compte a été validé. Vous pouvez maintenant commencer à recevoir des courses.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight, height: 1.5)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
                  (r) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Commencer à conduire 🚗',
                style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final t = loc.t;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('logout'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        content: Text(t('logout_confirm'), style: GoogleFonts.dmSans()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(t('logout'), style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await AuthService.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    _fadeCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = loc.t;

    final items = [
      {'icon': Icons.badge_outlined, 'label': t('id_document')},
      {'icon': Icons.credit_card, 'label': t('driver_license')},
      {'icon': Icons.directions_car_outlined, 'label': t('vehicle_insurance')},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // ── Illustration animée ───────────────────────────────────
                AnimatedBuilder(
                  animation: Listenable.merge([_pulseCtrl, _floatCtrl]),
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _floatAnim.value),
                    child: ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2 + _pulseCtrl.value * 0.1),
                              blurRadius: 30 + _pulseCtrl.value * 10,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.assignment_late_outlined,
                          color: AppColors.primary,
                          size: 56,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Nom du chauffeur ──────────────────────────────────────
                Text(
                  'Bonjour, $_driverName 👋',
                  style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  t('pending_title'),
                  style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark, height: 1.3),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  t('pending_desc'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textLight, height: 1.6),
                ),

                const SizedBox(height: 28),

                // ── Délai estimé ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(t('pending_eta'),
                        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Liste des vérifications ───────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.checklist_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('Vérifications en cours',
                            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: AppColors.divider, height: 1),
                      const SizedBox(height: 12),
                      ...items.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGray,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(item['icon'] as IconData, color: AppColors.primary, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(item['label'] as String,
                              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark))),
                            // Indicateur pulsant
                            AnimatedBuilder(
                              animation: _pulseCtrl,
                              builder: (_, __) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Color.lerp(AppColors.warningLight, AppColors.primaryLight, _pulseCtrl.value),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(t('in_progress'),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10, fontWeight: FontWeight.w600,
                                    color: Color.lerp(AppColors.warning, AppColors.primary, _pulseCtrl.value),
                                  )),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Actions ───────────────────────────────────────────────
                KoogweButton(
                  label: t('pending_btn'),
                  icon: Icons.edit_document,
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const DriverDocumentScreen(),
                  )),
                ),
                const SizedBox(height: 12),
                KoogweOutlinedButton(
                  label: t('logout'),
                  icon: Icons.logout,
                  onPressed: _logout,
                ),

                // ── Info polling ──────────────────────────────────────────
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.lerp(AppColors.success, AppColors.primary, _pulseCtrl.value),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Vérification automatique en cours...',
                        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textLight)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
