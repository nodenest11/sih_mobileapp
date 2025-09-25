import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/tourist.dart';
import '../models/location.dart';
import '../models/alert.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/search_bar.dart' as custom_search;

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
  List<HeatmapPoint> _heatmapData = [];
  List<RestrictedZone> _restrictedZones = [];
  List<Marker> _markers = [];
  List<Polygon> _polygons = [];
  
  bool _isLoadingHeatmap = false;
  bool _isLoadingZones = false;
  bool _showHeatmap = true;
  bool _showRestrictedZones = true;
  bool _isFollowingUser = false;

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
    await _loadHeatmapData();
    await _loadRestrictedZones();
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

  Future<void> _loadHeatmapData() async {
    setState(() {
      _isLoadingHeatmap = true;
    });

    try {
      final heatmapData = await _apiService.getHeatmapData();
      setState(() {
        _heatmapData = heatmapData;
        _isLoadingHeatmap = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingHeatmap = false;
      });
    }
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
    } catch (e) {
      setState(() {
        _isLoadingZones = false;
      });
    }
  }

  void _updateMapCenter(LatLng location) {
    _mapController.move(location, 15.0);
  }

  void _updatePolygons() {
    _polygons = _restrictedZones.map((zone) => Polygon(
      points: zone.polygonCoordinates,
      color: _getZoneColor(zone.type).withOpacity(0.3),
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

  void _toggleFollowUser() {
    setState(() {
      _isFollowingUser = !_isFollowingUser;
    });
    
    if (_isFollowingUser && _currentLocation != null) {
      _updateMapCenter(_currentLocation!);
    }
  }

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
        foregroundColor: const Color(0xFF1565C0),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _toggleFollowUser,
            icon: Icon(
              _isFollowingUser ? Icons.my_location : Icons.location_searching_outlined,
            ),
            tooltip: _isFollowingUser ? 'Stop following' : 'Follow location',
          ),
        ],
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
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tourist.safety',
              ),
              
              // Restricted zones polygons
              if (_showRestrictedZones)
                PolygonLayer(
                  polygons: _polygons,
                ),
              
              // Heatmap circles (custom implementation)
              if (_showHeatmap)
                CircleLayer(
                  circles: _heatmapData.map((point) => CircleMarker(
                    point: point.latLng,
                    color: Colors.red.withOpacity(point.intensity * 0.6),
                    borderColor: Colors.red.withOpacity(point.intensity),
                    borderStrokeWidth: 1.0,
                    radius: 20 + (point.intensity * 30),
                  )).toList(),
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
                                  color: Colors.blue.withOpacity(0.3 * (1 - _pulseAnimation.value)),
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
          if (_isLoadingHeatmap || _isLoadingZones)
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
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "layers",
            mini: true,
            onPressed: _showMapOptions,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1565C0),
            child: const Icon(Icons.layers_outlined),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "my_location",
            mini: true,
            onPressed: () async {
              await _getCurrentLocation();
              if (_currentLocation != null) {
                _updateMapCenter(_currentLocation!);
              }
            },
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1565C0),
            child: const Icon(Icons.my_location_outlined),
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
                    title: const Text('Show Heatmap'),
                    subtitle: const Text('Display safety intensity areas'),
                    value: _showHeatmap,
                    onChanged: (value) {
                      setModalState(() {
                        _showHeatmap = value;
                      });
                      setState(() {
                        _showHeatmap = value;
                      });
                    },
                  ),
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
                        await _loadHeatmapData();
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