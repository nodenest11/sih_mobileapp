class Tourist {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final DateTime? registrationDate;

  Tourist({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.registrationDate,
  });

  factory Tourist.fromJson(Map<String, dynamic> json) {
    return Tourist(
      id: json['tourist_id'] ?? json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      registrationDate: json['registration_date'] != null
          ? DateTime.parse(json['registration_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tourist_id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'registration_date': registrationDate?.toIso8601String(),
    };
  }

  Tourist copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    DateTime? registrationDate,
  }) {
    return Tourist(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      registrationDate: registrationDate ?? this.registrationDate,
    );
  }
}