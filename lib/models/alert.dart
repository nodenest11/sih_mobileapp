enum AlertType {
  geofencing,
  panic,
  safetyScore,
}

class Alert {
  final String id;
  final AlertType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  Alert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.data,
  });

  factory Alert.geofencingAlert(String zoneName) {
    return Alert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: AlertType.geofencing,
      title: 'Restricted Area Warning',
      message: '⚠️ You have entered a restricted/high-risk area: $zoneName',
      timestamp: DateTime.now(),
    );
  }

  factory Alert.panicAlert(double lat, double lon) {
    return Alert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: AlertType.panic,
      title: 'Panic Alert Sent',
      message: 'Emergency alert has been sent to authorities with your location',
      timestamp: DateTime.now(),
      data: {
        'lat': lat,
        'lon': lon,
      },
    );
  }

  factory Alert.safetyScoreAlert(int score) {
    String message;
    if (score < 60) {
      message = 'Your current location has a low safety score. Please be cautious.';
    } else if (score < 80) {
      message = 'Moderate safety area. Stay alert.';
    } else {
      message = 'You are in a safe area.';
    }

    return Alert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: AlertType.safetyScore,
      title: 'Safety Score Update',
      message: message,
      timestamp: DateTime.now(),
      data: {'score': score},
    );
  }
}

class SafetyScore {
  final int score;
  final String level;
  final DateTime lastUpdate;

  SafetyScore({
    required this.score,
    required this.level,
    required this.lastUpdate,
  });

  factory SafetyScore.fromJson(Map<String, dynamic> json) {
    int score = json['score']?.toInt() ?? 0;
    String level;
    
    if (score >= 80) {
      level = 'Safe';
    } else if (score >= 60) {
      level = 'Medium';
    } else {
      level = 'Risk';
    }

    return SafetyScore(
      score: score,
      level: level,
      lastUpdate: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'level': level,
      'lastUpdate': lastUpdate.toIso8601String(),
    };
  }
}