import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/tourist.dart';
import '../models/geospatial_heat.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../utils/logger.dart';
import '../widgets/zone_dots_layer.dart';
import '../widgets/panic_alert_pulse_layer.dart';

/// Comprehensive map screen with geographic heatmap, search, and safety score
class MapScreen extends StatefulWidget {
  final Tourist tourist;

  const MapScreen({
    super.key,
    required this.tourist,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  LatLng? _currentLocation;
  bool _isLoading = true;
  
  // Heatmap state
  List<GeospatialHeatPoint> _heatmapData = [];
  bool _showHeatmap = true;
  double _influenceRadiusKm = 20.0; // Reduced from 30km for less clutter
  
  // Search state
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  LatLng? _searchedLocation;
  String? _searchedLocationName;
  
  // Safety score state
  int? _locationSafetyScore;
  String? _locationRiskLevel;
  bool _showSafetyScoreCard = false;
  
  // Zone info state
  GeospatialHeatPoint? _selectedZone;
  bool _showZoneInfo = false;
  
  // Panic alert monitoring
  List<GeospatialHeatPoint> _recentPanicAlerts = [];
  Timer? _panicAlertMonitor;
  GeospatialHeatPoint? _nearestPanicAlert;
  
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _panicAlertMonitor?.cancel();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    setState(() => _isLoading = true);
    
    await _getCurrentLocation();
    await _loadHeatmapData();
    _listenToLocationUpdates();
    _startPanicAlertMonitoring();
    
    // Do immediate initial check for panic alerts (don't wait 30 seconds)
    await _checkForNearbyPanicAlerts();
    
    setState(() => _isLoading = false);
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_currentLocation!, 13.0);
      }
    } catch (e) {
      AppLogger.error('Failed to get current location: $e');
    }
  }

  void _listenToLocationUpdates() {
    _locationService.locationStream.listen((locationData) {
      if (mounted) {
        setState(() {
          _currentLocation = locationData.latLng;
        });
      }
    });
  }

  Future<void> _loadHeatmapData() async {
    try {
      AppLogger.info('🗺️ Loading geographic heatmap data...');
      
      // Load panic alerts (anonymized - no personal data, just aggregated location data)
      AppLogger.info('📍 Fetching panic alert heat data (last 30 days)...');
      final panicHeatData = await _apiService.getPanicAlertHeatData(daysPast: 30);
      AppLogger.info('✅ Loaded ${panicHeatData.length} panic alert heat points');
      
      // Load public restricted zones (no sensitive tourist data)
      AppLogger.info('🚧 Fetching public restricted zones...');
      final zones = await _apiService.getRestrictedZones();
      AppLogger.info('✅ Loaded ${zones.length} restricted zones');
      
      // Convert zones to heat points (center points for performance and privacy)
      // Using center points instead of full polygons maintains privacy
      final zoneHeatData = <GeospatialHeatPoint>[];
      for (final zone in zones) {
        if (zone.polygonCoordinates.isNotEmpty) {
          final avgLat = zone.polygonCoordinates.map((p) => p.latitude).reduce((a, b) => a + b) / zone.polygonCoordinates.length;
          final avgLng = zone.polygonCoordinates.map((p) => p.longitude).reduce((a, b) => a + b) / zone.polygonCoordinates.length;
          
          zoneHeatData.add(GeospatialHeatPoint.fromRestrictedZone(
            latitude: avgLat,
            longitude: avgLng,
            intensity: _getZoneIntensity(zone.type),
            description: zone.name,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _heatmapData = [...panicHeatData, ...zoneHeatData];
        });
      }
      
      AppLogger.info('🎨 Heatmap loaded: ${panicHeatData.length} panic alerts + ${zoneHeatData.length} zones = ${_heatmapData.length} total heat points');
      
      if (_heatmapData.isEmpty) {
        AppLogger.warning('⚠️ No heatmap data available. Map will show without heat overlay.');
      }
    } catch (e) {
      AppLogger.error('❌ Failed to load heatmap data: $e');
      // Don't throw - allow map to function without heatmap
      if (mounted) {
        setState(() {
          _heatmapData = [];
        });
      }
    }
  }

  double _getZoneIntensity(dynamic type) {
    final typeStr = type.toString().toLowerCase();
    if (typeStr.contains('danger')) return 0.9;
    if (typeStr.contains('high') || typeStr.contains('risk')) return 0.85;
    if (typeStr.contains('restrict')) return 0.7;
    if (typeStr.contains('caution')) return 0.5;
    return 0.3;
  }

  // Search functionality
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _apiService.searchLocation(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      AppLogger.error('Search failed: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  void _handleZoneTap(GeospatialHeatPoint zone) {
    setState(() {
      _selectedZone = zone;
      _showZoneInfo = true;
    });
  }

  /// Start monitoring for new panic alerts in nearby areas
  void _startPanicAlertMonitoring() {
    // Check for new panic alerts every 30 seconds
    _panicAlertMonitor = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _checkForNearbyPanicAlerts();
    });
    
    AppLogger.info('🚨 Started panic alert monitoring on map');
  }

  /// Check for panic alerts near user's current location (privacy-protected)
  Future<void> _checkForNearbyPanicAlerts() async {
    if (_currentLocation == null) {
      AppLogger.warning('⚠️ Cannot check panic alerts: No current location');
      return;
    }
    
    try {
      AppLogger.info('🔍 Checking for panic alerts near location: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
      
      // Use PUBLIC endpoint (no authentication required) for better reliability
      final publicAlerts = await _apiService.getPublicPanicAlerts(
        limit: 50,
        hoursBack: 1, // Only very recent alerts (last hour)
      );
      
      AppLogger.info('📡 Received ${publicAlerts.length} public panic alerts from API');
      
      if (publicAlerts.isEmpty) {
        AppLogger.info('ℹ️ No public panic alerts available');
        if (mounted && _recentPanicAlerts.isNotEmpty) {
          setState(() {
            _recentPanicAlerts = [];
          });
        }
        return;
      }
      
      // Convert to heat points and filter by distance
      final allAlertPoints = _apiService.convertPublicAlertsToHeatPoints(publicAlerts);
      AppLogger.info('🗺️ Converted to ${allAlertPoints.length} heat points');
      
      // Filter for alerts within 5km radius
      final nearbyAlerts = allAlertPoints.where((alert) {
        final distance = _calculateDistance(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          alert.latitude,
          alert.longitude,
        );
        return distance <= 5.0; // 5km radius
      }).toList();
      
      AppLogger.info('📍 Found ${nearbyAlerts.length} alerts within 5km radius');
      
      if (nearbyAlerts.isEmpty) {
        AppLogger.info('ℹ️ No panic alerts within 5km of current location');
        if (mounted && _recentPanicAlerts.isNotEmpty) {
          setState(() {
            _recentPanicAlerts = [];
          });
        }
        return;
      }
      
      // Always update alerts on map (even if not new)
      if (mounted) {
        // Filter for new alerts not seen before (for notifications only)
        final newAlerts = nearbyAlerts.where((alert) {
          return !_recentPanicAlerts.any((existing) => 
            existing.latitude == alert.latitude && 
            existing.longitude == alert.longitude
          );
        }).toList();
        
        AppLogger.info('🆕 ${newAlerts.length} new alerts detected');
        
        // Update state with all nearby alerts
        setState(() {
          _recentPanicAlerts = nearbyAlerts;
          _nearestPanicAlert = _findNearestAlert(nearbyAlerts);
        });
        
        AppLogger.info('✅ Updated map with ${_recentPanicAlerts.length} panic alerts');
        
        // Only show notification and refresh for NEW alerts
        if (newAlerts.isNotEmpty) {
          _showPanicAlertNotification(_nearestPanicAlert!);
          await _loadHeatmapData();
        }
      }
    } catch (e) {
      AppLogger.error('Failed to check panic alerts: $e');
    }
  }

  /// Find the nearest panic alert to current location
  GeospatialHeatPoint _findNearestAlert(List<GeospatialHeatPoint> alerts) {
    if (_currentLocation == null || alerts.isEmpty) return alerts.first;
    
    GeospatialHeatPoint nearest = alerts.first;
    double minDistance = _calculateDistance(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      nearest.latitude,
      nearest.longitude,
    );
    
    for (final alert in alerts.skip(1)) {
      final distance = _calculateDistance(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        alert.latitude,
        alert.longitude,
      );
      
      if (distance < minDistance) {
        minDistance = distance;
        nearest = alert;
      }
    }
    
    return nearest;
  }

  /// Show panic alert notification on map
  void _showPanicAlertNotification(GeospatialHeatPoint alert) {
    if (!mounted) return;
    
    final distance = _calculateDistance(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      alert.latitude,
      alert.longitude,
    );
    
    // Show snackbar with alert
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.emergency, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🚨 Panic Alert Nearby',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Emergency reported ${distance.toStringAsFixed(1)}km away. Stay alert!',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            // Center map on alert location (showing aggregated area, not exact user location)
            _mapController.move(
              LatLng(alert.latitude, alert.longitude),
              15.0,
            );
            
            // Highlight the alert zone
            setState(() {
              _selectedZone = alert;
              _showZoneInfo = true;
            });
          },
        ),
      ),
    );
    
    AppLogger.warning('🚨 Panic alert notification shown: ${distance.toStringAsFixed(1)}km away');
  }

  Future<void> _selectSearchResult(Map<String, dynamic> result) async {
    final lat = result['lat'] as double;
    final lon = result['lon'] as double;
    final name = result['display_name'] as String;

    setState(() {
      _searchedLocation = LatLng(lat, lon);
      _searchedLocationName = name;
      _searchResults = [];
      _searchController.clear();
      _searchFocusNode.unfocus();
    });

    // Move map to searched location
    _mapController.move(_searchedLocation!, 15.0);

    // Get safety score for this location
    await _getSafetyScoreForLocation(lat, lon);
  }

  Future<void> _getSafetyScoreForLocation(double lat, double lon) async {
    try {
      // Calculate safety score based on proximity to heat points
      int safetyScore = 100;
      String riskLevel = 'Safe';

      // Check distance to nearest high-risk heat points
      for (final point in _heatmapData) {
        final distance = _calculateDistance(lat, lon, point.latitude, point.longitude);
        
        if (distance < 0.5 && point.intensity > 0.8) { // Within 500m of high risk
          safetyScore = (safetyScore - 40).clamp(0, 100);
        } else if (distance < 1.0 && point.intensity > 0.6) { // Within 1km of medium risk
          safetyScore = (safetyScore - 20).clamp(0, 100);
        } else if (distance < 2.0 && point.intensity > 0.4) { // Within 2km of low risk
          safetyScore = (safetyScore - 10).clamp(0, 100);
        }
      }

      // Determine risk level
      if (safetyScore >= 80) {
        riskLevel = 'Safe';
      } else if (safetyScore >= 60) {
        riskLevel = 'Moderate';
      } else if (safetyScore >= 40) {
        riskLevel = 'Risky';
      } else {
        riskLevel = 'Dangerous';
      }

      if (mounted) {
        setState(() {
          _locationSafetyScore = safetyScore;
          _locationRiskLevel = riskLevel;
          _showSafetyScoreCard = true;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to get safety score: $e');
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  Color _getSafetyScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.deepOrange;
    return Colors.red;
  }

  IconData _getRiskLevelIcon(String? riskLevel) {
    switch (riskLevel?.toLowerCase()) {
      case 'safe':
        return Icons.check_circle;
      case 'moderate':
        return Icons.warning;
      case 'risky':
        return Icons.error;
      case 'dangerous':
        return Icons.dangerous;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Map'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        shadowColor: Colors.black12,
        scrolledUnderElevation: 1,
        actions: [
          // Toggle zone dots
          IconButton(
            icon: Icon(_showHeatmap ? Icons.visibility : Icons.visibility_off),
            tooltip: _showHeatmap ? 'Hide Zones' : 'Show Zones',
            onPressed: () {
              setState(() => _showHeatmap = !_showHeatmap);
            },
          ),
          // Recenter to current location
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'My Location',
            onPressed: () {
              if (_currentLocation != null) {
                _mapController.move(_currentLocation!, 13.0);
              }
            },
          ),
          // Refresh heatmap data
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadHeatmapData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading map...'),
                ],
              ),
            )
          : Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? const LatLng(20.5937, 78.9629), // India center
                    initialZoom: 13.0,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    // OpenStreetMap tiles
                    TileLayer(
                      urlTemplate: ApiService.osmTileUrl,
                      userAgentPackageName: 'com.tourist.safety',
                      keepBuffer: 5,
                      maxNativeZoom: 18,
                      maxZoom: 18,
                    ),
                    
                    // Zone dots layer (small circular dots with configurable influence)
                    if (_showHeatmap && _heatmapData.isNotEmpty)
                      ZoneDotsLayer(
                        heatPoints: _heatmapData,
                        dotSize: 12.0,
                        influenceRadiusKm: _influenceRadiusKm,
                        visible: _showHeatmap,
                        onZoneTap: _handleZoneTap,
                      ),
                    
                    // Panic alert pulse layer (real-time emergency alerts with animation)
                    if (_recentPanicAlerts.isNotEmpty)
                      StreamBuilder<MapEvent>(
                        stream: _mapController.mapEventStream,
                        builder: (context, snapshot) {
                          final camera = _mapController.camera;
                          return PanicAlertPulseLayer(
                            panicAlerts: _recentPanicAlerts,
                            camera: camera,
                          );
                        },
                      ),
                    
                    // Markers
                    MarkerLayer(
                      markers: [
                        // User location marker
                        if (_currentLocation != null)
                          Marker(
                            point: _currentLocation!,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        
                        // Searched location marker
                        if (_searchedLocation != null)
                          Marker(
                            point: _searchedLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.place,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                
                // Search box at top
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Search input
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Search location...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchResults = [];
                                            _searchedLocation = null;
                                            _showSafetyScoreCard = false;
                                          });
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                          
                          // Search results
                          if (_isSearching)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          
                          if (_searchResults.isNotEmpty && !_isSearching)
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final result = _searchResults[index];
                                  return ListTile(
                                    leading: const Icon(Icons.location_on),
                                    title: Text(
                                      result['display_name'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => _selectSearchResult(result),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Safety score card
                if (_showSafetyScoreCard && _locationSafetyScore != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Location Safety Score',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      _showSafetyScoreCard = false;
                                      _searchedLocation = null;
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            if (_searchedLocationName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 12),
                                child: Text(
                                  _searchedLocationName!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Score circle
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getSafetyScoreColor(_locationSafetyScore!).withValues(alpha: 0.1),
                                    border: Border.all(
                                      color: _getSafetyScoreColor(_locationSafetyScore!),
                                      width: 4,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$_locationSafetyScore',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: _getSafetyScoreColor(_locationSafetyScore!),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Risk level
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _getRiskLevelIcon(_locationRiskLevel),
                                            color: _getSafetyScoreColor(_locationSafetyScore!),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _locationRiskLevel ?? 'Unknown',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: _getSafetyScoreColor(_locationSafetyScore!),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _getScoreDescription(_locationSafetyScore!),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Safety tips
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _getSafetyTip(_locationSafetyScore!),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Zone info card (center bottom - shown when a zone dot is tapped)
                if (_showZoneInfo && _selectedZone != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _getZoneColor(_selectedZone!.intensity),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getZoneIcon(_selectedZone!.type),
                                        color: _getZoneColor(_selectedZone!.intensity),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _getZoneTypeName(_selectedZone!.type),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: _getZoneColor(_selectedZone!.intensity),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      _showZoneInfo = false;
                                      _selectedZone = null;
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _getZoneColor(_selectedZone!.intensity).withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_rounded,
                                    size: 16,
                                    color: _getZoneColor(_selectedZone!.intensity),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Intensity: ${(_selectedZone!.intensity * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _getZoneColor(_selectedZone!.intensity),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedZone!.description != null && 
                                _selectedZone!.description!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                _selectedZone!.description!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.notification_important_outlined,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_selectedZone!.alertCount} ${_selectedZone!.alertCount == 1 ? 'alert' : 'alerts'} recorded',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_influenceRadiusKm.toStringAsFixed(0)}km influence radius',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Zone dots legend (bottom left)
                if (_showHeatmap)
                  Positioned(
                    bottom: _showZoneInfo 
                        ? 230  // Move up when zone info card is shown
                        : (_showSafetyScoreCard ? 200 : 16),
                    left: 16,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Zone Indicators',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${_heatmapData.length} zones)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_influenceRadiusKm.toStringAsFixed(0)}km influence area',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildLegendItem(const Color(0xFFD32F2F), 'Dangerous'),
                            const SizedBox(height: 4),
                            _buildLegendItem(const Color(0xFFFF5722), 'High Risk'),
                            const SizedBox(height: 4),
                            _buildLegendItem(const Color(0xFFFF9800), 'Caution'),
                            const SizedBox(height: 4),
                            _buildLegendItem(const Color(0xFFFFC107), 'Mild'),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  String _getScoreDescription(int score) {
    if (score >= 80) return 'This area is generally safe for tourists.';
    if (score >= 60) return 'Exercise normal caution in this area.';
    if (score >= 40) return 'Be cautious and aware of your surroundings.';
    return 'High-risk area. Avoid if possible.';
  }

  String _getSafetyTip(int score) {
    if (score >= 80) return 'Enjoy your visit! Stay aware of your belongings.';
    if (score >= 60) return 'Stay in well-lit areas and avoid isolated spots.';
    if (score >= 40) return 'Travel in groups and keep emergency contacts ready.';
    return 'Consider visiting during daylight hours only. Use the panic button if needed.';
  }

  Color _getZoneColor(double intensity) {
    if (intensity >= 0.8) return const Color(0xFFD32F2F); // Critical - Dark red
    if (intensity >= 0.6) return const Color(0xFFF44336); // High - Red
    if (intensity >= 0.4) return const Color(0xFFFF9800); // Caution - Orange
    return const Color(0xFFFFC107); // Mild - Amber
  }

  IconData _getZoneIcon(HeatPointType type) {
    switch (type) {
      case HeatPointType.panicAlert:
        return Icons.emergency;
      case HeatPointType.restrictedZone:
        return Icons.block;
      case HeatPointType.safetyIncident:
        return Icons.warning;
      case HeatPointType.general:
        return Icons.location_on;
    }
  }

  String _getZoneTypeName(HeatPointType type) {
    switch (type) {
      case HeatPointType.panicAlert:
        return 'Panic Alert Zone';
      case HeatPointType.restrictedZone:
        return 'Restricted Zone';
      case HeatPointType.safetyIncident:
        return 'Safety Incident Zone';
      case HeatPointType.general:
        return 'Zone';
    }
  }
}
