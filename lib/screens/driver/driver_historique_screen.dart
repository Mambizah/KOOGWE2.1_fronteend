import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../models/models.dart';

class DriverHistoriqueScreen extends StatefulWidget {
  const DriverHistoriqueScreen({super.key});

  @override
  State<DriverHistoriqueScreen> createState() => _DriverHistoriqueScreenState();
}

class _DriverHistoriqueScreenState extends State<DriverHistoriqueScreen> {
  List<RideModel> _rides = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    SocketService.onTripFinished((_) => _loadHistory());
  }

  @override
  void dispose() {
    SocketService.off('trip_finished');
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await RidesService.getHistory();
      if (mounted) {
        setState(() {
          _rides = raw.map((r) => RideModel.fromJson(r)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Impossible de charger l\'historique'; _loading = false; });
    }
  }

  double get _totalEarnings => _rides.where((r) => r.isCompleted).fold(0, (sum, r) => sum + r.price);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.surfaceGray, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textDark)),
        ),
        title: Text('Historique des Courses', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.textDark), onPressed: _loadHistory),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.textHint),
                    Text(_error!), const SizedBox(height: 16),
                    TextButton(onPressed: _loadHistory, child: const Text('Réessayer')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats row
                        Row(
                          children: [
                            Expanded(child: _StatCard(
                              label: 'TOTAL GAGNÉ',
                              value: '${_totalEarnings.toStringAsFixed(0)} FCFA',
                              badge: '${_rides.length} courses',
                              badgePositive: true,
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard(
                              label: 'TERMINÉES',
                              value: '${_rides.where((r) => r.isCompleted).length}',
                              badge: '${_rides.where((r) => r.isCancelled).length} annulées',
                              badgePositive: null,
                            )),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (_rides.isEmpty)
                          Center(child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.directions_car_outlined, size: 64, color: AppColors.textHint),
                              const SizedBox(height: 12),
                              Text('Aucune course pour le moment', style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.textLight)),
                            ],
                          ))
                        else
                          ..._rides.map((r) => _DriverRideCard(ride: r)),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, badge;
  final bool? badgePositive;
  const _StatCard({required this.label, required this.value, required this.badge, this.badgePositive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textLight, letterSpacing: 0.8, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(height: 6),
          Text(badge, style: GoogleFonts.dmSans(fontSize: 11, color: badgePositive == true ? AppColors.success : AppColors.textLight)),
        ],
      ),
    );
  }
}

class _DriverRideCard extends StatelessWidget {
  final RideModel ride;
  const _DriverRideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: ride.isCompleted ? AppColors.primaryLight : AppColors.errorLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              ride.isCompleted ? Icons.directions_car_outlined : Icons.block,
              color: ride.isCompleted ? AppColors.primary : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ride.passengerName ?? 'Passager', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                Text('${ride.formattedDate} • ${ride.vehicleType}', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(ride.formattedPrice, style: GoogleFonts.dmSans(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: ride.isCompleted ? AppColors.textDark : AppColors.textHint,
                decoration: ride.isCancelled ? TextDecoration.lineThrough : null,
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ride.isCompleted ? AppColors.successLight : AppColors.errorLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ride.isCompleted ? 'Terminée' : 'Annulée',
                  style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: ride.isCompleted ? AppColors.success : AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
