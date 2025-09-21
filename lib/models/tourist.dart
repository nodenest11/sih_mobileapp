class Tourist {
  final String id;
  final String name;
  final double? currentLat;
  final double? currentLon;
  final DateTime? lastUpdate;

  Tourist({
    required this.id,
    required this.name,
    this.currentLat,
    this.currentLon,
    this.lastUpdate,
  });

  Tourist copyWith({
    String? id,
    String? name,
    double? currentLat,
    double? currentLon,
    DateTime? lastUpdate,
  }) {
    return Tourist(
      id: id ?? this.id,
      name: name ?? this.name,
      currentLat: currentLat ?? this.currentLat,
      currentLon: currentLon ?? this.currentLon,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tourist_id': id,
      'name': name,
      'lat': currentLat,
      'lon': currentLon,
      'timestamp': lastUpdate?.toIso8601String(),
    };
  }

  factory Tourist.fromJson(Map<String, dynamic> json) {
    return Tourist(
      id: json['tourist_id'] ?? '',
      name: json['name'] ?? '',
      currentLat: json['lat']?.toDouble(),
      currentLon: json['lon']?.toDouble(),
      lastUpdate: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : null,
    );
  }
}