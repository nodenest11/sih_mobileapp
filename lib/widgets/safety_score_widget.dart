import 'package:flutter/material.dart';
import '../models/location.dart';

class SafetyScoreWidget extends StatelessWidget {
  final SafetyScore safetyScore;
  final VoidCallback? onRefresh;

  const SafetyScoreWidget({
    super.key,
    required this.safetyScore,
    this.onRefresh,
  });

  Color get _scoreColor {
    if (safetyScore.score >= 80) return Colors.green;
    if (safetyScore.score >= 60) return Colors.orange;
    return Colors.red;
  }

  String get _scoreText {
    if (safetyScore.score >= 80) return 'Safe';
    if (safetyScore.score >= 60) return 'Caution';
    return 'High Risk';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Safety Score',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              if (onRefresh != null)
                GestureDetector(
                  onTap: onRefresh,
                  child: Icon(
                    Icons.refresh_outlined,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Simplified Score Display
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _scoreColor,
                ),
                child: Center(
                  child: Text(
                    '${safetyScore.score}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Score Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _scoreText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _scoreColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      safetyScore.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}