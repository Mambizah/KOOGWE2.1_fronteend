import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';

class SocketService {
  static IO.Socket? _socket;
  static bool _isConnected = false;
  static Timer? _reconnectTimer;
  static Timer? _heartbeatTimer;
  static int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _heartbeatInterval = Duration(seconds: 25);

  // Callbacks à restaurer après reconnexion
  static final Map<String, Function> _callbacks = {};

  // ─── Connexion avec token JWT réel ───────────────────────────────────────
  static Future<void> connect() async {
    if (_isConnected && _socket != null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    if (token.isEmpty) {
      print('⚠️ Socket: pas de token, connexion annulée');
      return;
    }

    _createSocket(token);
  }

  static void _createSocket(String token) {
    _socket?.dispose();

    _socket = IO.io(ApiService.baseUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .setExtraHeaders({'Authorization': 'Bearer $token'})
      .setAuth({'token': token})
      .setTimeout(15000)
      .setReconnectionDelay(2000)
      .build());

    _socket!.connect();

    _socket!.onConnect((_) {
      _isConnected = true;
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      print('🔌 Socket connecté');
      _startHeartbeat();
      // Restaurer les listeners après reconnexion
      _restoreCallbacks();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _heartbeatTimer?.cancel();
      print('🔌 Socket déconnecté - tentative de reconnexion...');
      _scheduleReconnect();
    });

    _socket!.onConnectError((data) {
      _isConnected = false;
      print('❌ Erreur connexion socket: $data');
      _scheduleReconnect();
    });

    _socket!.on('connect_error', (data) {
      print('❌ connect_error: $data');
    });
  }

  // ─── Auto-reconnexion avec backoff exponentiel ────────────────────────────
  static void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('❌ Socket: nombre max de reconnexions atteint');
      return;
    }

    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (2 << _reconnectAttempts).clamp(2, 60));
    _reconnectAttempts++;

    print('🔄 Reconnexion dans ${delay.inSeconds}s (tentative $_reconnectAttempts)');

    _reconnectTimer = Timer(delay, () async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        _createSocket(token);
      }
    });
  }

  // ─── Heartbeat pour maintenir la connexion active ────────────────────────
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_isConnected) {
        _socket?.emit('heartbeat', {'timestamp': DateTime.now().millisecondsSinceEpoch});
      }
    });
  }

  // ─── Restaurer les callbacks après reconnexion ───────────────────────────
  static void _restoreCallbacks() {
    _callbacks.forEach((event, cb) {
      _socket?.on(event, (data) {
        if (data is Map) {
          cb(Map<String, dynamic>.from(data));
        } else {
          cb(data);
        }
      });
    });
  }

  static void disconnect() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _reconnectAttempts = _maxReconnectAttempts; // Stop auto-reconnect
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _callbacks.clear();
    print('🔌 Socket déconnecté manuellement');
  }

  // ─── Réinitialiser les tentatives de reconnexion ─────────────────────────
  static void resetReconnect() {
    _reconnectAttempts = 0;
  }

  // ─── Emissions ───────────────────────────────────────────────────────────
  static void joinRide(String rideId) {
    _socket?.emit('join_ride', {'rideId': rideId});
  }

  static void leaveRide(String rideId) {
    _socket?.emit('leave_ride', {'rideId': rideId});
  }

  static void goOnline(String driverId) {
    _socket?.emit('driver_online', {'driverId': driverId});
  }

  static void goOffline(String driverId) {
    _socket?.emit('driver_offline', {'driverId': driverId});
  }

  static void acceptRide({required String rideId, required String driverId}) {
    _socket?.emit('accept_ride', {'rideId': rideId, 'driverId': driverId});
  }

  static void driverArrived(String rideId) {
    _socket?.emit('driver_arrived', {'rideId': rideId});
  }

  static void startTrip(String rideId) {
    _socket?.emit('start_trip', {'rideId': rideId});
  }

  static void finishTrip(String rideId) {
    // ✅ Sécurité : prix toujours contrôlé côté serveur, pas envoyé par le client
    _socket?.emit('finish_trip', {'rideId': rideId});
  }

  static void updateLocation({
    required String rideId,
    required double lat,
    required double lng,
  }) {
    _socket?.emit('update_location', {
      'rideId': rideId,
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static void sendChatMessage({
    required String rideId,
    required String senderId,
    required String message,
  }) {
    _socket?.emit('chat_message', {
      'rideId': rideId,
      'senderId': senderId,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ─── Listeners ───────────────────────────────────────────────────────────
  static void onNewRide(Function(Map<String, dynamic>) callback) {
    _callbacks['new_ride'] = callback;
    _socket?.on('new_ride', (data) => callback(Map<String, dynamic>.from(data)));
  }

  static void onRideStatus(String rideId, Function(Map<String, dynamic>) callback) {
    final event = 'ride_status_$rideId';
    _callbacks[event] = callback;
    _socket?.on(event, (data) => callback(Map<String, dynamic>.from(data)));
  }

  static void onDriverLocation(String rideId, Function(double lat, double lng) callback) {
    final event = 'driver_location_$rideId';
    _callbacks[event] = (data) {
      callback((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble());
    };
    _socket?.on(event, (data) {
      callback((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble());
    });
  }

  static void onChatMessage(String rideId, Function(Map<String, dynamic>) callback) {
    final event = 'chat_$rideId';
    _callbacks[event] = callback;
    _socket?.on(event, (data) => callback(Map<String, dynamic>.from(data)));
  }

  static void onTripFinished(Function(Map<String, dynamic>) callback) {
    _callbacks['trip_finished'] = callback;
    _socket?.on('trip_finished', (data) => callback(Map<String, dynamic>.from(data)));
  }

  static void off(String event) {
    _callbacks.remove(event);
    _socket?.off(event);
  }

  static bool get isConnected => _isConnected;
}
