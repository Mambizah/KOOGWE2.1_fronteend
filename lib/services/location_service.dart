import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  /// Pas de position par défaut — le GPS détermine la position
  static const double defaultLat = 0.0;
  static const double defaultLng = 0.0;

  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final res = await http.get(url, headers: {
        'User-Agent': 'KoogweApp/1.0 (contact@koogwe.com)',
        'Accept-Language': 'fr',
      });
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final parts = <String>[];
          if (address['road'] != null) parts.add(address['road']);
          if (address['suburb'] != null) parts.add(address['suburb']);
          if (address['city'] != null) parts.add(address['city']);
          if (parts.isNotEmpty) return parts.join(', ');
          return data['display_name'] ?? 'Position actuelle';
        }
      }
    } catch (_) {}
    return 'Position actuelle';
  }

  /// Recherche d'adresses — adaptée à la position GPS de l'utilisateur
  static Future<List<PlaceResult>> searchPlaces(String query, {double? nearLat, double? nearLng}) async {
    if (query.trim().length < 2) return [];
    try {
      final encoded = Uri.encodeComponent(query);
      
      // Si on connaît la position de l'utilisateur → cherche près de lui (viewbox)
      String urlStr;
      if (nearLat != null && nearLng != null) {
        // Zone de 2 degrés autour de l'utilisateur
        final latMin = nearLat - 1.0;
        final latMax = nearLat + 1.0;
        final lngMin = nearLng - 1.0;
        final lngMax = nearLng + 1.0;
        urlStr = 'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&addressdetails=1&limit=5&viewbox=$lngMin,$latMin,$lngMax,$latMax&bounded=0';
      } else {
        // Recherche globale sans restriction
        urlStr = 'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&addressdetails=1&limit=5';
      }

      final url = Uri.parse(urlStr);
      final res = await http.get(url, headers: {
        'User-Agent': 'KoogweApp/1.0 (contact@koogwe.com)',
        'Accept-Language': 'fr',
      });
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        if (data.isNotEmpty) {
          return data.map((item) => PlaceResult(
            displayName: _shortenAddress(item['display_name'] ?? ''),
            lat: double.tryParse(item['lat'].toString()) ?? 0,
            lng: double.tryParse(item['lon'].toString()) ?? 0,
          )).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<double> getDistanceKm(
    double fromLat, double fromLng,
    double toLat, double toLng,
  ) async {
    try {
      final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/$fromLng,$fromLat;$toLng,$toLat?overview=false',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final meters = data['routes'][0]['distance'] as num;
          return meters / 1000.0;
        }
      }
    } catch (_) {}
    return _haversineKm(fromLat, fromLng, toLat, toLng);
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = (dLat / 2) * (dLat / 2) +
        _deg2rad(lat1) * _deg2rad(lat2) * (dLon / 2) * (dLon / 2);
    final c = 2 * (a < 1 ? a : 1);
    return R * c;
  }

  static double _deg2rad(double deg) => deg * 3.14159265358979323846 / 180;

  static String _shortenAddress(String full) {
    final parts = full.split(',');
    if (parts.length > 3) return parts.take(3).join(',').trim();
    return full;
  }
}

class PlaceResult {
  final String displayName;
  final double lat;
  final double lng;
  PlaceResult({required this.displayName, required this.lat, required this.lng});
}