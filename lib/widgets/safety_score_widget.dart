import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/alert.dart';

class SafetyScoreWidget extends StatefulWidget {
  final String touristId;

  const SafetyScoreWidget({super.key, required this.touristId});

  @override
  State<SafetyScoreWidget> createState() => _SafetyScoreWidgetState();
}

class _SafetyScoreWidgetState extends State<SafetyScoreWidget> {
  final ApiService _apiService = ApiService();
  SafetyScore? _safetyScore;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSafetyScore();
    // Refresh safety score every 30 seconds
    _startPeriodicUpdate();
  }

  void _startPeriodicUpdate() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadSafetyScore();
        _startPeriodicUpdate();
      }
    });
  }

  Future<void> _loadSafetyScore() async {
    try {
      SafetyScore score = await _apiService.getSafetyScore(widget.touristId);
      if (mounted) {
        setState(() {
          _safetyScore = score;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading safety score: $e');
      if (mounted) {
        setState(() {
          _safetyScore = null; // Clear any previous score on error
          _isLoading = false;
        });
        // Don't show snackbar for safety score errors to avoid spam
        // The widget will show an error icon instead
      }
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) {
      return Colors.green;
    } else if (score >= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  IconData _getScoreIcon(int score) {
    if (score >= 80) {
      return Icons.security;
    } else if (score >= 60) {
      return Icons.warning;
    } else {
      return Icons.dangerous;
    }
  }

  String _getScoreText(int score) {
    if (score >= 80) {
      return 'Safe';
    } else if (score >= 60) {
      return 'Medium';
    } else {
      return 'Risk';
    }
  }

  void _showScoreDetails() {
    if (_safetyScore == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                _getScoreIcon(_safetyScore!.score),
                color: _getScoreColor(_safetyScore!.score),
                size: 32,
              ),
              const SizedBox(width: 12),
              const Text(
                'Safety Score Details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getScoreColor(_safetyScore!.score).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getScoreColor(_safetyScore!.score).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Score:',
                      style: TextStyle(
                        fontSize: 16,
                        color: _getScoreColor(_safetyScore!.score),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_safetyScore!.score}/100',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(_safetyScore!.score),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Safety Level: ${_safetyScore!.level}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last Updated: ${_safetyScore!.lastUpdate.toString().substring(0, 19)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Score Range:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildScoreRange('80-100', 'Safe', Colors.green),
              _buildScoreRange('60-79', 'Medium Risk', Colors.orange),
              _buildScoreRange('0-59', 'High Risk', Colors.red),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: const Text(
                  'Safety scores are calculated based on crime statistics, time of day, crowd density, and other local factors.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadSafetyScore(); // Refresh score
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScoreRange(String range, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$range: $label',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: 100,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
            ),
          ),
        ),
      );
    }

    if (_safetyScore == null) {
      return Container(
        width: 100,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.error,
            color: Colors.grey,
            size: 24,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _showScoreDetails,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getScoreIcon(_safetyScore!.score),
              color: _getScoreColor(_safetyScore!.score),
              size: 20,
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_safetyScore!.score}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(_safetyScore!.score),
                  ),
                ),
                Text(
                  _getScoreText(_safetyScore!.score),
                  style: TextStyle(
                    fontSize: 10,
                    color: _getScoreColor(_safetyScore!.score),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}