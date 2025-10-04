import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/panic_service.dart';
import '../models/tourist.dart';
import 'sos_success_screen.dart';

class SOSCountdownScreen extends StatefulWidget {
  final Tourist tourist;
  final Duration countdownDuration;

  const SOSCountdownScreen({
    super.key,
    required this.tourist,
    this.countdownDuration = const Duration(seconds: 10),
  });

  @override
  State<SOSCountdownScreen> createState() => _SOSCountdownScreenState();
}

class _SOSCountdownScreenState extends State<SOSCountdownScreen>
    with SingleTickerProviderStateMixin {
  late Duration _remaining;
  Timer? _timer;
  bool _isSending = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final PanicService _panicService = PanicService();

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownDuration;
    
    // Setup pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _startCountdown();
  }

  void _startCountdown() {
    // Haptic feedback on start
    HapticFeedback.heavyImpact();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      setState(() {
        _remaining -= const Duration(seconds: 1);
      });
      
      // Haptic feedback every second
      HapticFeedback.lightImpact();
      
      if (_remaining <= Duration.zero) {
        timer.cancel();
        _sendSOS();
      }
    });
  }

  Future<void> _sendSOS() async {
    if (_isSending) return;
    
    setState(() => _isSending = true);
    _pulseController.stop();
    
    // Strong haptic feedback
    HapticFeedback.heavyImpact();
    
    try {
      await _panicService.sendPanicAlert();
      
      if (!mounted) return;
      
      // Navigate to success screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SOSSuccessScreen(tourist: widget.tourist),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Show error and go back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send SOS: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _cancel() {
    _timer?.cancel();
    _pulseController.stop();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1 - (_remaining.inMilliseconds / widget.countdownDuration.inMilliseconds);
    
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Header with cancel button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 80), // Balance the cancel button
                  const Text(
                    'Emergency SOS',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  TextButton(
                    onPressed: _isSending ? null : _cancel,
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Main countdown display
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isSending ? 1.0 : _pulseAnimation.value,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.red.shade600,
                            Colors.red.shade800,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Progress circle
                          SizedBox(
                            width: 240,
                            height: 240,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 8,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          
                          // Center content
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isSending) ...[
                                const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'SENDING...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ] else ...[
                                Icon(
                                  Icons.emergency,
                                  size: 60,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '${_remaining.inSeconds}',
                                  style: const TextStyle(
                                    fontSize: 72,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const Text(
                                  'SECONDS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const Spacer(),
              
              // Description
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red.shade600),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Emergency Alert',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isSending
                          ? 'Sending your location and emergency alert to police and emergency contacts...'
                          : 'Emergency services will be notified with your current location. Cancel if this was accidental.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              if (!_isSending) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _timer?.cancel();
                          _sendSOS();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'SEND NOW',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}