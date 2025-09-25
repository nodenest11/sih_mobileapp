import 'package:flutter/material.dart';

class SosButton extends StatefulWidget {
  final bool disabled;
  final VoidCallback? onTap;
  final String title;
  final String subtitle;
  final Duration pulseDuration;

  const SosButton({
    super.key,
    required this.disabled,
    required this.onTap,
    required this.title,
    required this.subtitle,
    this.pulseDuration = const Duration(seconds: 2),
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.pulseDuration)..repeat(reverse: true);
    _scale = Tween(begin: 1.0, end: 1.04).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _glow = Tween(begin: 0.0, end: 18.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.disabled;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: disabled ? 0.55 : 1,
      child: GestureDetector(
        onTap: disabled ? null : widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
            builder: (context, _) {
            return Transform.scale(
              scale: _scale.value,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: disabled
                        ? [Colors.red.shade200, Colors.red.shade300]
                        : [Colors.red.shade500, Colors.red.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.35),
                      blurRadius: _glow.value,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: disabled
                                  ? [Colors.white.withValues(alpha: 0.25), Colors.white.withValues(alpha: 0.15)]
                                  : [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.15)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        Icon(Icons.emergency, color: Colors.white, size: 36),
                      ],
                    ),
                    const SizedBox(width: 26),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(
                            tag: 'sos-title',
                            child: Material(
                              type: MaterialType.transparency,
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
