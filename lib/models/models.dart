// ─── MODÈLE UTILISATEUR ──────────────────────────────────────────────────────
class UserModel {
  final String id;
  final String email;
  final String? name;
  final String role;
  final String? phone;

  const UserModel({
    required this.id,
    required this.email,
    this.name,
    required this.role,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    email: json['email'],
    name: json['name'],
    role: json['role'],
    phone: json['phone'],
  );
}

// ─── MODÈLE COURSE ──────────────────────────────────────────────────────────
class RideModel {
  final String id;
  final String status;
  final double price;
  final String vehicleType;
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final String? originAddress;
  final String? destAddress;
  final DateTime requestedAt;
  final String? driverName;
  final String? driverPhone;
  final String? vehicleInfo;
  final String? licensePlate;
  final String? passengerName;

  const RideModel({
    required this.id,
    required this.status,
    required this.price,
    required this.vehicleType,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    this.originAddress,
    this.destAddress,
    required this.requestedAt,
    this.driverName,
    this.driverPhone,
    this.vehicleInfo,
    this.licensePlate,
    this.passengerName,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) => RideModel(
    id: json['id'],
    status: json['status'],
    price: (json['price'] as num).toDouble(),
    vehicleType: json['vehicleType'] ?? 'MOTO',
    originLat: (json['originLat'] as num).toDouble(),
    originLng: (json['originLng'] as num).toDouble(),
    destLat: (json['destLat'] as num).toDouble(),
    destLng: (json['destLng'] as num).toDouble(),
    originAddress: json['originAddress'],
    destAddress: json['destAddress'],
    requestedAt: DateTime.parse(json['requestedAt']),
    driverName: json['driver']?['name'],
    driverPhone: json['driver']?['phone'],
    passengerName: json['passenger']?['name'],
  );

  String get formattedDate {
    final d = requestedAt;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String get formattedPrice => '${price.toStringAsFixed(0)} FCFA';

  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isActive => ['REQUESTED', 'ACCEPTED', 'ARRIVED', 'IN_PROGRESS'].contains(status);
}

// ─── MODÈLE TRANSACTION ──────────────────────────────────────────────────────
class TransactionModel {
  final String id;
  final String type;
  final double amount;
  final String status;
  final DateTime createdAt;
  final String? rideId;
  final String? paymentMethod;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.rideId,
    this.paymentMethod,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel(
    id: json['id'],
    type: json['type'],
    amount: (json['amount'] as num).toDouble(),
    status: json['status'],
    createdAt: DateTime.parse(json['createdAt']),
    rideId: json['rideId'],
    paymentMethod: json['paymentMethod'],
  );

  bool get isPositive => amount > 0;
  String get formattedAmount => '${amount > 0 ? '+' : ''}${amount.toStringAsFixed(0)} FCFA';

  String get label {
    switch (type) {
      case 'RECHARGE': return 'Recharge';
      case 'PAYMENT': return 'Course payée';
      case 'REFUND': return 'Remboursement';
      case 'WITHDRAWAL': return 'Virement';
      case 'COMMISSION': return 'Commission';
      default: return type;
    }
  }
}

// ─── MODÈLE DRIVER STATS ────────────────────────────────────────────────────
class DriverStats {
  final double dailyEarnings;
  final double totalEarnings;
  final int todayRides;
  final int totalRides;

  const DriverStats({
    required this.dailyEarnings,
    required this.totalEarnings,
    required this.todayRides,
    required this.totalRides,
  });

  factory DriverStats.fromJson(Map<String, dynamic> json) => DriverStats(
    dailyEarnings: (json['dailyEarnings'] as num).toDouble(),
    totalEarnings: (json['totalEarnings'] as num).toDouble(),
    todayRides: json['todayRides'],
    totalRides: json['totalRides'],
  );
}

// ─── MODÈLE STATUT CHAUFFEUR ─────────────────────────────────────────────────
class DriverStatus {
  final bool faceVerified;
  final bool documentsUploaded;
  final bool adminApproved;
  final String currentStep;

  const DriverStatus({
    required this.faceVerified,
    required this.documentsUploaded,
    required this.adminApproved,
    required this.currentStep,
  });

  factory DriverStatus.fromJson(Map<String, dynamic> json) => DriverStatus(
    faceVerified: json['faceVerified'] ?? false,
    documentsUploaded: json['documentsUploaded'] ?? false,
    adminApproved: json['adminApproved'] ?? false,
    currentStep: json['currentStep'] ?? 'face_verification',
  );

  bool get isActive => currentStep == 'active';
}
