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

  // Cache color calculations for better performance
  Color get _scoreColor {
    final score = safetyScore.score;
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String get _scoreText {
    final score = safetyScore.score;
    if (score >= 80) return 'Safe';
    if (score >= 60) return 'Caution';
    return 'High Risk';
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor; // Calculate once
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildScoreSection(scoreColor),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
    );
  }

  Widget _buildScoreSection(Color scoreColor) {
    return Row(
      children: [
        _ScoreBadge(
          score: safetyScore.score,
          color: scoreColor,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ScoreDetails(
            scoreText: _scoreText,
            description: safetyScore.description,
            color: scoreColor,
          ),
        ),
      ],
    );
  }
}

// Separate widget for score badge to prevent unnecessary rebuilds
class _ScoreBadge extends StatelessWidget {
  final int score;
  final Color color;

  const _ScoreBadge({
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: Center(
        child: Text(
          '$score',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// Separate widget for score details
class _ScoreDetails extends StatelessWidget {
  final String scoreText;
  final String description;
  final Color color;

  const _ScoreDetails({
    required this.scoreText,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          scoreText,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}