import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/socket_service.dart';
import 'tracking_screen.dart';
import 'home_screen.dart';

class SearchingScreen extends StatefulWidget {
  final String rideId;
  final String destination;
  final double price;

  const SearchingScreen({
    super.key,
    required this.rideId,
    required this.destination,
    required this.price,
  });

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  Timer? _timeoutTimer;
  int _remainingSeconds = 90; // 90 secondes timeout
  bool _driverFound = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _startTimeoutCountdown();
    _listenForDriver();
  }

  void _startTimeoutCountdown() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _showNoDriverDialog();
      }
    });
  }

  void _listenForDriver() {
    SocketService.joinRide(widget.rideId);
    SocketService.onRideStatus(widget.rideId, (data) {
      final status = data['status'] as String?;
      if (status == 'ACCEPTED' && !_driverFound) {
        _driverFound = true;
        _timeoutTimer?.cancel();
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => TrackingScreen(rideId: widget.rideId, price: widget.price),
          ));
        }
      }
    });
  }

  void _showNoDriverDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Aucun chauffeur disponible', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        content: Text(
          'Aucun chauffeur n\'a pu accepter votre course pour le moment. Réessayez dans quelques instants.',
          style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Fermer dialog
              Navigator.pop(context); // Retour à l'accueil
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Retour', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timeoutTimer?.cancel();
    SocketService.off('ride_status_${widget.rideId}');
    super.dispose();
  }

  String get _timeFormatted {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return m > 0 ? '${m}m ${s.toString().padLeft(2, '0')}s' : '${s}s';
  }

  double get _progressValue => 1 - (_remainingSeconds / 90);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Recherche en cours', style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),

            // Animation radar
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) => Stack(
                alignment: Alignment.center,
                children: [
                  // Cercles pulsants
                  for (int i = 3; i >= 1; i--)
                    Container(
                      width: 80.0 + i * 50 + _pulseCtrl.value * 20,
                      height: 80.0 + i * 50 + _pulseCtrl.value * 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.04 * (4 - i) * (0.6 + _pulseCtrl.value * 0.4)),
                      ),
                    ),
                  // Centre
                  Container(
                    width: 80, height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_taxi, color: AppColors.primary, size: 40),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            Text(
              'Recherche d\'un chauffeur',
              style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              'Vers : ${widget.destination}',
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${widget.price.toStringAsFixed(0)} FCFA',
                style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),

            const SizedBox(height: 40),

            // Barre de progression / timer
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Temps restant', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textLight)),
                    Text(
                      _timeFormatted,
                      style: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: _remainingSeconds < 20 ? AppColors.error : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progressValue,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceGray,
                    valueColor: AlwaysStoppedAnimation(
                      _remainingSeconds < 20 ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Infos
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceGray,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.textLight),
                    const SizedBox(width: 8),
                    Text('Les chauffeurs proches sont notifiés', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textLight)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.shield_outlined, size: 16, color: AppColors.textLight),
                    const SizedBox(width: 8),
                    Text('Course assurée par KOOGWE', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textLight)),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 16),

            TextButton(
              onPressed: () {
                _timeoutTimer?.cancel();
                Navigator.pop(context);
              },
              child: Text(
                'Annuler la course',
                style: GoogleFonts.dmSans(fontSize: 15, color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
