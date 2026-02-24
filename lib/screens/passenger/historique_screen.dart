import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../models/models.dart';

class HistoriqueScreen extends StatefulWidget {
  const HistoriqueScreen({super.key});

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<RideModel> _rides = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadHistory();

    // Écouter les nouvelles courses terminées en temps réel
    SocketService.onTripFinished((data) {
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
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

  List<RideModel> get _completed => _rides.where((r) => r.isCompleted).toList();
  List<RideModel> get _cancelled => _rides.where((r) => r.isCancelled).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Historique', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        backgroundColor: AppColors.surface, elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.surfaceGray, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textDark),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.textDark), onPressed: _loadHistory),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Terminées'), Tab(text: 'Annulées')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.textHint),
                    const SizedBox(height: 12),
                    Text(_error!, style: GoogleFonts.dmSans(color: AppColors.textLight)),
                    const SizedBox(height: 16),
                    TextButton(onPressed: _loadHistory, child: const Text('Réessayer')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _buildList(_completed),
                      _buildList(_cancelled),
                    ],
                  ),
                ),
    );
  }

  Widget _buildList(List<RideModel> rides) {
    return rides.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_car_outlined, size: 64, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text('Aucune course', style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.textLight)),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            itemBuilder: (_, i) => _RideCard(ride: rides[i]),
          );
  }
}

class _RideCard extends StatelessWidget {
  final RideModel ride;
  const _RideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.directions_car_outlined, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ride.formattedDate, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textLight)),
                    Text(ride.driverName != null ? 'Chauffeur : ${ride.driverName}' : 'Course ${ride.vehicleType}',
                      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  ],
                ),
              ),
              Text(ride.formattedPrice, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 12),
          // Status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ride.isCompleted ? AppColors.successLight : AppColors.errorLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ride.isCompleted ? 'Terminée' : 'Annulée',
                  style: GoogleFonts.dmSans(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: ride.isCompleted ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.replay, size: 14),
                label: Text('Recommander', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
