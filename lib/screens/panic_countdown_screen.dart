import 'dart:async';
import 'package:flutter/material.dart';
import '../services/panic_service.dart';
import 'panic_result_screen.dart';

class PanicCountdownScreen extends StatefulWidget {
  final Duration countdownDuration;

  const PanicCountdownScreen({
    super.key,
    this.countdownDuration = const Duration(seconds: 10),
  });

  @override
  State<PanicCountdownScreen> createState() => _PanicCountdownScreenState();
}

class _PanicCountdownScreenState extends State<PanicCountdownScreen> {
  late Duration _remaining;
  Timer? _timer;
  bool _sending = false;
  final PanicService _panicService = PanicService();

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownDuration;
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      setState(() {
        _remaining -= const Duration(seconds: 1);
      });
      if (_remaining <= Duration.zero) {
        _timer?.cancel();
        _triggerSend();
      }
    });
  }

  Future<void> _triggerSend() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await _panicService.sendPanicAlert();
      if (!mounted) return;
      final rem = await _panicService.remaining();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PanicResultScreen(
            initialRemaining: rem,
            startedAt: DateTime.now(),
          ),
        ),
      );
    } on PanicCooldownException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Already sent. Remaining ${e.remaining.inMinutes}m')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send SOS: $e')),
      );
      Navigator.of(context).pop();
    }
  }

  void _cancel() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) => d.inSeconds.toString();

  @override
  Widget build(BuildContext context) {
    final percent = 1 - (_remaining.inMilliseconds / widget.countdownDuration.inMilliseconds);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _sending ? null : _cancel,
                    child: const Text('CANCEL'),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: percent.clamp(0, 1),
                      strokeWidth: 12,
                      backgroundColor: Colors.red.shade50,
                      valueColor: AlwaysStoppedAnimation(Colors.red.shade600),
                    ),
                    Text(
                      _format(_remaining),
                      style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w700, color: Colors.red),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Sending SOS',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.grey.shade900),
              ),
              const SizedBox(height: 12),
              Text(
                'Auto in ${_remaining.inSeconds}s',
                style: TextStyle(fontSize: 14, color: Colors.red.shade400, letterSpacing: 0.5),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sending ? null : _triggerSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_sending ? 'SENDING…' : 'SEND NOW'),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _sending ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('CANCEL'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
