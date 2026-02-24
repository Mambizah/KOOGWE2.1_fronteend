import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';
import 'driver_facial_screen.dart';

class VehicleRegistrationScreen extends StatefulWidget {
  const VehicleRegistrationScreen({super.key});

  @override
  State<VehicleRegistrationScreen> createState() => _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  String _selectedVehicleType = 'MOTO';
  bool _loading = false;
  String? _error;

  final List<String> _vehicleTypes = ['MOTO', 'TAXI', 'CONFORT', 'VAN'];
  final List<String> _colors = ['Blanc', 'Noir', 'Gris', 'Rouge', 'Bleu', 'Vert', 'Jaune', 'Autre'];

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await UsersService.updateVehicle(
        vehicleMake: _makeCtrl.text.trim(),
        vehicleModel: _modelCtrl.text.trim(),
        vehicleColor: _colorCtrl.text.trim(),
        licensePlate: _plateCtrl.text.trim().toUpperCase(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Véhicule enregistré !', style: GoogleFonts.dmSans()),
          backgroundColor: AppColors.success,
        ));
        // Passer à la vérification faciale
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DriverFacialScreen()));
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Erreur d\'enregistrement';
      setState(() => _error = msg.toString());
    } catch (_) {
      setState(() => _error = 'Erreur de connexion au serveur');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Votre véhicule', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(24)),
                  child: const Icon(Icons.directions_car, color: AppColors.primary, size: 40),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Text('Informations du véhicule', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    const SizedBox(height: 4),
                    Text('Complétez ces informations pour démarrer', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Type de véhicule
              Text('Type de véhicule', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
              const SizedBox(height: 8),
              Row(
                children: _vehicleTypes.map((type) {
                  final selected = _selectedVehicleType == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedVehicleType = type),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primaryLight : AppColors.surface,
                          border: Border.all(color: selected ? AppColors.primary : AppColors.cardBorder, width: selected ? 2 : 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(child: Text(type, style: GoogleFonts.dmSans(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: selected ? AppColors.primary : AppColors.textLight,
                        ))),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Marque
              KoogweInput(
                label: 'Marque',
                hint: 'Ex: Toyota, Honda...',
                prefixIcon: Icons.branding_watermark_outlined,
                controller: _makeCtrl,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),

              // Modèle
              KoogweInput(
                label: 'Modèle',
                hint: 'Ex: Corolla, CB125...',
                prefixIcon: Icons.directions_car_outlined,
                controller: _modelCtrl,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),

              // Couleur
              Text('Couleur', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _colors.map((color) {
                  final selected = _colorCtrl.text == color;
                  return GestureDetector(
                    onTap: () { setState(() => _colorCtrl.text = color); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primaryLight : AppColors.surface,
                        border: Border.all(color: selected ? AppColors.primary : AppColors.cardBorder, width: selected ? 2 : 1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(color, style: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: selected ? AppColors.primary : AppColors.textMedium,
                      )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Plaque
              KoogweInput(
                label: 'Numéro d\'immatriculation',
                hint: 'Ex: TG-1234-AB',
                prefixIcon: Icons.confirmation_number_outlined,
                controller: _plateCtrl,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
              KoogweButton(
                label: 'Continuer →',
                icon: Icons.arrow_forward,
                onPressed: _submit,
                loading: _loading,
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Étape 1/3 : Véhicule → Vérification faciale → Documents',
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textHint),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
