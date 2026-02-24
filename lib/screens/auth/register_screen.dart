import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  final bool isPassenger;
  const RegisterScreen({super.key, required this.isPassenger});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // ignore: unused_field
  String _selectedCountry = 'Togo';
  String _selectedDialCode = '+228';
  bool _loading = false;
  String? _error;
  int _step = 0;

  static const List<Map<String, String>> _countries = [
    {'name': 'Togo', 'code': '+228', 'flag': '🇹🇬'},
    {'name': 'Côte d\'Ivoire', 'code': '+225', 'flag': '🇨🇮'},
    {'name': 'Ghana', 'code': '+233', 'flag': '🇬🇭'},
    {'name': 'Bénin', 'code': '+229', 'flag': '🇧🇯'},
    {'name': 'Sénégal', 'code': '+221', 'flag': '🇸🇳'},
    {'name': 'France', 'code': '+33', 'flag': '🇫🇷'},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _phoneCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    // ✅ FIX : Fermer le clavier AVANT toute validation pour éviter le crash ViewInsets
    FocusScope.of(context).unfocus();

    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty ||
        _phoneCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Veuillez remplir tous les champs');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Le mot de passe doit contenir au moins 6 caractères');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await AuthService.register(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        name: _nameCtrl.text.trim(),
        phone: '$_selectedDialCode${_phoneCtrl.text.trim()}',
        role: widget.isPassenger ? 'PASSENGER' : 'DRIVER',
      );

      if (!mounted) return;

      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OtpScreen(
          email: _emailCtrl.text.trim(),
          isPassenger: widget.isPassenger,
        ),
      ));
    } on DioException catch (e) {
      // ✅ DEBUG : Affiche le code HTTP + le vrai message du backend
      final statusCode = e.response?.statusCode ?? 0;
      final msg = e.response?.data?['message'] ??
                  e.response?.data?['error'] ??
                  'Erreur lors de l\'inscription';
      setState(() => _error = '[$statusCode] ${msg is List ? msg.join(', ') : msg.toString()}');
    } catch (e) {
      // ✅ DEBUG : Affiche l'erreur réelle au lieu de masquer
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // ✅ FIX : resizeToAvoidBottomInset false pour éviter le recalcul de viewInsets
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: _step == 0 ? _buildRoleStep() : _buildFormStep(),
      ),
    );
  }

  Widget _buildRoleStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textDark),
            ),
          ),
          const SizedBox(height: 32),
          Text('Rejoindre KOOGWE', style: GoogleFonts.dmSans(
            fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark,
          )),
          const SizedBox(height: 8),
          Text('Vous êtes :', style: GoogleFonts.dmSans(
            fontSize: 16, color: AppColors.textLight,
          )),
          const SizedBox(height: 24),
          _RoleCard(
            icon: Icons.person,
            title: 'Passager',
            desc: 'Réservez des courses premium',
            selected: widget.isPassenger,
            onTap: () => setState(() => _step = 1),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.directions_car,
            title: 'Chauffeur',
            desc: 'Conduisez et gagnez de l\'argent',
            selected: !widget.isPassenger,
            onTap: () => setState(() => _step = 1),
          ),
          const Spacer(),
          KoogweButton(label: 'Continuer', onPressed: () => setState(() => _step = 1)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFormStep() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          // ✅ FIX : padding bas géré manuellement puisque resizeToAvoidBottomInset = false
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => setState(() => _step = 0),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textDark),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('Créer un compte', style: GoogleFonts.dmSans(
                    fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark,
                  )),
                  const SizedBox(height: 6),
                  Text(
                    widget.isPassenger
                        ? 'Commencez à réserver vos courses'
                        : 'Commencez à conduire et à gagner',
                    style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight, height: 1.5),
                  ),
                  const SizedBox(height: 28),

                  KoogweInput(
                    label: 'Nom complet',
                    hint: 'ex. Juan Pérez',
                    prefixIcon: Icons.person_outline,
                    controller: _nameCtrl,
                  ),
                  const SizedBox(height: 16),

                  KoogweInput(
                    label: 'Adresse email',
                    hint: 'nom@exemple.com',
                    prefixIcon: Icons.mail_outline,
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // ── Indicatif + Téléphone ──────────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Téléphone',
                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _showCountryPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Text(_selectedDialCode,
                                    style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down, color: AppColors.textLight, size: 16),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.dmSans(fontSize: 15, color: AppColors.textDark),
                              decoration: InputDecoration(
                                hintText: '06 12 34 56 78',
                                hintStyle: GoogleFonts.dmSans(color: AppColors.textHint),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  KoogweInput(
                    label: 'Mot de passe',
                    hint: '••••••••',
                    obscure: true,
                    prefixIcon: Icons.lock_outline,
                    controller: _passCtrl,
                  ),

                  // ── Message d'erreur ──────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // ✅ FIX : onPressed bloqué si _loading pour éviter le double submit
                  KoogweButton(
                    label: 'Créer mon compte',
                    onPressed: _loading ? null : _register,
                    loading: _loading,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Indicatif pays',
              style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 16),
            ..._countries.map((c) => ListTile(
              onTap: () {
                setState(() {
                  _selectedCountry = c['name']!;
                  _selectedDialCode = c['code']!;
                });
                Navigator.pop(context);
              },
              leading: Text(c['flag']!, style: const TextStyle(fontSize: 24)),
              title: Text(c['name']!, style: GoogleFonts.dmSans(fontSize: 15)),
              trailing: Text(c['code']!, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textLight)),
            )),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard({
    required this.icon, required this.title, required this.desc,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surfaceGray,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: selected ? Colors.white : AppColors.textLight, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  Text(desc,
                    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textLight)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}