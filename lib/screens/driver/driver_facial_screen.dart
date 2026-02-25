import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';
import '../../services/i18n_service.dart';
import 'vehicle_registration_screen.dart';

class DriverFacialScreen extends StatefulWidget {
  const DriverFacialScreen({super.key});
  @override
  State<DriverFacialScreen> createState() => _DriverFacialScreenState();
}

class _DriverFacialScreenState extends State<DriverFacialScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _cameraReady = false;
  bool _cameraError = false;

  int _currentStep = 0;
  bool _processing = false;
  bool _capturing = false;
  String? _error;
  final Map<String, String> _capturedImages = {};

  late AnimationController _pulseCtrl;
  late AnimationController _checkCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _checkAnim;

  final List<_FaceStep> _steps = const [
    _FaceStep(key: 'down', iconData: Icons.face, instructionKey: 'face_step1', subKey: 'face_step1_sub'),
    _FaceStep(key: 'left', iconData: Icons.arrow_back, instructionKey: 'face_step2', subKey: 'face_step2_sub'),
    _FaceStep(key: 'right', iconData: Icons.arrow_forward, instructionKey: 'face_step3', subKey: 'face_step3_sub'),
    _FaceStep(key: 'up', iconData: Icons.arrow_upward, instructionKey: 'face_step4', subKey: 'face_step4_sub'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _checkAnim = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) { setState(() => _cameraError = true); return; }
      final frontCamera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );
      _cameraController = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _cameraError = true);
    }
  }

  Future<void> _captureStep() async {
    if (_capturing || !_cameraReady || _cameraController == null) return;
    setState(() => _capturing = true);
    try {
      final file = await _cameraController!.takePicture();
      final bytes = await File(file.path).readAsBytes();
      final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      _capturedImages[_steps[_currentStep].key] = b64;
      _checkCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 600));
      if (_currentStep < _steps.length - 1) {
        setState(() { _currentStep++; _capturing = false; });
        _checkCtrl.reset();
      } else {
        setState(() => _capturing = false);
        await _submitVerification();
      }
    } catch (e) {
      setState(() => _capturing = false);
    }
  }

  Future<void> _submitVerification() async {
    setState(() { _processing = true; _error = null; });
    try {
      final result = await DocumentsService.verifyFace(
        downImage: _capturedImages['down'] ?? '',
        leftImage: _capturedImages['left'] ?? '',
        rightImage: _capturedImages['right'] ?? '',
        upImage: _capturedImages['up'] ?? '',
      );
      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.t('face_success'), style: GoogleFonts.dmSans(color: Colors.white)),
          backgroundColor: AppColors.success,
        ));
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VehicleRegistrationScreen()));
      } else {
        _showError(result['message'] ?? 'Vérification échouée.');
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 409) {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VehicleRegistrationScreen()));
        return;
      }
      _showError(e.response?.data?['message']?.toString() ?? 'Erreur de connexion');
    } catch (_) {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VehicleRegistrationScreen()));
    }
  }

  void _showError(String msg) => setState(() { _error = msg; _processing = false; });
  void _reset() => setState(() { _currentStep = 0; _capturedImages.clear(); _error = null; _processing = false; _capturing = false; });

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _checkCtrl.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live camera preview
          if (_cameraReady && _cameraController != null)
            Center(child: CameraPreview(_cameraController!))
          else if (_cameraError)
            _buildCameraError()
          else
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),

          // 2. Vignette sombre sur les bords
          if (_cameraReady)
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.7,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                ),
              ),
            ),

          // 3. Cadre ovale animé
          if (_cameraReady)
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
                child: Container(
                  width: 230,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(200),
                    border: Border.all(
                      color: _error != null ? AppColors.error : AppColors.primary,
                      width: 3,
                    ),
                  ),
                  child: _error == null
                      ? Center(child: Icon(_steps[_currentStep].iconData, size: 60, color: Colors.white.withOpacity(0.2)))
                      : null,
                ),
              ),
            ),

          // 4. Flash vert de succès
          AnimatedBuilder(
            animation: _checkAnim,
            builder: (_, __) => _checkAnim.value > 0
                ? Container(
                    color: AppColors.success.withOpacity(0.2 * _checkAnim.value),
                    child: Center(
                      child: Transform.scale(
                        scale: _checkAnim.value,
                        child: Container(
                          width: 80, height: 80,
                          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: Colors.white, size: 48),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(),
          ),

          // 5. Header
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 22),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
                          child: Text('Étape ${_currentStep + 1}/${_steps.length}',
                            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: List.generate(_steps.length, (i) {
                        final done = i < _currentStep;
                        final cur = i == _currentStep;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: 3,
                            decoration: BoxDecoration(
                              color: done ? AppColors.success : cur ? AppColors.primary : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 6. Instruction label
          if (_cameraReady && !_processing)
            Positioned(
              top: 145, left: 30, right: 30,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: (_error != null ? AppColors.error : AppColors.primary).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      _error ?? loc.t(_steps[_currentStep].instructionKey),
                      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (_error == null) ...[
                      const SizedBox(height: 4),
                      Text(
                        loc.t(_steps[_currentStep].subKey),
                        style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.85), fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // 7. Bottom bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_processing) ...[
                    const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                    const SizedBox(height: 12),
                    Text(loc.t('face_verifying'), style: GoogleFonts.dmSans(color: Colors.white, fontSize: 15)),
                  ] else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: KoogweButton(label: loc.t('face_retry'), onPressed: _reset, backgroundColor: AppColors.error),
                    )
                  else
                    GestureDetector(
                      onTap: (_cameraReady && !_capturing) ? _captureStep : null,
                      child: Container(
                        width: 76, height: 76,
                        decoration: BoxDecoration(
                          color: _capturing ? AppColors.primary.withOpacity(0.5) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 4),
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 20)],
                        ),
                        child: _capturing
                            ? const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3)
                            : const Icon(Icons.camera_alt, color: AppColors.primary, size: 34),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline, color: Colors.white54, size: 13),
                        const SizedBox(width: 6),
                        Text(loc.t('face_secure'), style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white54, size: 60),
            const SizedBox(height: 16),
            Text('Caméra indisponible', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Autorisez l\'accès à la caméra dans les paramètres.', style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            KoogweButton(label: 'Retour', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

class _FaceStep {
  final String key, instructionKey, subKey;
  final IconData iconData;
  const _FaceStep({required this.key, required this.iconData, required this.instructionKey, required this.subKey});
}