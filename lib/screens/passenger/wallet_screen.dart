import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

class WalletScreen extends StatefulWidget {
  final String userId;
  const WalletScreen({super.key, required this.userId});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _selectedMode = 0;
  double _balance = 0;
  List<TransactionModel> _transactions = [];
  bool _loading = true;
  String? _error;
  String _resolvedUserId = '';

  @override
  void initState() {
    super.initState();
    _resolveAndLoad();
  }

  @override
  void didUpdateWidget(WalletScreen old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) _resolveAndLoad();
  }

  // ✅ FIX : Résoudre le userId depuis SharedPreferences si vide
  Future<void> _resolveAndLoad() async {
    String uid = widget.userId;
    if (uid.isEmpty) {
      uid = await AuthService.getUserId() ?? '';
    }
    if (uid.isEmpty) {
      setState(() { _loading = false; _error = 'Utilisateur non connecté'; });
      return;
    }
    _resolvedUserId = uid;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_resolvedUserId.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final balance = await WalletService.getBalance(_resolvedUserId);
      final txRaw = await WalletService.getTransactions(_resolvedUserId);
      if (mounted) {
        setState(() {
          _balance = balance;
          _transactions = txRaw.map((t) => TransactionModel.fromJson(t)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Impossible de charger le portefeuille'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: Text('Mon Portefeuille', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
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
                    TextButton(onPressed: _resolveAndLoad, child: const Text('Réessayer')),
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
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: AppColors.surfaceGray, borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            children: [
                              _ModeTab(label: 'Personnel', selected: _selectedMode == 0, onTap: () => setState(() => _selectedMode = 0)),
                              _ModeTab(label: 'Professionnel', selected: _selectedMode == 1, onTap: () => setState(() => _selectedMode = 1)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryAccent, Color(0xFF5B73FF)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 8))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Solde Disponible', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('${_balance.toStringAsFixed(0)} FCFA', style: GoogleFonts.dmSans(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.add, color: Colors.white, size: 16),
                                        const SizedBox(width: 4),
                                        Text('Recharger', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: _QuickAction(icon: Icons.add_circle_outline, label: 'Ajouter', onTap: () {})),
                            const SizedBox(width: 10),
                            Expanded(child: _QuickAction(icon: Icons.send_outlined, label: 'Envoyer', onTap: () {})),
                            const SizedBox(width: 10),
                            Expanded(child: _QuickAction(icon: Icons.download_outlined, label: 'Retrait', onTap: () {})),
                            const SizedBox(width: 10),
                            Expanded(child: _QuickAction(icon: Icons.history_outlined, label: 'Historique', onTap: () {})),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Activité Récente', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                            Text('Tout voir', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_transactions.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textHint),
                                  const SizedBox(height: 8),
                                  Text('Aucune transaction', style: GoogleFonts.dmSans(color: AppColors.textLight)),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._transactions.map((t) => _TransactionTile(transaction: t)),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected ? [const BoxShadow(color: Color(0x0F000000), blurRadius: 8)] : null,
          ),
          child: Center(child: Text(label, style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.textDark : AppColors.textLight,
          ))),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textLight)),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final d = transaction.createdAt;
    final date = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: transaction.isPositive ? AppColors.successLight : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              transaction.isPositive ? Icons.add : Icons.directions_car_outlined,
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
                Text(date, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(transaction.formattedAmount, style: GoogleFonts.dmSans(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: transaction.isPositive ? AppColors.success : AppColors.textDark,
              )),
              Text(transaction.status, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
        ],
      ),
    );
  }
}
