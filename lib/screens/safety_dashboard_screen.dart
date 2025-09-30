import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../models/alert.dart';
import '../theme/app_theme.dart';

class SafetyDashboardScreen extends StatefulWidget {
  const SafetyDashboardScreen({super.key});

  @override
  State<SafetyDashboardScreen> createState() => _SafetyDashboardScreenState();
}

class _SafetyDashboardScreenState extends State<SafetyDashboardScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();
  
  int _safetyScore = 0;
  String _riskLevel = 'unknown';
  String _lastUpdated = '';
  List<RestrictedZone> _zones = [];
  bool _isLoading = true;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _loadSafetyData();
    _getCurrentLocation();
  }

  Future<void> _loadSafetyData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load safety score
      final scoreResponse = await _apiService.getSafetyScore();
      if (scoreResponse['success'] == true) {
        setState(() {
          _safetyScore = scoreResponse['safety_score'] ?? 0;
          _riskLevel = scoreResponse['risk_level'] ?? 'unknown';
          _lastUpdated = scoreResponse['last_updated'] ?? '';
        });
      }

      // Load safety zones
      final zones = await _apiService.getRestrictedZones();
      setState(() {
        _zones = zones;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load safety data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        
        // Center map on current location
        if (_currentLocation != null) {
          _mapController.move(_currentLocation!, 13.0);
        }
      }
    } catch (e) {
      // Location permission might be denied
    }
  }

  Color _getSafetyColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getSafetyDescription(int score) {
    if (score >= 80) return "Safe Area";
    if (score >= 60) return "Moderate Risk";
    return "High Risk Area";
  }

  List<String> _getSafetyRecommendations(int score, String riskLevel) {
    if (score >= 80) {
      return [
        "Stay aware of your surroundings",
        "Keep emergency contacts handy",
        "Enjoy your trip safely",
      ];
    } else if (score >= 60) {
      return [
        "Stay in well-lit, populated areas",
        "Avoid traveling alone at night",
        "Keep valuables secure",
        "Share your location with trusted contacts",
      ];
    } else {
      return [
        "Consider moving to a safer area",
        "Stay in groups if possible",
        "Keep emergency services contact ready",
        "Be extra vigilant of surroundings",
        "Inform others of your exact location",
      ];
    }
  }

  Widget _buildSafetyScoreCard() {
    final color = _getSafetyColor(_safetyScore);
    final description = _getSafetyDescription(_safetyScore);
    
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.security, color: color, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Safety Score',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_safetyScore',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: _safetyScore / 100,
                      strokeWidth: 8,
                      backgroundColor: color.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
              if (_lastUpdated.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Last updated: ${_formatLastUpdated(_lastUpdated)}',
                  style: TextStyle(
                    color: AppColors.greyText,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    final recommendations = _getSafetyRecommendations(_safetyScore, _riskLevel);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.redPrimary),
                const SizedBox(width: 8),
                const Text(
                  'Safety Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recommendations.map((recommendation) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: AppColors.redPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildZonesMapCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.map, color: AppColors.redPrimary),
                const SizedBox(width: 8),
                const Text(
                  'Safety Zones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? const LatLng(28.6139, 77.2090),
                    initialZoom: 13.0,
                    maxZoom: 18.0,
                    minZoom: 1.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.safehorizon.tourist',
                    ),
                    // Add zone markers
                    MarkerLayer(
                      markers: [
                        if (_currentLocation != null)
                          Marker(
                            point: _currentLocation!,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ..._zones.map((zone) {
                          // Calculate center point from polygon coordinates
                          LatLng center = _calculatePolygonCenter(zone.polygonCoordinates);
                          return Marker(
                            point: center,
                            child: Icon(
                              Icons.warning,
                              color: zone.type == ZoneType.restricted 
                                  ? Colors.red 
                                  : zone.type == ZoneType.highRisk 
                                      ? Colors.orange 
                                      : Colors.yellow,
                              size: 24,
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZonesList() {
    if (_zones.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: AppColors.greyText, size: 48),
              const SizedBox(height: 8),
              Text(
                'No Safety Zones Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.greyText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Safety zone information will appear here when available',
                style: TextStyle(
                  color: AppColors.greyText,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list, color: AppColors.redPrimary),
                const SizedBox(width: 8),
                const Text(
                  'Nearby Zones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._zones.take(5).map((zone) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getZoneColor(zone.type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getZoneColor(zone.type).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getZoneIcon(zone.type),
                    color: _getZoneColor(zone.type),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          zone.description,
                          style: TextStyle(
                            color: AppColors.greyText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getZoneColor(zone.type),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      zone.type.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Color _getZoneColor(ZoneType zoneType) {
    switch (zoneType) {
      case ZoneType.restricted:
      case ZoneType.dangerous:
        return Colors.red;
      case ZoneType.highRisk:
        return Colors.orange;
      case ZoneType.caution:
        return Colors.yellow;
      case ZoneType.safe:
        return Colors.green;
    }
  }

  IconData _getZoneIcon(ZoneType zoneType) {
    switch (zoneType) {
      case ZoneType.restricted:
      case ZoneType.dangerous:
        return Icons.dangerous;
      case ZoneType.highRisk:
        return Icons.warning;
      case ZoneType.caution:
        return Icons.info;
      case ZoneType.safe:
        return Icons.check_circle;
    }
  }

  LatLng _calculatePolygonCenter(List<LatLng> coordinates) {
    if (coordinates.isEmpty) {
      return const LatLng(0, 0);
    }
    
    double totalLat = 0;
    double totalLng = 0;
    
    for (LatLng coord in coordinates) {
      totalLat += coord.latitude;
      totalLng += coord.longitude;
    }
    
    return LatLng(
      totalLat / coordinates.length,
      totalLng / coordinates.length,
    );
  }

  String _formatLastUpdated(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      }
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Dashboard'),
        backgroundColor: AppColors.redPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadSafetyData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSafetyData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSafetyScoreCard(),
                  const SizedBox(height: 16),
                  _buildRecommendationsCard(),
                  const SizedBox(height: 16),
                  _buildZonesMapCard(),
                  const SizedBox(height: 16),
                  _buildZonesList(),
                ],
              ),
            ),
    );
  }
}