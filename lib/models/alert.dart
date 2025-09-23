import 'package:latlong2/latlong.dart';

class Alert {
  final String id;
  final String touristId;
  final AlertType type;
  final String title;
  final String message;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;
  final bool isRead;
  final AlertSeverity severity;

  Alert({
    required this.id,
    required this.touristId,
    required this.type,
    required this.title,
    required this.message,
    this.latitude,
    this.longitude,
    required this.timestamp,
    this.isRead = false,
    this.severity = AlertSeverity.medium,
  });

  LatLng? get location {
    if (latitude != null && longitude != null) {
      return LatLng(latitude!, longitude!);
    }
    return null;
  }

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'],
      touristId: json['tourist_id'],
      type: AlertType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AlertType.general,
      ),
      title: json['title'],
      message: json['message'],
      latitude: json['lat']?.toDouble(),
      longitude: json['lon']?.toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['is_read'] ?? false,
      severity: AlertSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => AlertSeverity.medium,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tourist_id': touristId,
      'type': type.name,
      'title': title,
      'message': message,
      'lat': latitude,
      'lon': longitude,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'severity': severity.name,
    };
  }

  Alert copyWith({
    String? id,
    String? touristId,
    AlertType? type,
    String? title,
    String? message,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    bool? isRead,
    AlertSeverity? severity,
  }) {
    return Alert(
      id: id ?? this.id,
      touristId: touristId ?? this.touristId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      severity: severity ?? this.severity,
    );
  }
}

enum AlertType {
  panic,
  geoFence,
  safety,
  general,
  emergency,
}

enum AlertSeverity {
  low,
  medium,
  high,
  critical,
}

class RestrictedZone {
  final String id;
  final String name;
  final String description;
  final List<LatLng> polygonCoordinates;
  final ZoneType type;
  final String? warningMessage;

  RestrictedZone({
    required this.id,
    required this.name,
    required this.description,
    required this.polygonCoordinates,
    required this.type,
    this.warningMessage,
  });

  factory RestrictedZone.fromJson(Map<String, dynamic> json) {
    List<LatLng> coordinates = [];
    if (json['polygon_coordinates'] != null) {
      for (var coord in json['polygon_coordinates']) {
        coordinates.add(LatLng(coord['lat'].toDouble(), coord['lon'].toDouble()));
      }
    }

    return RestrictedZone(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      polygonCoordinates: coordinates,
      type: ZoneType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ZoneType.restricted,
      ),
      warningMessage: json['warning_message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'polygon_coordinates': polygonCoordinates
          .map((coord) => {'lat': coord.latitude, 'lon': coord.longitude})
          .toList(),
      'type': type.name,
      'warning_message': warningMessage,
    };
  }
}

enum ZoneType {
  restricted,
  highRisk,
  dangerous,
  caution,
}

class PanicAlert {
  final String touristId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? message;
  final bool isActive;

  PanicAlert({
    required this.touristId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.message,
    this.isActive = true,
  });

  LatLng get location => LatLng(latitude, longitude);

  factory PanicAlert.fromJson(Map<String, dynamic> json) {
    return PanicAlert(
      touristId: json['tourist_id'],
      latitude: json['lat'].toDouble(),
      longitude: json['lon'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      message: json['message'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tourist_id': touristId,
      'lat': latitude,
      'lon': longitude,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'is_active': isActive,
    };
  }
}