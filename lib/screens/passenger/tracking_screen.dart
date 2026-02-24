import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import '../../services/i18n_service.dart';
import 'home_screen.dart';

class TrackingScreen extends StatefulWidget {
  final String rideId;
  final double price;
  const TrackingScreen({super.key, required this.rideId, required this.price});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  String _status = 'ACCEPTED';
  String? _driverName;
  String? _driverPhone;
  String? _vehicleInfo;
  String? _licensePlate;
  double? _driverRating;
  double? _driverLat;
  double? _driverLng;
  bool _ratingShown = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();

    SocketService.joinRide(widget.rideId);

    // ── Écouter les changements de statut en temps réel ──────────────────
    SocketService.onRideStatus(widget.rideId, (data) {
      if (!mounted) return;
      final newStatus = data['status'] as String? ?? _status;
      setState(() {
        _status = newStatus;
        if (data['driverName'] != null) _driverName = data['driverName'];
        if (data['driverPhone'] != null) _driverPhone = data['driverPhone'];
        if (data['vehicleInfo'] != null) _vehicleInfo = data['vehicleInfo'];
        if (data['licensePlate'] != null) _licensePlate = data['licensePlate'];
        if (data['driverRating'] != null) _driverRating = (data['driverRating'] as num).toDouble();
      });

      if (_status == 'COMPLETED' && !_ratingShown) {
        _ratingShown = true;
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _showRatingDialog();
        });
      }

      if (_status == 'ARRIVED') {
        HapticFeedback.mediumImpact();
      }
    });

    // ── Écouter la position GPS du chauffeur en temps réel ───────────────
    SocketService.onDriverLocation(widget.rideId, (lat, lng) {
      if (mounted) setState(() { _driverLat = lat; _driverLng = lng; });
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    SocketService.leaveRide(widget.rideId);
    SocketService.off('ride_status_${widget.rideId}');
    SocketService.off('driver_location_${widget.rideId}');
    super.dispose();
  }

  Future<void> _callDriver() async {
    if (_driverPhone == null || _driverPhone!.isEmpty) {
      _showSnack('Numéro du chauffeur non disponible', error: true);
      return;
    }
    final uri = Uri(scheme: 'tel', path: _driverPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnack('Impossible d\'effectuer l\'appel', error: true);
    }
  }

  Future<void> _cancelRide() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Annuler la course ?', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        content: Text('Êtes-vous sûr de vouloir annuler ?', style: GoogleFonts.dmSans()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Non', style: GoogleFonts.dmSans())),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Oui, annuler', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await ApiService.dio.patch('/rides/${widget.rideId}/cancel');
      } catch (_) {}
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PassengerHomeScreen()),
          (r) => false,
        );
      }
    }
  }

  void _showRatingDialog() {
    int selectedStars = 5;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(color: AppColors.successLight, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
              ),
              const SizedBox(height: 16),
              Text('Course terminée !', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 6),
              Text('${widget.price.toStringAsFixed(0)} FCFA', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
              const SizedBox(height: 20),
              Text('Notez votre chauffeur', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight)),
              if (_driverName != null) ...[
                const SizedBox(height: 4),
                Text(_driverName!, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setModalState(() => selectedStars = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      i < selectedStars ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 42,
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 24),
              KoogweButton(
                label: 'Envoyer la note',
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await ApiService.dio.post('/rides/${widget.rideId}/rate', data: {'rating': selectedStars});
                  } catch (_) {}
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const PassengerHomeScreen()),
                      (r) => false,
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PassengerHomeScreen()), (r) => false);
                },
                child: Text('Ignorer', style: GoogleFonts.dmSans(color: AppColors.textLight)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white)),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String get _statusLabel {
    switch (_status) {
      case 'ACCEPTED': return loc.t('driver_on_way');
      case 'ARRIVED': return loc.t('driver_arrived');
      case 'IN_PROGRESS': return loc.t('ride_in_progress');
      case 'COMPLETED': return loc.t('ride_completed');
      case 'CANCELLED': return loc.t('ride_cancelled');
      default: return _status;
    }
  }

  Color get _statusColor {
    switch (_status) {
      case 'ARRIVED': return AppColors.success;
      case 'IN_PROGRESS': return AppColors.warning;
      case 'COMPLETED': return AppColors.success;
      case 'CANCELLED': return AppColors.error;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool driverVisible = ['ACCEPTED', 'ARRIVED', 'IN_PROGRESS'].contains(_status);

    return Scaffold(
      body: Stack(
        children: [
          // ── 1. Carte OSM plein écran ────────────────────────────────────
          Positioned.fill(
            child: MapPlaceholder(
              showRoute: driverVisible,
              currentLat: _driverLat,
              currentLng: _driverLng,
            ),
          ),

          // ── 2. Header flottant ──────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    if (_status == 'ACCEPTED')
                      GestureDetector(
                        onTap: _cancelRide,
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [BoxShadow(color: Color(0x15000000), blurRadius: 12)],
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textDark),
                        ),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Color(0x15000000), blurRadius: 12)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(_statusLabel, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: _statusColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 3. Bottom sheet ─────────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SlideTransition(
              position: _slideAnim,
              child: driverVisible || _status == 'COMPLETED'
                  ? _DriverFoundSheet(
                      driverName: _driverName ?? 'Chauffeur',
                      vehicleInfo: _vehicleInfo ?? 'Véhicule en route',
                      licensePlate: _licensePlate ?? '———',
                      driverRating: _driverRating,
                      status: _status,
                      price: widget.price,
                      onCall: _callDriver,
                      onCancel: _status == 'ACCEPTED' ? _cancelRide : null,
                      pulseCtrl: _pulseCtrl,
                    )
                  : _WaitingSheet(pulseCtrl: _pulseCtrl),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Waiting sheet (avant acceptation) ──────────────────────────────────────
class _WaitingSheet extends StatelessWidget {
  final AnimationController pulseCtrl;
  const _WaitingSheet({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x18000000), blurRadius: 30, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 28),
            AnimatedBuilder(
              animation: pulseCtrl,
              builder: (_, child) => Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80 + pulseCtrl.value * 30, height: 80 + pulseCtrl.value * 30,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.05 + pulseCtrl.value * 0.05)),
                  ),
                  Container(
                    width: 80, height: 80,
                    decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                    child: const Icon(Icons.radar, color: AppColors.primary, size: 40),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Connexion au chauffeur...', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 6),
            Text('Votre chauffeur vous a accepté. Connexion en cours.', textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textLight, height: 1.5)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Driver found sheet ──────────────────────────────────────────────────────
class _DriverFoundSheet extends StatelessWidget {
  final String driverName, vehicleInfo, licensePlate, status;
  final double? driverRating;
  final double price;
  final VoidCallback onCall;
  final VoidCallback? onCancel;
  final AnimationController pulseCtrl;

  const _DriverFoundSheet({
    required this.driverName, required this.vehicleInfo, required this.licensePlate,
    required this.status, required this.price, required this.onCall, required this.pulseCtrl,
    this.driverRating, this.onCancel,
  });

  Color get _statusBg {
    switch (status) {
      case 'ARRIVED': return AppColors.successLight;
      case 'IN_PROGRESS': return AppColors.warningLight;
      case 'COMPLETED': return AppColors.successLight;
      default: return AppColors.primaryLight;
    }
  }
  Color get _statusFg {
    switch (status) {
      case 'ARRIVED': return AppColors.success;
      case 'IN_PROGRESS': return AppColors.warning;
      case 'COMPLETED': return AppColors.success;
      default: return AppColors.primary;
    }
  }
  String get _statusText {
    switch (status) {
      case 'ACCEPTED': return '🚗 Votre chauffeur arrive';
      case 'ARRIVED': return '✅ Votre chauffeur est arrivé !';
      case 'IN_PROGRESS': return '🚀 Course en cours';
      case 'COMPLETED': return '✓ Course terminée';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x18000000), blurRadius: 30, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            // Driver info row
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF2B40F0), Color(0xFF4F63F5)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: Text(
                    driverName.isNotEmpty ? driverName[0].toUpperCase() : 'C',
                    style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                  )),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driverName, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      Text(vehicleInfo, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textLight)),
                      if (driverRating != null)
                        Row(children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(driverRating!.toStringAsFixed(1), style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                        ]),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.surfaceGray, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder)),
                      child: Text(licensePlate, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark, letterSpacing: 1.5)),
                    ),
                    const SizedBox(height: 4),
                    Text('${price.toStringAsFixed(0)} FCFA', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Status pill
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: _statusBg, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(_statusText, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: _statusFg))),
            ),
            const SizedBox(height: 14),
            // Boutons appel et annuler
            if (status != 'COMPLETED') Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.phone_outlined, size: 18),
                    label: Text('Appeler', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                    ),
                  ),
                ),
                if (onCancel != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
                      label: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
