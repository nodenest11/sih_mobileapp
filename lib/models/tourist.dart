class Tourist {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final int safetyScore;
  final DateTime? lastSeen;
  final String? emergencyContact;
  final String? emergencyPhone;
  final DateTime? registrationDate;

  Tourist({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.safetyScore = 50,
    this.lastSeen,
    this.emergencyContact,
    this.emergencyPhone,
    this.registrationDate,
  });

  factory Tourist.fromJson(Map<String, dynamic> json) {
    return Tourist(
      id: json['user_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      safetyScore: json['safety_score'] ?? 50,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'])
          : null,
      emergencyContact: json['emergency_contact'],
      emergencyPhone: json['emergency_phone'],
      registrationDate: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'safety_score': safetyScore,
      'last_seen': lastSeen?.toIso8601String(),
      'emergency_contact': emergencyContact,
      'emergency_phone': emergencyPhone,
      'created_at': registrationDate?.toIso8601String(),
    };
  }

  Tourist copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    int? safetyScore,
    DateTime? lastSeen,
    String? emergencyContact,
    String? emergencyPhone,
    DateTime? registrationDate,
  }) {
    return Tourist(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      safetyScore: safetyScore ?? this.safetyScore,
      lastSeen: lastSeen ?? this.lastSeen,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      registrationDate: registrationDate ?? this.registrationDate,
    );
  }

  String get safetyLevel {
    if (safetyScore >= 80) return 'Safe';
    if (safetyScore >= 60) return 'Medium';
    return 'Risk';
  }

  String get safetyDescription {
    if (safetyScore >= 80) return 'You are in a safe area';
    if (safetyScore >= 60) return 'Moderate safety level';
    return 'High risk area - be cautious';
  }
}