import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/location.dart';

/// Simple heatmap overlay that renders colored circles with gradients
/// This is a basic implementation that should work with flutter_map 8.x
class HeatmapLayer extends StatelessWidget {
  final List<HeatmapPoint> points;
  final double baseRadius;
  final double minOpacity;
  final double maxOpacity;
  final bool visible;
  final double intensityScale;

  const HeatmapLayer({
    super.key,
    required this.points,
    this.baseRadius = 60,
    this.minOpacity = 0.2,
    this.maxOpacity = 0.8,
    this.visible = true,
    this.intensityScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || points.isEmpty) {
      print('HeatmapLayer: Not visible or no points (${points.length})');
      return const SizedBox.shrink();
    }
    
    print('HeatmapLayer: Rendering ${points.length} heatmap points');
    
    // For now, let's use CircleLayer which we know works
    return CircleLayer(
      circles: points.map((point) {
        final intensity = (point.intensity * intensityScale).clamp(0.0, 1.0);
        final color = _getHeatmapColor(intensity);
        final opacity = minOpacity + (maxOpacity - minOpacity) * intensity;
        final radius = baseRadius + (intensity * 40);
        
        return CircleMarker(
          point: LatLng(point.latitude, point.longitude),
          color: color.withOpacity(opacity * 0.7),
          borderColor: color.withOpacity(opacity),
          borderStrokeWidth: 2.0,
          radius: radius,
        );
      }).toList(),
    );
  }

  Color _getHeatmapColor(double intensity) {
    // Smooth color progression
    if (intensity <= 0.0) return const Color(0xFF4C1B7A);
    if (intensity >= 1.0) return const Color(0xFFFF6B35);
    
    const colors = [
      Color(0xFF4C1B7A), // deep purple
      Color(0xFF2E86AB), // blue  
      Color(0xFF06FFA5), // cyan
      Color(0xFF8FD14F), // green
      Color(0xFFFFC629), // yellow
      Color(0xFFFF6B35), // orange
    ];
    
    const stops = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];
    
    for (int i = 0; i < stops.length - 1; i++) {
      if (intensity >= stops[i] && intensity <= stops[i + 1]) {
        final t = (intensity - stops[i]) / (stops[i + 1] - stops[i]);
        return Color.lerp(colors[i], colors[i + 1], t)!;
      }
    }
    
    return colors.last;
  }
}
