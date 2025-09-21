import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/tourist.dart';
import '../models/location.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../widgets/panic_button.dart';
import '../widgets/safety_score_widget.dart';
import '../widgets/search_bar.dart';

class MapScreen extends StatefulWidget {
  final Tourist tourist;

  const MapScreen({super.key, required this.tourist});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final ApiService _apiService = ApiService();
  
  LatLng _currentLocation = const LatLng(28.6139, 77.2090); // Default: Delhi
  List<HeatmapPoint> _heatmapData = [];
  List<RestrictedZone> _restrictedZones = [];
  bool _isLoading = true;
  
  // Heatmap settings
  int _heatmapHours = 24;
  bool _includeAlerts = true;
  double _gridSize = 0.005;
  
  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      // Start location tracking
      await _locationService.startLocationTracking();
      
      // Get current location
      LocationData location = await _locationService.getCurrentLocation();
      setState(() {
        _currentLocation = LatLng(location.latitude, location.longitude);
      });

      // Load heatmap data
      _loadHeatmapData();
      
      // Load restricted zones
      _loadRestrictedZones();
      
      // Listen to location updates
      _locationService.locationStream.listen((location) {
        setState(() {
          _currentLocation = LatLng(location.latitude, location.longitude);
        });
        
        // Update location on backend
        _updateLocationOnBackend(location.latitude, location.longitude);
        
        // Check geo-fencing
        _checkGeofencing(location.latitude, location.longitude);
      });
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing map: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Show error dialog
      if (mounted) {
        _showErrorDialog('Location Error', 
          'Unable to access location. Please enable location services and restart the app.');
      }
    }
  }

  Future<void> _loadHeatmapData() async {
    try {
      // Load heatmap with current settings
      HeatmapResponse heatmapResponse = await _apiService.getHeatmapData(
        hours: _heatmapHours,
        includeAlerts: _includeAlerts,
        gridSize: _gridSize,
      );
      
      setState(() {
        _heatmapData = heatmapResponse.points;
      });
      
      debugPrint('Loaded ${heatmapResponse.points.length} heatmap points from ${heatmapResponse.metadata.timeWindowHours}h window');
    } catch (e) {
      debugPrint('Error loading heatmap data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load heatmap data: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadRestrictedZones() async {
    try {
      List<RestrictedZone> zones = await _apiService.getRestrictedZones();
      setState(() {
        _restrictedZones = zones;
      });
    } catch (e) {
      debugPrint('Error loading restricted zones: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load restricted zones: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _updateLocationOnBackend(double lat, double lon) async {
    try {
      await _apiService.updateLocation(widget.tourist.id, lat, lon);
    } catch (e) {
      debugPrint('Failed to update location on backend: $e');
      // Don't show user notification for location updates as they happen frequently
      // Just log the error
    }
  }

  void _checkGeofencing(double lat, double lon) {
    for (RestrictedZone zone in _restrictedZones) {
      // Simple point-in-polygon check for geo-fencing
      if (_isPointInPolygon(lat, lon, zone.polygonCoordinates)) {
        _showGeofencingAlert(zone.name);
        break;
      }
    }
  }

  bool _isPointInPolygon(double lat, double lon, List<LatLng> polygon) {
    bool inside = false;
    int j = polygon.length - 1;
    
    for (int i = 0; i < polygon.length; i++) {
      if (((polygon[i].longitude > lon) != (polygon[j].longitude > lon)) &&
          (lat < (polygon[j].latitude - polygon[i].latitude) * 
           (lon - polygon[i].longitude) / 
           (polygon[j].longitude - polygon[i].longitude) + polygon[i].latitude)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  void _showGeofencingAlert(String zoneName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Restricted Area Warning'),
            ],
          ),
          content: Text('⚠️ You have entered a restricted/high-risk area: $zoneName'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _onSearchLocation(String query) async {
    try {
      final result = await _apiService.searchLocation(query);
      if (result != null) {
        LatLng newLocation = LatLng(result['lat'], result['lon']);
        _mapController.move(newLocation, 15.0);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location not found')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching location: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.tourist.name}'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _showHeatmapSettings,
            tooltip: 'Heatmap Settings',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15.0,
              maxZoom: 18.0,
              minZoom: 3.0,
            ),
            children: [
              // OpenStreetMap tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mobile',
              ),
              
              // Heatmap overlay with risk-based colors
              if (_heatmapData.isNotEmpty)
                CircleLayer(
                  circles: _heatmapData.map((point) {
                    // Color based on risk level
                    Color color;
                    switch (point.riskLevel) {
                      case 'high':
                        color = Colors.red;
                        break;
                      case 'medium':
                        color = Colors.orange;
                        break;
                      case 'low':
                      default:
                        color = Colors.yellow;
                        break;
                    }
                    
                    // Scale radius based on intensity (0-100)
                    double radiusMultiplier = (point.intensity / 100).clamp(0.2, 1.0);
                    
                    return CircleMarker(
                      point: point.latLng,
                      radius: 30 + (70 * radiusMultiplier), // 30-100m radius
                      useRadiusInMeter: true,
                      color: color.withValues(alpha: 0.3 + (0.4 * radiusMultiplier)),
                      borderColor: color.withValues(alpha: 0.8),
                      borderStrokeWidth: 2,
                    );
                  }).toList(),
                ),
              
              // Restricted zones
              if (_restrictedZones.isNotEmpty)
                PolygonLayer(
                  polygons: _restrictedZones.map((zone) {
                    return Polygon(
                      points: zone.polygonCoordinates,
                      color: Colors.red.withOpacity(0.2),
                      borderColor: Colors.red,
                      borderStrokeWidth: 2,
                    );
                  }).toList(),
                ),
              
              // Current location marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 60,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Search bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: LocationSearchBar(onSearch: _onSearchLocation),
          ),
          
          // Safety score widget
          Positioned(
            top: 80,
            right: 16,
            child: SafetyScoreWidget(touristId: widget.tourist.id),
          ),
          
          // Panic button
          Positioned(
            bottom: 100,
            right: 16,
            child: PanicButton(
              touristId: widget.tourist.id,
              currentLocation: _currentLocation,
            ),
          ),
        ],
      ),
    );
  }

  void _showHeatmapSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Heatmap Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Time window setting
                  Row(
                    children: [
                      const Text('Time Window: '),
                      Expanded(
                        child: DropdownButton<int>(
                          value: _heatmapHours,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('Last 1 hour')),
                            DropdownMenuItem(value: 6, child: Text('Last 6 hours')),
                            DropdownMenuItem(value: 12, child: Text('Last 12 hours')),
                            DropdownMenuItem(value: 24, child: Text('Last 24 hours')),
                            DropdownMenuItem(value: 72, child: Text('Last 3 days')),
                            DropdownMenuItem(value: 168, child: Text('Last 7 days')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              _heatmapHours = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Include alerts setting
                  Row(
                    children: [
                      const Text('Include Alert Hotspots: '),
                      Switch(
                        value: _includeAlerts,
                        onChanged: (value) {
                          setDialogState(() {
                            _includeAlerts = value;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Grid size setting
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Detail Level: ${_gridSize == 0.001 ? 'Very High' : _gridSize == 0.005 ? 'High' : _gridSize == 0.01 ? 'Medium' : 'Low'}'),
                      Slider(
                        value: _gridSize,
                        min: 0.001,
                        max: 0.1,
                        divisions: 3,
                        onChanged: (value) {
                          setDialogState(() {
                            _gridSize = value;
                          });
                        },
                      ),
                      const Text(
                        'Higher detail may show more points but take longer to load',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {}); // Update the main state
                    _loadHeatmapData(); // Reload heatmap with new settings
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}