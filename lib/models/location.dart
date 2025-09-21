import 'package:latlong2/latlong.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() {
    return {
      'lat': latitude,
      'lon': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
    };
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: json['lat']?.toDouble() ?? 0.0,
      longitude: json['lon']?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      accuracy: json['accuracy']?.toDouble(),
    );
  }
}

class HeatmapPoint {
  final double latitude;
  final double longitude;
  final double intensity;
  final String riskLevel;

  HeatmapPoint({
    required this.latitude,
    required this.longitude,
    required this.intensity,
    required this.riskLevel,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) {
    return HeatmapPoint(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      intensity: json['intensity']?.toDouble() ?? 0.0,
      riskLevel: json['risk_level'] ?? 'low',
    );
  }
}

class HeatmapResponse {
  final List<HeatmapPoint> points;
  final HeatmapMetadata metadata;

  HeatmapResponse({
    required this.points,
    required this.metadata,
  });

  factory HeatmapResponse.fromJson(Map<String, dynamic> json) {
    return HeatmapResponse(
      points: (json['points'] as List<dynamic>? ?? [])
          .map((point) => HeatmapPoint.fromJson(point))
          .toList(),
      metadata: HeatmapMetadata.fromJson(json['metadata'] ?? {}),
    );
  }
}

class HeatmapMetadata {
  final int totalPoints;
  final int timeWindowHours;
  final double gridSize;
  final bool includesAlerts;

  HeatmapMetadata({
    required this.totalPoints,
    required this.timeWindowHours,
    required this.gridSize,
    required this.includesAlerts,
  });

  factory HeatmapMetadata.fromJson(Map<String, dynamic> json) {
    return HeatmapMetadata(
      totalPoints: json['total_points'] ?? 0,
      timeWindowHours: json['time_window_hours'] ?? 24,
      gridSize: json['grid_size']?.toDouble() ?? 0.005,
      includesAlerts: json['includes_alerts'] ?? true,
    );
  }
}

class RestrictedZone {
  final String id;
  final String name;
  final List<LatLng> polygonCoordinates;

  RestrictedZone({
    required this.id,
    required this.name,
    required this.polygonCoordinates,
  });

  factory RestrictedZone.fromJson(Map<String, dynamic> json) {
    List<LatLng> coordinates = [];
    if (json['polygon_coordinates'] != null) {
      for (var coord in json['polygon_coordinates']) {
        coordinates.add(LatLng(
          coord['lat']?.toDouble() ?? 0.0,
          coord['lon']?.toDouble() ?? 0.0,
        ));
      }
    }

    return RestrictedZone(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      polygonCoordinates: coordinates,
    );
  }
}