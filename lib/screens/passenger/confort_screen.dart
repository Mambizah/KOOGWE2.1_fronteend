import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../widgets/koogwe_widgets.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import 'searching_screen.dart';

class ConfortScreen extends StatefulWidget {
  const ConfortScreen({super.key});

  @override
  State<ConfortScreen> createState() => _ConfortScreenState();
}

class _ConfortScreenState extends State<ConfortScreen> {
  int _selectedVehicle = 0;
  // ✅ Par défaut aucune option sélectionnée (le prix de base suffit)
  final Set<String> _selectedOptions = {};
  int _selectedPayment = 0;
  bool _loading = false;
  String? _error;

  // GPS
  double? _originLat, _originLng;
  double? _destLat, _destLng;
  String _originAddress = 'Obtention de la position...';
  String _destAddress = '';
  double _distanceKm = 0;
  bool _gpsLoading = true;

  final _destCtrl = TextEditingController();
  List<PlaceResult> _suggestions = [];
  Timer? _searchDebounce;

  final List<_Vehicle> _vehicles = const [
    _Vehicle(name: 'Moto', apiType: 'MOTO', basePrice: 500, eta: '3 min', seats: 1, desc: 'Rapide et économique'),
    _Vehicle(name: 'Taxi', apiType: 'ECO', basePrice: 800, eta: '5 min', seats: 4, desc: 'Confortable et abordable'),
    _Vehicle(name: 'Confort', apiType: 'CONFORT', basePrice: 1500, eta: '8 min', seats: 4, desc: 'Véhicule premium'),
  ];

  // ✅ Options avec prix individuels clairement définis
  final List<_ComfortOption> _options = const [
    _ComfortOption(id: 'Clim', icon: Icons.ac_unit, label: 'Clim', price: 500),
    _ComfortOption(id: 'WiFi', icon: Icons.wifi, label: 'Wi-Fi', price: 300),
    _ComfortOption(id: 'Musique', icon: Icons.music_note, label: 'Musique', price: 200),
    _ComfortOption(id: 'Silence', icon: Icons.volume_off, label: 'Silencieux', price: 0),
  ];

  @override
  void initState() {
    super.initState();
    _getGpsLocation();
  }

  @override
  void dispose() {
    _destCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _getGpsLocation() async {
    setState(() => _gpsLoading = true);
    final pos = await LocationService.getCurrentPosition();
    if (pos != null) {
      _originLat = pos.latitude;
      _originLng = pos.longitude;
      final address = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) setState(() {
        _originAddress = address;
        _gpsLoading = false;
      });
    } else {
      _originLat = LocationService.defaultLat;
      _originLng = LocationService.defaultLng;
      if (mounted) setState(() {
        _originAddress = 'Lomé, Togo (GPS indisponible)';
        _gpsLoading = false;
      });
    }
  }

  void _onDestChanged(String val) {
    _searchDebounce?.cancel();
    if (val.isEmpty) {
      setState(() { _suggestions = []; _destLat = null; _destLng = null; _distanceKm = 0; });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await LocationService.searchPlaces(val);
      if (mounted) setState(() => _suggestions = results);
    });
  }

  Future<void> _selectDestination(PlaceResult place) async {
    _destLat = place.lat;
    _destLng = place.lng;
    _destAddress = place.displayName;
    _destCtrl.text = place.displayName;
    _suggestions = [];

    if (_originLat != null && _originLng != null) {
      final dist = await LocationService.getDistanceKm(
        _originLat!, _originLng!, place.lat, place.lng,
      );
      if (mounted) setState(() => _distanceKm = dist);
    }
    if (mounted) setState(() {});
  }

  // ✅ FIX PRIX : 1km = 100 FCFA + options individuelles
  // Clim = +500 | WiFi = +300 | Musique = +200 | Silence = gratuit
  double get _totalPrice {
    final base = _vehicles[_selectedVehicle].basePrice.toDouble();
    final kmPrice = _distanceKm * 100; // ← 1 km = 100 FCFA
    double optionsPrice = 0;
    for (final opt in _options) {
      if (_selectedOptions.contains(opt.id)) {
        optionsPrice += opt.price;
      }
    }
    return (base + kmPrice + optionsPrice).roundToDouble();
  }

  bool get _canOrder => _originLat != null && _destLat != null && !_loading;

  Future<void> _confirmRide() async {
    if (!_canOrder) {
      setState(() => _error = 'Sélectionnez une destination');
      return;
    }

    // ✅ FIX DÉCONNEXION : Vérifier le token AVANT d'envoyer la requête
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Session expirée. Veuillez vous reconnecter.');
      return;
    }
    // S'assurer que le token est dans les headers Dio
    ApiService.setToken(token);

    setState(() { _loading = true; _error = null; });

    try {
      final ride = await RidesService.createRide(
        originLat: _originLat!,
        originLng: _originLng!,
        destLat: _destLat!,
        destLng: _destLng!,
        price: _totalPrice,
        vehicleType: _vehicles[_selectedVehicle].apiType,
        originAddress: _originAddress,
        destAddress: _destAddress,
      );

      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => SearchingScreen(
          rideId: ride['id'] as String,
          destination: _destAddress,
          price: _totalPrice,
        ),
      ));
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 0;
      if (statusCode == 401) {
        setState(() => _error = 'Session expirée. Veuillez vous reconnecter.');
      } else {
        final msg = e.response?.data?['message'] ?? 'Impossible de créer la course';
        setState(() => _error = '[$statusCode] ${msg.toString()}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
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
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.surfaceGray, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textDark),
          ),
        ),
        title: Text('Réserver une course', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Adresses ────────────────────────────────────────────
                  Container(
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
                            const Icon(Icons.my_location, color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _gpsLoading
                                  ? Row(children: [
                                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                                      const SizedBox(width: 8),
                                      Text('Localisation en cours...', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textLight)),
                                    ])
                                  : Text(_originAddress, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                            GestureDetector(
                              onTap: _getGpsLocation,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.gps_fixed, size: 16, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 10, top: 8, bottom: 8),
                          child: Divider(color: AppColors.divider),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppColors.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _destCtrl,
                                onChanged: _onDestChanged,
                                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textDark),
                                decoration: InputDecoration(
                                  hintText: 'Où allez-vous ?',
                                  hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textHint),
                                  border: InputBorder.none,
                                  filled: false,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_destLat != null)
                              const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ─── Suggestions ─────────────────────────────────────────
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10)],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined, color: AppColors.primary, size: 20),
                          title: Text(_suggestions[i].displayName, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textDark), maxLines: 2),
                          onTap: () => _selectDestination(_suggestions[i]),
                        ),
                      ),
                    ),
                  ],

                  // ✅ Distance + détail du prix
                  if (_distanceKm > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.straighten, size: 14, color: AppColors.success),
                          const SizedBox(width: 6),
                          Text(
                            '${_distanceKm.toStringAsFixed(1)} km × 100 FCFA = ${(_distanceKm * 100).toStringAsFixed(0)} FCFA',
                            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ─── Type de véhicule ─────────────────────────────────────
                  Text('TYPE DE VÉHICULE', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _vehicles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _VehicleCard(
                        vehicle: _vehicles[i],
                        selected: i == _selectedVehicle,
                        onTap: () => setState(() => _selectedVehicle = i),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Options de confort avec prix ─────────────────────────
                  Row(
                    children: [
                      Text('OPTIONS DE CONFORT', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight, letterSpacing: 1)),
                      const Spacer(),
                      if (_selectedOptions.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            '+${_options.where((o) => _selectedOptions.contains(o.id)).fold(0, (s, o) => s + o.price)} FCFA',
                            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.5,
                    children: _options.map((opt) => _ComfortCard(
                      option: opt,
                      selected: _selectedOptions.contains(opt.id),
                      onTap: () => setState(() {
                        if (_selectedOptions.contains(opt.id)) _selectedOptions.remove(opt.id);
                        else _selectedOptions.add(opt.id);
                      }),
                    )).toList(),
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
                ],
              ),
            ),
          ),

          // ─── Bottom bar ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, -4))],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _PaymentChip(icon: Icons.account_balance_wallet, label: 'Wallet', selected: _selectedPayment == 0, onTap: () => setState(() => _selectedPayment = 0))),
                      const SizedBox(width: 8),
                      Expanded(child: _PaymentChip(icon: Icons.payments_outlined, label: 'Espèces', selected: _selectedPayment == 1, onTap: () => setState(() => _selectedPayment = 1))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TOTAL ESTIMÉ', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textLight, letterSpacing: 0.8)),
                          Text('${_totalPrice.toStringAsFixed(0)} FCFA', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                          // ✅ Détail du prix en petit
                          if (_distanceKm > 0)
                            Text(
                              'Base ${_vehicles[_selectedVehicle].basePrice} + ${(_distanceKm * 100).toStringAsFixed(0)} km',
                              style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textLight),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: KoogweButton(
                          label: _destLat == null ? 'Choisir destination' : 'Confirmer ${_vehicles[_selectedVehicle].name}',
                          onPressed: _canOrder ? _confirmRide : null,
                          loading: _loading,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vehicle {
  final String name, apiType, desc, eta;
  final int basePrice;
  final int seats;
  const _Vehicle({required this.name, required this.apiType, required this.basePrice, required this.eta, required this.seats, required this.desc});
}

class _VehicleCard extends StatelessWidget {
  final _Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;
  const _VehicleCard({required this.vehicle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.primary : AppColors.cardBorder, width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 20)] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: selected ? AppColors.primaryLight : AppColors.surfaceGray, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.directions_car, color: selected ? AppColors.primary : AppColors.textLight, size: 18),
                ),
                if (selected) Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ],
            ),
            const Spacer(),
            Text(vehicle.name, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            Text(vehicle.eta, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textLight)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${vehicle.basePrice} FCFA', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                Row(children: [
                  const Icon(Icons.person, size: 12, color: AppColors.textLight),
                  Text(' ${vehicle.seats}', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textLight)),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComfortOption {
  final String id, label;
  final IconData icon;
  final int price; // ✅ Prix individuel de l'option
  const _ComfortOption({required this.id, required this.icon, required this.label, required this.price});
}

class _ComfortCard extends StatelessWidget {
  final _ComfortOption option;
  final bool selected;
  final VoidCallback onTap;
  const _ComfortCard({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.cardBorder, width: selected ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(option.icon, color: selected ? AppColors.primary : AppColors.textMedium, size: 24),
            const SizedBox(height: 4),
            Text(option.label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? AppColors.primary : AppColors.textMedium)),
            // ✅ Afficher le prix de l'option
            if (option.price > 0)
              Text(
                '+${option.price} FCFA',
                style: GoogleFonts.dmSans(fontSize: 11, color: selected ? AppColors.primary : AppColors.textLight),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PaymentChip({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surfaceGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? AppColors.primary : AppColors.textLight),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? AppColors.primary : AppColors.textLight), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}