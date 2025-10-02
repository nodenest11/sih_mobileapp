import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/tourist.dart';
import '../models/alert.dart';
import '../models/geospatial_heat.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../utils/logger.dart';
import '../widgets/search_bar.dart' as custom_search;
import '../widgets/geospatial_heatmap.dart';
import '../widgets/heatmap_legend.dart';

class MapScreen extends StatefulWidget {
  final Tourist tourist;

  const MapScreen({
    super.key,
    required this.tourist,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  
  LatLng? _currentLocation; // Will be set when location is obtained
  List<RestrictedZone> _restrictedZones = [];
  List<Marker> _markers = [];
  List<Polygon> _polygons = [];
  
  bool _isLoadingZones = false;
  bool _showRestrictedZones = true;
  bool _isFollowingUser = false;

  // Heatmap state
  List<GeospatialHeatPoint> _heatmapData = [];
  bool _isLoadingHeatmap = false;
  bool _showHeatmap = true;
  bool _showHeatmapLegend = false;
  Set<HeatPointType> _visibleHeatTypes = {
    HeatPointType.panicAlert,
    HeatPointType.restrictedZone,
  };

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _initializeMap();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    await _loadRestrictedZones();
    await _loadHeatmapData();
    _listenToLocationUpdates();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        if (_currentLocation != null) {
          _updateMapCenter(_currentLocation!);
        }
      }
    } catch (e) {
      // Unable to get current location - map will show world view initially
    }
  }

  void _listenToLocationUpdates() {
    _locationService.locationStream.listen((locationData) {
      setState(() {
        _currentLocation = locationData.latLng;
      });
      
      // Check for geo-fence violations
      _checkGeoFenceViolations(locationData.latLng);
      
      // Update map center if following user
      if (_isFollowingUser && _currentLocation != null) {
        _updateMapCenter(_currentLocation!);
      }
    });
  }

  Future<void> _loadRestrictedZones() async {
    setState(() {
      _isLoadingZones = true;
    });

    try {
      final zones = await _apiService.getRestrictedZones();
      setState(() {
        _restrictedZones = zones;
        _isLoadingZones = false;
      });
      _updatePolygons();
      
      // Reload heatmap data with new zones
      await _loadHeatmapData();
      
      AppLogger.info('Loaded ${zones.length} restricted zones');
    } catch (e) {
      setState(() {
        _isLoadingZones = false;
      });
      AppLogger.error('Failed to load restricted zones: $e');
    }
  }

  Future<void> _loadHeatmapData() async {
    if (!_showHeatmap) return;
    
    setState(() {
      _isLoadingHeatmap = true;
    });

    try {
      // Get panic alerts for heatmap
      final panicHeatData = await _apiService.getPanicAlertHeatData(daysPast: 30);
      
      // Add restricted zones as heat points with multiple points per zone for better visualization
      final restrictedZoneHeatData = <GeospatialHeatPoint>[];
      
      for (final zone in _restrictedZones) {
        if (zone.polygonCoordinates.isNotEmpty) {
          // Calculate zone centroid
          final avgLat = zone.polygonCoordinates.map((p) => p.latitude).reduce((a, b) => a + b) / zone.polygonCoordinates.length;
          final avgLng = zone.polygonCoordinates.map((p) => p.longitude).reduce((a, b) => a + b) / zone.polygonCoordinates.length;
          
          // Add center point with high intensity
          restrictedZoneHeatData.add(GeospatialHeatPoint.fromRestrictedZone(
            latitude: avgLat,
            longitude: avgLng,
            intensity: _getZoneIntensity(zone.type),
            description: '${zone.name} (Center)',
          ));
          
          // Add additional points around the zone perimeter for better coverage
          for (int i = 0; i < zone.polygonCoordinates.length; i += 2) {
            final point = zone.polygonCoordinates[i];
            restrictedZoneHeatData.add(GeospatialHeatPoint.fromRestrictedZone(
              latitude: point.latitude,
              longitude: point.longitude,
              intensity: _getZoneIntensity(zone.type) * 0.7, // Slightly lower intensity for perimeter
              description: '${zone.name} (Perimeter)',
            ));
          }
        }
      }

      setState(() {
        _heatmapData = [...panicHeatData, ...restrictedZoneHeatData];
        _isLoadingHeatmap = false;
      });
      
      AppLogger.info('Heatmap data loaded: ${panicHeatData.length} panic alerts, ${restrictedZoneHeatData.length} zone points');
    } catch (e) {
      setState(() {
        _isLoadingHeatmap = false;
      });
      AppLogger.error('Failed to load heatmap data: $e');
    }
  }

  double _getZoneIntensity(ZoneType type) {
    switch (type) {
      case ZoneType.highRisk:
        return 0.95; // Very high intensity for high-risk zones
      case ZoneType.dangerous:
        return 0.85; // High intensity for dangerous zones
      case ZoneType.restricted:
        return 0.7; // Moderate-high intensity for restricted zones
      case ZoneType.caution:
        return 0.5; // Moderate intensity for caution zones
      case ZoneType.safe:
        return 0.2; // Low intensity for safe zones
    }
  }

  /// Refresh heatmap data
  Future<void> _refreshHeatmap() async {
    await _loadHeatmapData();
  }

  /// Toggle heatmap visibility and refresh if needed
  void _toggleHeatmap() {
    setState(() {
      _showHeatmap = !_showHeatmap;
    });
    if (_showHeatmap && _heatmapData.isEmpty) {
      _refreshHeatmap();
    }
  }

  void _updateMapCenter(LatLng location) {
    _mapController.move(location, 15.0);
  }

  void _updatePolygons() {
    _polygons = _restrictedZones.map((zone) => Polygon(
      points: zone.polygonCoordinates,
      color: _getZoneColor(zone.type).withValues(alpha: 0.3),
      borderColor: _getZoneColor(zone.type),
      borderStrokeWidth: 2.0,
    )).toList();
  }

  Color _getZoneColor(ZoneType type) {
    switch (type) {
      case ZoneType.highRisk:
        return Colors.red;
      case ZoneType.dangerous:
        return Colors.purple;
      case ZoneType.restricted:
        return Colors.orange;
      case ZoneType.caution:
        return Colors.yellow;
      case ZoneType.safe:
        return Colors.green; // Green color for safe zones
    }
  }

  void _checkGeoFenceViolations(LatLng currentPos) {
    for (final zone in _restrictedZones) {
      if (_locationService.isPointInPolygon(currentPos, zone.polygonCoordinates)) {
        _showGeoFenceAlert(zone);
        break;
      }
    }
  }

  void _showGeoFenceAlert(RestrictedZone zone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning,
                color: _getZoneColor(zone.type),
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text('Area Alert'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                zone.warningMessage ?? '⚠ You have entered a restricted/high-risk area.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Zone: ${zone.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (zone.description.isNotEmpty)
                Text(zone.description),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Optionally navigate away from the area or show directions
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getZoneColor(zone.type),
                foregroundColor: Colors.white,
              ),
              child: const Text('Get Directions Away'),
            ),
          ],
        );
      },
    );
  }

  // Removed unused _toggleFollowUser method

  void _onLocationSelected(LatLng location, String name) {
    _updateMapCenter(location);
    
    // Add a temporary marker for the searched location
    setState(() {
      _markers = [
        ..._markers,
        Marker(
          point: location,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_on,
            color: Colors.blue,
            size: 40,
          ),
        ),
      ];
    });

    // Show location info
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Found: $name'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Map'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: _currentLocation == null 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Waiting for location data from backend...',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          )
        : Stack(
            children: [
              // Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation!,
                  initialZoom: 15.0,
                  minZoom: 1.0,
                  maxZoom: 18.0,
                ),
            children: [
              // OpenStreetMap tile layer
              TileLayer(
                urlTemplate: ApiService.osmTileUrl,
                userAgentPackageName: 'com.tourist.safety',
              ),
              
              // Geospatial heatmap layer
              if (_showHeatmap && _heatmapData.isNotEmpty)
                GeospatialHeatmapLayer(
                  heatPoints: _heatmapData,
                  config: HeatmapConfig(
                    visibleTypes: _visibleHeatTypes.toList(),
                    baseRadius: 60.0, // Increased radius for better visibility
                    maxPoints: 2000, // Allow more points for better coverage
                    minOpacity: 0.2, // Higher minimum opacity for restricted zones
                    maxOpacity: 0.9, // Higher maximum opacity for visibility
                  ),
                  visible: _showHeatmap,
                ),
              
              // Restricted zones polygons
              if (_showRestrictedZones)
                PolygonLayer(
                  polygons: _polygons,
                ),
              
              // Markers layer
              MarkerLayer(
                markers: [
                  // Current location marker with pulse animation (only if location is available)
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 60,
                      height: 60,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulse effect
                              Container(
                                width: 60 * (1 + _pulseAnimation.value * 0.5),
                                height: 60 * (1 + _pulseAnimation.value * 0.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue.withValues(alpha: 0.3 * (1 - _pulseAnimation.value)),
                              ),
                            ),
                            // Main marker
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Other markers
                  ..._markers,
                ],
              ),
            ],
          ),
          
          // Search bar
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: custom_search.SearchBar(
              onLocationSelected: _onLocationSelected,
              hintText: 'Search for a place...',
            ),
          ),
          
          // Loading indicators
          if (_isLoadingZones)
            Positioned(
              top: 100,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),

          // Heatmap loading indicator
          if (_isLoadingHeatmap)
            Positioned(
              top: 100,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text("Loading heatmap...", style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),

          // Heatmap controls
          Positioned(
            top: 140,
            right: 16,
            child: HeatmapControls(
              heatmapVisible: _showHeatmap,
              onToggleHeatmap: _toggleHeatmap,
              onShowLegend: () {
                setState(() {
                  _showHeatmapLegend = !_showHeatmapLegend;
                });
              },
            ),
          ),

          // Heatmap legend
          if (_showHeatmapLegend)
            Positioned(
              top: 200,
              right: 16,
              left: 16,
              child: HeatmapLegend(
                visibleTypes: _visibleHeatTypes,
                onVisibilityChanged: (newTypes) {
                  setState(() {
                    _visibleHeatTypes = newTypes;
                  });
                },
                isExpanded: true,
                onToggleExpanded: () {
                  setState(() {
                    _showHeatmapLegend = false;
                  });
                },
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.layers_rounded, size: 22),
              color: const Color(0xFF1E40AF),
              onPressed: _showMapOptions,
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.my_location_rounded, size: 22),
              color: const Color(0xFF1E40AF),
              onPressed: () async {
                await _getCurrentLocation();
                if (_currentLocation != null) {
                  _updateMapCenter(_currentLocation!);
                }
              },
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  void _showMapOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Map Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Restricted Zones'),
                    subtitle: const Text('Display high-risk and restricted areas'),
                    value: _showRestrictedZones,
                    onChanged: (value) {
                      setModalState(() {
                        _showRestrictedZones = value;
                      });
                      setState(() {
                        _showRestrictedZones = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Follow My Location'),
                    subtitle: const Text('Keep map centered on your location'),
                    value: _isFollowingUser,
                    onChanged: (value) {
                      setModalState(() {
                        _isFollowingUser = value;
                      });
                      setState(() {
                        _isFollowingUser = value;
                      });
                      if (_isFollowingUser && _currentLocation != null) {
                        _updateMapCenter(_currentLocation!);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _loadRestrictedZones();
                      },
                      child: const Text('Refresh Map Data'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
