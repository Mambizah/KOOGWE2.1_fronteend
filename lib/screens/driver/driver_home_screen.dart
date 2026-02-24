import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/i18n_service.dart';
import '../../models/models.dart';
import 'driver_wallet_screen.dart';
import 'driver_document_screen.dart';
import 'driver_historique_screen.dart';
import '../auth/login_screen.dart';
import 'driver_active_ride_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _navIndex = 0;
  String _driverId = '';
  String _driverName = 'Chauffeur';
  DriverStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadDriver();
  }

  Future<void> _loadDriver() async {
    final id = await AuthService.getUserId();
    final name = await AuthService.getUserName();
    if (mounted) {
      setState(() { _driverId = id ?? ''; _driverName = name ?? 'Chauffeur'; });
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    try {
      final data = await RidesService.getDriverStats();
      if (mounted) setState(() => _stats = DriverStats.fromJson(data));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DriverMapContent(driverId: _driverId, driverName: _driverName, stats: _stats, onRefresh: _loadStats),
      DriverWalletScreen(driverId: _driverId),
      const DriverDocumentScreen(),
      _DriverProfilePage(driverName: _driverName),
    ];

    return Scaffold(
      body: IndexedStack(index: _navIndex, children: pages),
      bottomNavigationBar: DriverBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

class _DriverMapContent extends StatefulWidget {
  final String driverId;
  final String driverName;
  final DriverStats? stats;
  final VoidCallback onRefresh;
  const _DriverMapContent({required this.driverId, required this.driverName, this.stats, required this.onRefresh});

  @override
  State<_DriverMapContent> createState() => _DriverMapContentState();
}

class _DriverMapContentState extends State<_DriverMapContent> {
  bool _isOnline = false;
  Map<String, dynamic>? _pendingRide;

  @override
  void initState() {
    super.initState();
    // Écouter les nouvelles courses
    SocketService.onNewRide((rideData) {
      if (_isOnline && mounted) {
        setState(() => _pendingRide = rideData);
      }
    });
  }

  @override
  void dispose() {
    SocketService.off('new_ride');
    super.dispose();
  }

  void _toggleOnline() {
    setState(() => _isOnline = !_isOnline);
    if (_isOnline) {
      SocketService.goOnline(widget.driverId);
    } else {
      SocketService.goOffline(widget.driverId);
      setState(() => _pendingRide = null);
    }
  }

  void _acceptRide() {
    if (_pendingRide == null) return;
    final rideId = _pendingRide!['id'] as String;
    final passengerName = (_pendingRide!['passenger']?['name'] as String?) ?? 'Passager';
    final passengerPhone = _pendingRide!['passenger']?['phone'] as String?;
    final price = (_pendingRide!['price'] as num?)?.toDouble() ?? 0.0;
    final vehicleType = (_pendingRide!['vehicleType'] as String?) ?? 'MOTO';

    SocketService.acceptRide(rideId: rideId, driverId: widget.driverId);
    setState(() => _pendingRide = null);

    // ✅ Naviguer vers l'écran de course active (arrivée → démarrage → fin)
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DriverActiveRideScreen(
        rideId: rideId,
        passengerName: passengerName,
        passengerPhone: passengerPhone,
        price: price,
        vehicleType: vehicleType,
      ),
    ));
    widget.onRefresh();
  }

  void _declineRide() {
    setState(() => _pendingRide = null);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: MapPlaceholder()),
        // Stats bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [const BoxShadow(color: Color(0x12000000), blurRadius: 16)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GAINS DU JOUR', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textLight, letterSpacing: 0.8, fontWeight: FontWeight.w500)),
                        Text(
                          widget.stats != null ? '${widget.stats!.dailyEarnings.toStringAsFixed(0)} FCFA' : '—',
                          style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: AppColors.divider),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('COURSES AUJD.', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textLight, letterSpacing: 0.8, fontWeight: FontWeight.w500)),
                          Text(
                            widget.stats != null ? '${widget.stats!.todayRides}' : '—',
                            style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: _isOnline ? AppColors.successLight : AppColors.surfaceGray, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.circle, color: _isOnline ? AppColors.success : AppColors.textHint, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Go Online button
        Positioned(
          left: 20, right: 20, bottom: 20,
          child: GestureDetector(
            onTap: _toggleOnline,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isOnline
                      ? [AppColors.success, const Color(0xFF16A34A)]
                      : [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                  color: (_isOnline ? AppColors.success : AppColors.primary).withOpacity(0.4),
                  blurRadius: 16, offset: const Offset(0, 6),
                )],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isOnline ? Icons.pause_circle_outline : Icons.power_settings_new, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      _isOnline ? loc.t('go_offline') : loc.t('go_online'),
                      style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Incoming ride request
        if (_isOnline && _pendingRide != null)
          Positioned(
            left: 16, right: 16, bottom: 100,
            child: _RideRequestCard(
              ride: _pendingRide!,
              onAccept: _acceptRide,
              onDecline: _declineRide,
            ),
          ),
      ],
    );
  }
}

class _RideRequestCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _RideRequestCard({required this.ride, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final price = (ride['price'] as num?)?.toDouble() ?? 0.0;
    final passengerName = ride['passenger']?['name'] ?? 'Passager';
    final vehicleType = ride['vehicleType'] ?? 'MOTO';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.directions_car, color: AppColors.primary, size: 14),
                  const SizedBox(width: 4),
                  Text('$vehicleType • $passengerName', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ]),
              ),
              const Spacer(),
              Text('${price.toStringAsFixed(0)} FCFA', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.cardBorder), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: Text('Refuser', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
                  child: Text('Accepter', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverProfilePage extends StatefulWidget {
  final String driverName;
  const _DriverProfilePage({required this.driverName});

  @override
  State<_DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<_DriverProfilePage> {
  bool _notificationsEnabled = true;
  String _email = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final email = await AuthService.getUserEmail();
    final phone = await AuthService.getUserPhone();
    if (mounted) setState(() {
      _email = email ?? '';
      _phone = phone ?? '';
    });
  }

  void _editProfile() {
    final nameCtrl = TextEditingController(text: widget.driverName);
    final phoneCtrl = TextEditingController(text: _phone);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Modifier le profil', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              try {
                await AuthService.updateProfile(name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim());
                setState(() => _phone = phoneCtrl.text.trim());
                if (context.mounted) Navigator.pop(context);
              } catch (_) {}
            },
            child: Text('Sauvegarder', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Mon Profil', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        backgroundColor: AppColors.surface, elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            Stack(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.success, Color(0xFF16A34A)]),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(
                  widget.driverName.isNotEmpty ? widget.driverName[0].toUpperCase() : 'C',
                  style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                )),
              ),
              Positioned(bottom: 0, right: 0, child: GestureDetector(
                onTap: _editProfile,
                child: Container(
                  width: 28, height: 28,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              )),
            ]),
            const SizedBox(height: 12),
            Text(widget.driverName, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            Text(_email, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textLight)),
            Text('Chauffeur KOOGWE', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textLight)),
            const SizedBox(height: 32),
            _ProfileTile(icon: Icons.history, title: 'Historique des courses', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverHistoriqueScreen()))),
            _ProfileTile(icon: Icons.person_outline, title: 'Modifier le profil', onTap: _editProfile),
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
              child: ListTile(
                leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 18)),
                title: Text('Notifications', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                trailing: Switch(value: _notificationsEnabled, onChanged: (v) => setState(() => _notificationsEnabled = v), activeColor: AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            _ProfileTile(icon: Icons.help_outline, title: 'Aide & Support', onTap: () {}),
            const SizedBox(height: 16),
            KoogweButton(
              label: 'Se déconnecter',
              backgroundColor: AppColors.errorLight,
              textColor: AppColors.error,
              onPressed: () async {
                await AuthService.logout();
                SocketService.disconnect();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ProfileTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textDark)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textLight),
        onTap: onTap,
      ),
    );
  }
}
