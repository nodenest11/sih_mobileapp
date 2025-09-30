import 'dart:math' as math;
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
  final LatLng? center;
  final double? radiusMeters;
  final String? safetyRecommendation;

  RestrictedZone({
    required this.id,
    required this.name,
    required this.description,
    required this.polygonCoordinates,
    required this.type,
    this.warningMessage,
    this.center,
    this.radiusMeters,
    this.safetyRecommendation,
  });

  factory RestrictedZone.fromJson(Map<String, dynamic> json) {
    List<LatLng> coordinates = [];
    LatLng? centerPoint;
    double? radius;
    
    // Handle the actual API response format with center and radius
    if (json['center'] != null && json['center']['lat'] != null && json['center']['lon'] != null) {
      centerPoint = LatLng(
        json['center']['lat'].toDouble(),
        json['center']['lon'].toDouble(),
      );
      radius = json['radius_meters']?.toDouble() ?? 1000.0;
      
      // Generate circular polygon from center and radius
      coordinates = _generateCircularPolygon(centerPoint, radius!);
    } else if (json['polygon_coordinates'] != null) {
      // Handle polygon coordinates if provided
      for (var coord in json['polygon_coordinates']) {
        coordinates.add(LatLng(coord['lat'].toDouble(), coord['lon'].toDouble()));
      }
    } else {
      // Fallback: Generate mock polygon coordinates
      coordinates = _generateMockPolygon(json['id']?.toString() ?? '0');
    }

    return RestrictedZone(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Zone',
      description: json['description'] ?? '',
      polygonCoordinates: coordinates,
      type: _parseZoneType(json['type']),
      warningMessage: json['warning_message'] ?? json['safety_recommendation'],
      center: centerPoint,
      radiusMeters: radius,
      safetyRecommendation: json['safety_recommendation'],
    );
  }

  static ZoneType _parseZoneType(dynamic type) {
    if (type == null) return ZoneType.restricted;
    
    String typeStr = type.toString().toLowerCase();
    switch (typeStr) {
      case 'restricted':
        return ZoneType.restricted;
      case 'high_risk':
      case 'highrisk':
      case 'high-risk':
      case 'risky':
        return ZoneType.highRisk;
      case 'dangerous':
        return ZoneType.dangerous;
      case 'caution':
      case 'safe':
        return ZoneType.caution;
      default:
        return ZoneType.restricted;
    }
  }

  static List<LatLng> _generateCircularPolygon(LatLng center, double radiusMeters) {
    // Convert radius from meters to degrees (approximate)
    // 1 degree ≈ 111,000 meters at equator
    double radiusInDegrees = radiusMeters / 111000.0;
    
    List<LatLng> polygon = [];
    int numPoints = 16; // More points for smoother circle
    
    for (int i = 0; i < numPoints; i++) {
      double angle = (i * 360 / numPoints) * (math.pi / 180);
      double lat = center.latitude + radiusInDegrees * math.cos(angle);
      double lon = center.longitude + radiusInDegrees * math.sin(angle) / math.cos(center.latitude * (math.pi / 180));
      polygon.add(LatLng(lat, lon));
    }
    
    return polygon;
  }

  static List<LatLng> _generateMockPolygon(String zoneId) {
    // Generate mock coordinates based on zone ID for demonstration
    // In a real app, these would come from the API or be configured
    
    // Base coordinates around different areas (example locations)
    List<Map<String, double>> baseLocations = [
      {'lat': 28.6139, 'lon': 77.2090}, // Delhi
      {'lat': 19.0760, 'lon': 72.8777}, // Mumbai
      {'lat': 12.9716, 'lon': 77.5946}, // Bangalore
      {'lat': 13.0827, 'lon': 80.2707}, // Chennai
      {'lat': 22.5726, 'lon': 88.3639}, // Kolkata
      {'lat': 23.0225, 'lon': 72.5714}, // Ahmedabad
      {'lat': 18.5204, 'lon': 73.8567}, // Pune
      {'lat': 26.9124, 'lon': 75.7873}, // Jaipur
    ];
    
    int index = int.tryParse(zoneId) ?? 0;
    Map<String, double> baseLocation = baseLocations[index % baseLocations.length];
    
    double centerLat = baseLocation['lat']!;
    double centerLon = baseLocation['lon']!;
    
    // Create a circular polygon with radius of ~1km
    double radiusInDegrees = 0.009; // Approximately 1km
    List<LatLng> polygon = [];
    
    for (int i = 0; i < 8; i++) {
      double angle = (i * 45) * (math.pi / 180); // 45-degree increments
      double lat = centerLat + radiusInDegrees * math.cos(angle);
      double lon = centerLon + radiusInDegrees * math.sin(angle);
      polygon.add(LatLng(lat, lon));
    }
    
    return polygon;
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
  safe, // Added safe zone type to match API response
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