import 'dart:async';
import 'package:flutter/material.dart';

class PanicResultScreen extends StatefulWidget {
  final Duration initialRemaining;
  final DateTime startedAt;
  final VoidCallback? onClose;

  const PanicResultScreen({
    super.key,
    required this.initialRemaining,
    required this.startedAt,
    this.onClose,
  });

  @override
  State<PanicResultScreen> createState() => _PanicResultScreenState();
}

class _PanicResultScreenState extends State<PanicResultScreen> {
  late Duration _remaining;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _remaining = widget.initialRemaining;
    _startTimer();
  }

  void _startTimer() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final passed = DateTime.now().difference(widget.startedAt);
      final newRemaining = widget.initialRemaining - passed;
      if (newRemaining <= Duration.zero) {
        setState(() => _remaining = Duration.zero);
        _ticker?.cancel();
      } else {
        setState(() => _remaining = newRemaining);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final cooling = _remaining > Duration.zero;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Close button row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      widget.onClose?.call();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Success Icon
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: Colors.red.shade600, size: 72),
              ),
              const SizedBox(height: 28),
              Text(
                'SOS Sent',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                cooling
                    ? 'Your emergency has been transmitted. Stay where you are if safe.'
                    : 'You can send another alert now.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.4, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              // Cooldown chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: cooling ? Colors.red.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cooling ? Icons.lock_clock : Icons.lock_open, size: 18, color: cooling ? Colors.red.shade700 : Colors.green.shade700),
                    const SizedBox(width: 6),
                    Text(
                      cooling ? 'Next SOS in ${_format(_remaining)}' : 'Ready for new SOS',
                      style: TextStyle(
                        color: cooling ? Colors.red.shade800 : Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onClose?.call();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('BACK TO HOME'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
