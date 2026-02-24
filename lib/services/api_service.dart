import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _railwayUrl = 'https://web-production-5edc5.up.railway.app';

  static String get baseUrl {
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return _railwayUrl;
  }

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  /// ✅ FIX BUG #1 : Callback appelé quand 401 → navigation vers login
  static VoidCallback? _onUnauthorized;
  static void setOnUnauthorized(VoidCallback cb) => _onUnauthorized = cb;

  static bool _initialized = false;

  static Future<void> init() async {
    // ✅ FIX BUG #1 : Guard pour éviter double initialisation (interceptors doublés)
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Vider le token ET rediriger vers login
          await AuthService.logout();
          _onUnauthorized?.call();
        }
        handler.next(e);
      },
      onRequest: (options, handler) {
        if (kDebugMode) print('📡 ${options.method} ${options.uri}');
        handler.next(options);
      },
    ));
  }

  static void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  static void clearToken() {
    _dio.options.headers.remove('Authorization');
  }

  static Dio get dio => _dio;
}

// ─── AUTH SERVICE ─────────────────────────────────────────────────────────────
class AuthService {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await ApiService.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = res.data as Map<String, dynamic>;
    await saveUserFromMap(data['user'] as Map<String, dynamic>);
    await _saveToken(data['access_token'] as String);
    return data;
  }

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    final res = await ApiService.dio.post('/auth/signup', data: {
      'email': email,
      'password': password,
      'name': name,
      'phone': phone,
      'role': role,
    });
    final data = res.data as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_email', email);
    await prefs.setString('pending_name', name);
    await prefs.setString('pending_role', role);
    return data;
  }

  static Future<void> saveUserFromMap(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user['id']?.toString() ?? '');
    await prefs.setString('user_name', user['name']?.toString() ?? '');
    await prefs.setString('user_email', user['email']?.toString() ?? '');
    await prefs.setString('user_role', user['role']?.toString() ?? '');
    if (user['phone'] != null) {
      await prefs.setString('user_phone', user['phone'].toString());
    }
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    ApiService.setToken(token);
  }

  static Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    final res = await ApiService.dio.post('/auth/verify', data: {
      'email': email,
      'code': code,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['access_token'] != null) {
      await _saveToken(data['access_token'] as String);
    }
    if (data['user'] != null) {
      await saveUserFromMap(data['user'] as Map<String, dynamic>);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('pending_name') ?? '';
      final role = prefs.getString('pending_role') ?? '';
      if (name.isNotEmpty) await prefs.setString('user_name', name);
      if (role.isNotEmpty) await prefs.setString('user_role', role);
    }
    return data;
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final res = await ApiService.dio.get('/users/me');
    final data = res.data as Map<String, dynamic>;
    await saveUserFromMap(data);
    return data;
  }

  static Future<void> updateProfile({String? name, String? phone}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    await ApiService.dio.patch('/users/me', data: body);
    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString('user_name', name);
    if (phone != null) await prefs.setString('user_phone', phone);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ApiService.clearToken();
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  static Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_phone');
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') != null;
  }
}

// ─── RIDES SERVICE ─────────────────────────────────────────────────────────────
class RidesService {
  static Future<Map<String, dynamic>> createRide({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required double price,
    required String vehicleType,
    String? originAddress,
    String? destAddress,
  }) async {
    final res = await ApiService.dio.post('/rides', data: {
      'originLat': originLat,
      'originLng': originLng,
      'destLat': destLat,
      'destLng': destLng,
      'price': price,
      'vehicleType': vehicleType,
      if (originAddress != null) 'originAddress': originAddress,
      if (destAddress != null) 'destAddress': destAddress,
    });
    return res.data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getHistory() async {
    final res = await ApiService.dio.get('/rides/history');
    return res.data as List;
  }

  static Future<Map<String, dynamic>> getDriverStats() async {
    final res = await ApiService.dio.get('/rides/driver/stats');
    return res.data as Map<String, dynamic>;
  }
}

// ─── WALLET SERVICE ────────────────────────────────────────────────────────────
class WalletService {
  static Future<double> getBalance(String userId) async {
    final res = await ApiService.dio.get('/wallet/balance/$userId');
    return (res.data['balance'] as num).toDouble();
  }

  static Future<List<dynamic>> getTransactions(String userId) async {
    final res = await ApiService.dio.get('/wallet/transactions/$userId');
    return res.data as List;
  }

  static Future<Map<String, dynamic>> rechargeWithCard({
    required String userId,
    required double amount,
    required String paymentMethodId,
  }) async {
    final res = await ApiService.dio.post('/wallet/recharge-card', data: {
      'userId': userId,
      'amount': amount,
      'paymentMethodId': paymentMethodId,
    });
    return res.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> requestWithdrawal({
    required String userId,
    required double amount,
  }) async {
    final res = await ApiService.dio.post('/wallet/request-withdrawal', data: {
      'userId': userId,
      'amount': amount,
    });
    return res.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> payRide({
    required String userId,
    required String rideId,
    required double amount,
  }) async {
    final res = await ApiService.dio.post('/wallet/pay-ride', data: {
      'userId': userId,
      'rideId': rideId,
      'amount': amount,
    });
    return res.data as Map<String, dynamic>;
  }
}

// ─── USERS SERVICE ────────────────────────────────────────────────────────────
class UsersService {
  static Future<Map<String, dynamic>> getDriverStatus() async {
    final res = await ApiService.dio.get('/users/driver-status');
    return res.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateVehicle({
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleColor,
    String? licensePlate,
  }) async {
    final res = await ApiService.dio.patch('/users/update-vehicle', data: {
      if (vehicleMake != null) 'vehicleMake': vehicleMake,
      if (vehicleModel != null) 'vehicleModel': vehicleModel,
      if (vehicleColor != null) 'vehicleColor': vehicleColor,
      if (licensePlate != null) 'licensePlate': licensePlate,
    });
    return res.data as Map<String, dynamic>;
  }
}

// ─── DOCUMENTS SERVICE ────────────────────────────────────────────────────────
class DocumentsService {
  static Future<Map<String, dynamic>> uploadDocument({
    required String type,
    required String imageBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final res = await ApiService.dio.post('/documents/upload', data: {
      'userId': userId,
      'type': type,
      'imageBase64': imageBase64,
    });
    return res.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> verifyFace({
    required String downImage,
    required String leftImage,
    required String rightImage,
    required String upImage,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final res = await ApiService.dio.post('/face-verification/verify-movements', data: {
      'userId': userId,
      'downImage': downImage,
      'leftImage': leftImage,
      'rightImage': rightImage,
      'upImage': upImage,
    });
    return res.data as Map<String, dynamic>;
  }
}
