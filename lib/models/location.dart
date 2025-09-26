import 'package:latlong2/latlong.dart';

class LocationData {
  final String touristId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;

  LocationData({
    required this.touristId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      touristId: json['tourist_id'],
      latitude: json['lat'].toDouble(),
      longitude: json['lon'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      accuracy: json['accuracy']?.toDouble(),
      altitude: json['altitude']?.toDouble(),
      speed: json['speed']?.toDouble(),
      heading: json['heading']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tourist_id': touristId,
      'lat': latitude,
      'lon': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
    };
  }
}

class SafetyScore {
  final String touristId;
  final int score;
  final String level;
  final String description;
  final DateTime updatedAt;

  SafetyScore({
    required this.touristId,
    required this.score,
    required this.level,
    required this.description,
    required this.updatedAt,
  });

  String get levelColor {
    if (score >= 80) return 'green';
    if (score >= 60) return 'yellow';
    return 'red';
  }

  factory SafetyScore.fromJson(Map<String, dynamic> json) {
    return SafetyScore(
      touristId: json['tourist_id'],
      score: json['score'],
      level: json['level'] ?? _getLevelFromScore(json['score']),
      description: json['description'] ?? '',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  static String _getLevelFromScore(int score) {
    if (score >= 80) return 'Safe';
    if (score >= 60) return 'Medium';
    return 'Risk';
  }

  Map<String, dynamic> toJson() {
    return {
      'tourist_id': touristId,
      'score': score,
      'level': level,
      'description': description,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}