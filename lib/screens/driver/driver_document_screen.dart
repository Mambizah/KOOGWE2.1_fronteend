import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';

class DriverDocumentScreen extends StatefulWidget {
  const DriverDocumentScreen({super.key});

  @override
  State<DriverDocumentScreen> createState() => _DriverDocumentScreenState();
}

class _DriverDocumentScreenState extends State<DriverDocumentScreen> {
  final _picker = ImagePicker();

  final Map<String, File?> _files = {
    'ID_CARD_FRONT': null,
    'ID_CARD_BACK': null,
    'SELFIE_WITH_ID': null,
    'DRIVERS_LICENSE': null,
    'VEHICLE_REGISTRATION': null,
    'INSURANCE': null,
  };

  final Map<String, String> _labels = {
    'ID_CARD_FRONT': 'CNI (Recto)',
    'ID_CARD_BACK': 'CNI (Verso)',
    'SELFIE_WITH_ID': 'Selfie avec CNI',
    'DRIVERS_LICENSE': 'Permis de conduire',
    'VEHICLE_REGISTRATION': 'Carte grise',
    'INSURANCE': 'Assurance véhicule',
  };

  final Map<String, IconData> _icons = {
    'ID_CARD_FRONT': Icons.credit_card,
    'ID_CARD_BACK': Icons.credit_card,
    'SELFIE_WITH_ID': Icons.face,
    'DRIVERS_LICENSE': Icons.badge,
    'VEHICLE_REGISTRATION': Icons.description,
    'INSURANCE': Icons.shield,
  };

  bool _uploading = false;
  double _uploadProgress = 0;
  Map<String, bool> _uploaded = {};

  int get _readyCount => _files.values.where((f) => f != null).length;
  double get _readyProgress => _readyCount / _files.length;

  Future<void> _pick(String type) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _files[type] = File(picked.path));
    }
  }

  Future<void> _pickFromGallery(String type) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _files[type] = File(picked.path));
    }
  }

  void _showPickOptions(String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_labels[type]!, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: Text('Prendre une photo', style: GoogleFonts.dmSans()),
                onTap: () { Navigator.pop(context); _pick(type); },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: Text('Choisir depuis la galerie', style: GoogleFonts.dmSans()),
                onTap: () { Navigator.pop(context); _pickFromGallery(type); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadAll() async {
    if (_readyCount < _files.length) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Veuillez ajouter tous les documents', style: GoogleFonts.dmSans()),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() { _uploading = true; _uploadProgress = 0; _uploaded = {}; });
    int done = 0;

    for (final entry in _files.entries) {
      try {
        final bytes = await entry.value!.readAsBytes();
        final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        await DocumentsService.uploadDocument(type: entry.key, imageBase64: b64);
        done++;
        _uploaded[entry.key] = true;
        if (mounted) setState(() => _uploadProgress = done / _files.length);
      } on DioException catch (e) {
        _uploaded[entry.key] = false;
        final msg = e.response?.data?['message'] ?? 'Erreur upload ${_labels[entry.key]}';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg.toString(), style: GoogleFonts.dmSans()),
            backgroundColor: AppColors.error,
          ));
        }
      } catch (_) {
        _uploaded[entry.key] = false;
      }
    }

    if (mounted) {
      setState(() => _uploading = false);
      final allOk = _uploaded.values.every((v) => v);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(allOk ? '✅ Documents envoyés avec succès !' : '⚠️ Certains documents n\'ont pas pu être envoyés', style: GoogleFonts.dmSans()),
        backgroundColor: allOk ? AppColors.success : AppColors.warning,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: Text('Dossier Professionnel', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppColors.textDark),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de progression
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progression', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('$_readyCount/${_files.length} ajoutés', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textLight)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _uploading ? _uploadProgress : _readyProgress,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceGray,
                    valueColor: AlwaysStoppedAnimation(_uploading ? AppColors.success : AppColors.primary),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Documents d\'identité', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  for (final type in ['ID_CARD_FRONT', 'ID_CARD_BACK', 'SELFIE_WITH_ID'])
                    _DocCard(
                      label: _labels[type]!,
                      icon: _icons[type]!,
                      file: _files[type],
                      uploadStatus: _uploaded[type],
                      onTap: () => _showPickOptions(type),
                    ),
                  const SizedBox(height: 20),
                  Text('Documents du véhicule', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  for (final type in ['DRIVERS_LICENSE', 'VEHICLE_REGISTRATION', 'INSURANCE'])
                    _DocCard(
                      label: _labels[type]!,
                      icon: _icons[type]!,
                      file: _files[type],
                      uploadStatus: _uploaded[type],
                      onTap: () => _showPickOptions(type),
                    ),
                ],
              ),
            ),
          ),

          // Bouton soumettre
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, -4))],
            ),
            child: SafeArea(
              child: KoogweButton(
                label: _uploading
                    ? 'Envoi ${(_uploadProgress * 100).toInt()}%...'
                    : 'Envoyer les documents',
                onPressed: _uploading || _readyProgress < 1.0 ? null : _uploadAll,
                loading: _uploading,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Conseils pour les photos', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final tip in [
              '✅ Bonne luminosité',
              '✅ Photo nette et claire',
              '✅ Document entièrement visible',
              '✅ Sans reflets ni ombres',
              '✅ Informations lisibles',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(tip, style: GoogleFonts.dmSans(fontSize: 14)),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Compris', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final File? file;
  final bool? uploadStatus;
  final VoidCallback onTap;

  const _DocCard({
    required this.label,
    required this.icon,
    required this.file,
    required this.uploadStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool has = file != null;
    final Color borderColor = uploadStatus == true
        ? AppColors.success
        : uploadStatus == false
            ? AppColors.error
            : has ? AppColors.primary : AppColors.cardBorder;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: has ? 2 : 1),
      ),
      child: Row(
        children: [
          // Miniature si photo prise
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: file != null
                ? Image.file(file!, width: 52, height: 52, fit: BoxFit.cover)
                : Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: has ? AppColors.primaryLight : AppColors.surfaceGray,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: has ? AppColors.primary : AppColors.textHint, size: 26),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 3),
                Text(
                  uploadStatus == true ? '✅ Envoyé avec succès'
                      : uploadStatus == false ? '❌ Erreur d\'envoi'
                      : has ? 'Photo ajoutée — cliquez pour modifier'
                      : 'Appuyez pour prendre une photo',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: uploadStatus == true ? AppColors.success
                        : uploadStatus == false ? AppColors.error
                        : has ? AppColors.primary : AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
              child: Icon(has ? Icons.edit : Icons.camera_alt, color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
