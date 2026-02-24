import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

class DriverWalletScreen extends StatefulWidget {
  final String driverId;
  const DriverWalletScreen({super.key, required this.driverId});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  double _balance = 0;
  DriverStats? _stats;
  List<TransactionModel> _transactions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // ✅ FIX BUG #4 : Fallback si driverId vide → charger depuis SharedPreferences
    _resolveAndLoad();
  }

  @override
  void didUpdateWidget(DriverWalletScreen old) {
    super.didUpdateWidget(old);
    if (old.driverId != widget.driverId) _resolveAndLoad();
  }

  Future<void> _resolveAndLoad() async {
    String id = widget.driverId;
    if (id.isEmpty) {
      id = await AuthService.getUserId() ?? '';
    }
    if (id.isEmpty) {
      setState(() { _loading = false; _error = 'ID chauffeur introuvable'; });
      return;
    }
    // Utiliser l'ID résolu
    if (mounted) _loadData(resolvedId: id);
  }

  Future<void> _loadData({String? resolvedId}) async {
    final id = resolvedId ?? widget.driverId;
    if (id.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final balance = await WalletService.getBalance(id);
      final transactions = await WalletService.getTransactions(id);
      final statsData = await RidesService.getDriverStats();
      if (mounted) {
        setState(() {
          _balance = balance;
          _transactions = transactions.map((t) => TransactionModel.fromJson(t)).toList();
          _stats = DriverStats.fromJson(statsData);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Impossible de charger les revenus'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: Text('Revenus', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.textDark), onPressed: _loadData),
        ],
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
                    TextButton(onPressed: _loadData, child: const Text('Réessayer')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Balance
                        Center(
                          child: Column(
                            children: [
                              Text('Solde actuel', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight)),
                              const SizedBox(height: 6),
                              Text('${_balance.toStringAsFixed(0)} FCFA', style: GoogleFonts.dmSans(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Withdrawal button
                        Container(
                          width: double.infinity, height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryAccent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                if (_balance < 1) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text('Solde insuffisant', style: GoogleFonts.dmSans()),
                                    backgroundColor: AppColors.error,
                                  ));
                                  return;
                                }
                                // TODO: Implémenter le virement
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Demande de virement envoyée !', style: GoogleFonts.dmSans()),
                                  backgroundColor: AppColors.success,
                                ));
                              },
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.bolt, color: Colors.white, size: 20),
                                    const SizedBox(width: 6),
                                    Text('Virement Immédiat', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Stats cards
                        if (_stats != null) ...[
                          Row(
                            children: [
                              Expanded(child: _StatCard(label: 'COURSES AUJD.', value: '${_stats!.todayRides}', badge: '${_stats!.totalRides} au total')),
                              const SizedBox(width: 12),
                              Expanded(child: _StatCard(label: 'TOTAL GAGNÉ', value: '${_stats!.totalEarnings.toStringAsFixed(0)} FCFA', badge: 'Depuis le début', positive: true)),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                        // Transactions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Transactions récentes', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                            Text('Tout voir', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_transactions.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            child: Center(child: Column(children: [
                              const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textHint),
                              const SizedBox(height: 8),
                              Text('Aucune transaction', style: GoogleFonts.dmSans(color: AppColors.textLight)),
                            ])),
                          )
                        else
                          ..._transactions.map((t) => _TransactionItem(transaction: t)),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, badge;
  final bool? positive;
  const _StatCard({required this.label, required this.value, required this.badge, this.positive});

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
          Text(badge, style: GoogleFonts.dmSans(fontSize: 11, color: positive == true ? AppColors.success : AppColors.textLight)),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final TransactionModel transaction;
  const _TransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: transaction.isPositive ? AppColors.successLight : const Color(0xFFEEF1FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              transaction.isPositive ? Icons.directions_car_outlined : Icons.account_balance_outlined,
              color: transaction.isPositive ? AppColors.success : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                Text(_formatDate(transaction.createdAt), style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(transaction.formattedAmount, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: transaction.isPositive ? AppColors.success : AppColors.textDark)),
              Text(transaction.status, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
