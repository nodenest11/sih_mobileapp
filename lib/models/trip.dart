class Trip {
  final int id;
  final String destination;
  final String? itinerary;
  final String status; // 'active', 'completed', 'cancelled'
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final double? durationHours;

  Trip({
    required this.id,
    required this.destination,
    this.itinerary,
    required this.status,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    this.durationHours,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] ?? json['trip_id'] ?? 0,
      destination: json['destination'] ?? '',
      itinerary: json['itinerary'],
      status: json['status'] ?? 'active',
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      durationHours: json['duration_hours']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination': destination,
      'itinerary': itinerary,
      'status': status,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'duration_hours': durationHours,
    };
  }

  /// Generate API payload for starting a trip
  Map<String, dynamic> toStartTripJson() {
    return {
      'destination': destination,
      if (itinerary != null) 'itinerary': itinerary,
    };
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  Duration? get duration {
    if (endDate != null) {
      return endDate!.difference(startDate);
    }
    return null;
  }

  String get formattedDuration {
    final dur = duration;
    if (dur == null) return 'Ongoing';
    
    if (dur.inDays > 0) {
      return '${dur.inDays} day${dur.inDays > 1 ? 's' : ''}';
    } else if (dur.inHours > 0) {
      return '${dur.inHours} hour${dur.inHours > 1 ? 's' : ''}';
    } else {
      return '${dur.inMinutes} minute${dur.inMinutes > 1 ? 's' : ''}';
    }
  }
}