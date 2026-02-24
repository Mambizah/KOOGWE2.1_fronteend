import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import 'confort_screen.dart';
import 'wallet_screen.dart';
import 'historique_screen.dart';
import '../auth/login_screen.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  int _navIndex = 0;
  String _userName = 'Utilisateur';
  String _userId = '';
  String _userEmail = '';
  String _userPhone = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final name = await AuthService.getUserName();
    final id = await AuthService.getUserId();
    final email = await AuthService.getUserEmail();
    final phone = await AuthService.getUserPhone();
    if (mounted) setState(() {
      _userName = name ?? 'Utilisateur';
      _userId = id ?? '';
      _userEmail = email ?? '';
      _userPhone = phone ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeContent(userName: _userName, userId: _userId),
      const _DeliveryPlaceholder(),
      WalletScreen(userId: _userId),
      _ProfilePage(
        userName: _userName,
        userEmail: _userEmail,
        userPhone: _userPhone,
        onUpdate: _loadUser,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _navIndex, children: pages),
      bottomNavigationBar: PassengerBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final String userName;
  final String userId;
  const _HomeContent({required this.userName, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: MapPlaceholder()),
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10)]),
                    child: const Icon(Icons.menu, color: AppColors.textDark),
                  ),
                  const Spacer(),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10)]),
                    child: const Icon(Icons.security, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 16, bottom: 280,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 10)]),
            child: const Icon(Icons.my_location, color: AppColors.primary, size: 20),
          ),
        ),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: _BottomSearchSheet(userName: userName),
        ),
      ],
    );
  }
}

class _BottomSearchSheet extends StatelessWidget {
  final String userName;
  const _BottomSearchSheet({required this.userName});

  String get _firstName => userName.split(' ').first;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x15000000), blurRadius: 30, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Bonjour, $_firstName 👋', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          Text('Prêt pour un trajet ?', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfortScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(color: AppColors.surfaceGray, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Où allez-vous ?', style: GoogleFonts.dmSans(fontSize: 15, color: AppColors.textHint))),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder)),
                    child: const Icon(Icons.my_location, color: AppColors.primary, size: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoriqueScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: AppColors.surfaceGray, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.history, color: AppColors.textLight, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mes dernières courses', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                        Text('Voir l\'historique', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textLight)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textLight),
                ],
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _DeliveryPlaceholder extends StatelessWidget {
  const _DeliveryPlaceholder();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.background,
    body: Center(child: Text('Livraison — Bientôt disponible')),
  );
}

/// ─── Profil passager éditable ─────────────────────────────────────────────
class _ProfilePage extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String userPhone;
  final VoidCallback onUpdate;
  const _ProfilePage({required this.userName, required this.userEmail, required this.userPhone, required this.onUpdate});

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  bool _notificationsEnabled = true;

  void _editProfile() {
    final nameCtrl = TextEditingController(text: widget.userName);
    final phoneCtrl = TextEditingController(text: widget.userPhone);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Modifier le profil', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: 'Nom complet', prefixIcon: const Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: 'Téléphone', prefixIcon: const Icon(Icons.phone_outlined)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              try {
                await AuthService.updateProfile(name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim());
                widget.onUpdate();
                if (context.mounted) { Navigator.pop(context); }
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryAccent]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(
                    widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                    style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                  )),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: GestureDetector(
                    onTap: _editProfile,
                    child: Container(
                      width: 28, height: 28,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(widget.userName, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            Text(widget.userEmail, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textLight)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
              child: Text('Passager KOOGWE', style: GoogleFonts.dmSans(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 24),

            // Menu
            _ProfileSection('Compte'),
            _ProfileTile(icon: Icons.person_outline, title: 'Modifier le profil', onTap: _editProfile),
            _ProfileTile(icon: Icons.history, title: 'Historique', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoriqueScreen()))),

            const SizedBox(height: 16),
            _ProfileSection('Préférences'),
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
              child: ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 18),
                ),
                title: Text('Notifications', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                trailing: Switch(value: _notificationsEnabled, onChanged: (v) => setState(() => _notificationsEnabled = v), activeColor: AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            _ProfileTile(icon: Icons.help_outline, title: 'Aide & Support', onTap: () {}),
            _ProfileTile(icon: Icons.info_outline, title: 'À propos de KOOGWE', onTap: () => _showAbout(context)),

            const SizedBox(height: 24),
            KoogweButton(
              label: 'Se déconnecter',
              backgroundColor: AppColors.errorLight,
              textColor: AppColors.error,
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text('Déconnexion', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                    content: Text('Voulez-vous vous déconnecter ?', style: GoogleFonts.dmSans()),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                        child: Text('Déconnexion', style: GoogleFonts.dmSans(color: Colors.white))),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await AuthService.logout();
                  SocketService.disconnect();
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('KOOGWE', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        content: Text('Application de transport premium à Lomé, Togo.\n\nVersion 1.0.0\n© 2026 KOOGWE', style: GoogleFonts.dmSans()),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK', style: TextStyle(color: AppColors.primary)))],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  const _ProfileSection(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: GoogleFonts.dmSans(color: AppColors.textLight, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.8)),
  );
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ProfileTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: ListTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        title: Text(title, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textLight),
        onTap: onTap,
      ),
    );
  }
}

class PassengerBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  const PassengerBottomNav({required this.currentIndex, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textLight,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
        BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), label: 'Livraison'),
        BottomNavigationBarItem(icon: Icon(Icons.wallet_outlined), label: 'Portefeuille'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
      ],
    );
  }
}
