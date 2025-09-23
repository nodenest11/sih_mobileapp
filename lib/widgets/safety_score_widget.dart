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

  IconData get _scoreIcon {
    if (safetyScore.score >= 80) return Icons.security;
    if (safetyScore.score >= 60) return Icons.warning;
    return Icons.dangerous;
  }

  String get _scoreText {
    if (safetyScore.score >= 80) return 'Safe';
    if (safetyScore.score >= 60) return 'Caution';
    return 'High Risk';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Safety Score',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Score Circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _scoreColor.withOpacity(0.1),
                    border: Border.all(
                      color: _scoreColor,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${safetyScore.score}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _scoreColor,
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
                      Row(
                        children: [
                          Icon(
                            _scoreIcon,
                            color: _scoreColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _scoreText,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _scoreColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        safetyScore.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Updated: ${_formatTime(safetyScore.updatedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Score Bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[200],
              ),
              child: FractionallySizedBox(
                widthFactor: safetyScore.score / 100,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _scoreColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Score Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  '100',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}