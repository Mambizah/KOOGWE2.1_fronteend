import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/socket_service.dart';
import '../../services/i18n_service.dart';
import 'driver_home_screen.dart';

class DriverActiveRideScreen extends StatefulWidget {
  final String rideId;
  final String passengerName;
  final String? passengerPhone;
  final double price;
  final String vehicleType;

  const DriverActiveRideScreen({
    super.key,
    required this.rideId,
    required this.passengerName,
    this.passengerPhone,
    required this.price,
    required this.vehicleType,
  });

  @override
  State<DriverActiveRideScreen> createState() => _DriverActiveRideScreenState();
}

class _DriverActiveRideScreenState extends State<DriverActiveRideScreen> {
  // ACCEPTED → ARRIVED → IN_PROGRESS → COMPLETED
  String _tripStatus = 'ACCEPTED';
  bool _loading = false;

  // ── GPS tracking temps réel ──────────────────────────────────────────────
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;
  double? _currentLat;
  double? _currentLng;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  // ── Démarrer le suivi GPS en temps réel ──────────────────────────────────
  void _startLocationTracking() async {
    // Vérifier les permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    // Stream de position en temps réel (précision haute, toutes les 5 secondes)
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20, // Émettre si > 20m de déplacement
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position pos) {
      _currentLat = pos.latitude;
      _currentLng = pos.longitude;
      _emitLocation(pos.latitude, pos.longitude);
    });

    // Fallback timer toutes les 8 secondes si pas de mouvement
    _locationTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        _emitLocation(pos.latitude, pos.longitude);
      } catch (_) {}
    });
  }

  void _emitLocation(double lat, double lng) {
    if (_tripStatus == 'ACCEPTED' || _tripStatus == 'IN_PROGRESS') {
      SocketService.updateLocation(
        rideId: widget.rideId,
        lat: lat,
        lng: lng,
      );
    }
  }

  Future<void> _callPassenger() async {
    if (widget.passengerPhone == null || widget.passengerPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Numéro du passager non disponible', style: GoogleFonts.dmSans()),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    final uri = Uri(scheme: 'tel', path: widget.passengerPhone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _markArrived() async {
    setState(() => _loading = true);
    SocketService.driverArrived(widget.rideId);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() { _tripStatus = 'ARRIVED'; _loading = false; });
  }

  Future<void> _startTrip() async {
    setState(() => _loading = true);
    SocketService.startTrip(widget.rideId);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() { _tripStatus = 'IN_PROGRESS'; _loading = false; });
  }

  Future<void> _finishTrip() async {
    final t = loc.t;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('finish_trip'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        content: Text(
          '${t('finish_trip_confirm')}\n${t('amount')} : ${widget.price.toStringAsFixed(0)} FCFA',
          style: GoogleFonts.dmSans(color: AppColors.textLight),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: Text(t('finish'), style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    // Arrêter le tracking
    _locationTimer?.cancel();
    _positionStream?.cancel();

    SocketService.finishTrip(widget.rideId);
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() => _tripStatus = 'COMPLETED');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = loc.t;
    return Scaffold(
      body: Stack(
        children: [
          // Carte temps réel
          Positioned.fill(
            child: MapPlaceholder(
              showRoute: true,
              currentLat: _currentLat,
              currentLng: _currentLng,
            ),
          ),

          // Header
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.directions_car, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Course en cours', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textLight)),
                            Text(widget.passengerName, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                          ],
                        ),
                      ),
                      // Indicateur GPS actif
                      if (_currentLat != null)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.location_on, size: 10, color: AppColors.success),
                            const SizedBox(width: 3),
                            Text('GPS', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success)),
                          ]),
                        ),
                      Text('${widget.price.toStringAsFixed(0)} FCFA',
                        style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom panel
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Color(0x15000000), blurRadius: 30, offset: Offset(0, -4))],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: Container(width: 36, height: 4,
                      decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),

                    // Status steps
                    _StatusSteps(current: _tripStatus),
                    const SizedBox(height: 20),

                    // Info passager
                    Row(
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryAccent]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(child: Text(
                            widget.passengerName.isNotEmpty ? widget.passengerName[0].toUpperCase() : 'P',
                            style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                          )),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.passengerName, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                              Text(widget.vehicleType, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textLight)),
                            ],
                          ),
                        ),
                        // Bouton appel passager
                        GestureDetector(
                          onTap: _callPassenger,
                          child: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.phone, color: AppColors.success, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Bouton principal selon état
                    if (_tripStatus == 'ACCEPTED')
                      KoogweButton(
                        label: '✅  ${t('arrive_pickup')}',
                        onPressed: _loading ? null : _markArrived,
                        loading: _loading,
                        backgroundColor: AppColors.primary,
                      ),
                    if (_tripStatus == 'ARRIVED')
                      KoogweButton(
                        label: '🚀  ${t('start_trip')}',
                        onPressed: _loading ? null : _startTrip,
                        loading: _loading,
                        backgroundColor: AppColors.warning,
                      ),
                    if (_tripStatus == 'IN_PROGRESS')
                      KoogweButton(
                        label: '🏁  ${t('finish_trip')}',
                        onPressed: _loading ? null : _finishTrip,
                        loading: _loading,
                        backgroundColor: AppColors.success,
                      ),
                    if (_tripStatus == 'COMPLETED')
                      Container(
                        width: double.infinity, height: 56,
                        decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(16)),
                        child: Center(
                          child: Text('Course terminée ! Redirection...', style: GoogleFonts.dmSans(
                            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.success,
                          )),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSteps extends StatelessWidget {
  final String current;
  const _StatusSteps({required this.current});

  int get _currentIndex {
    switch (current) {
      case 'ACCEPTED': return 0;
      case 'ARRIVED': return 1;
      case 'IN_PROGRESS': return 2;
      case 'COMPLETED': return 3;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['En route', 'Arrivé', 'Démarré', 'Terminé'];
    return Row(
      children: List.generate(steps.length, (i) {
        final done = i <= _currentIndex;
        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: done ? AppColors.primary : AppColors.surfaceGray,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text('${i+1}', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textHint)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(steps[i], style: GoogleFonts.dmSans(
                    fontSize: 9, fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                    color: done ? AppColors.primary : AppColors.textHint,
                  )),
                ],
              ),
              if (i < steps.length - 1)
                Expanded(child: Container(height: 2, color: i < _currentIndex ? AppColors.primary : AppColors.divider, margin: const EdgeInsets.only(bottom: 20))),
            ],
          ),
        );
      }),
    );
  }
}
