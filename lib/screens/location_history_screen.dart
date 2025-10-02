import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../models/location.dart';
import '../theme/app_theme.dart';

class LocationHistoryScreen extends StatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();
  late TabController _tabController;
  
  List<LocationData> _locations = [];
  bool _isLoading = true;
  String _selectedFilter = 'Today';
  
  final List<String> _timeFilters = ['Today', 'This Week', 'This Month', 'All Time'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLocationHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationHistory() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await _apiService.getLocationHistory(limit: 100);
      final List<dynamic> locationData = response['locations'] ?? [];
      final locations = locationData
          .map((json) => LocationData.fromJson(json as Map<String, dynamic>))
          .where(_filterByTime)
          .toList();
      
      setState(() {
        _locations = locations;
        _isLoading = false;
      });

      // Center map on latest location if available
      if (_locations.isNotEmpty && mounted) {
        final latest = _locations.first;
        _mapController.move(LatLng(latest.latitude, latest.longitude), 15.0);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load location history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _filterByTime(LocationData location) {
    final now = DateTime.now();
    final locationTime = location.timestamp;
    
    switch (_selectedFilter) {
      case 'Today':
        return locationTime.day == now.day && 
               locationTime.month == now.month && 
               locationTime.year == now.year;
      case 'This Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return locationTime.isAfter(weekStart.subtract(const Duration(days: 1)));
      case 'This Month':
        return locationTime.month == now.month && locationTime.year == now.year;
      case 'All Time':
      default:
        return true;
    }
  }

  List<Marker> _buildMapMarkers() {
    if (_locations.isEmpty) return [];
    
    final markers = <Marker>[];
    
    // Add path markers
    for (int i = 0; i < _locations.length; i++) {
      final location = _locations[i];
      final isFirst = i == 0;
      final isLast = i == _locations.length - 1;
      
      markers.add(
        Marker(
          point: LatLng(location.latitude, location.longitude),
          child: Container(
            width: isFirst || isLast ? 12 : 8,
            height: isFirst || isLast ? 12 : 8,
            decoration: BoxDecoration(
              color: isFirst 
                  ? Colors.green 
                  : isLast 
                      ? AppColors.primary 
                      : Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      );
    }
    
    return markers;
  }

  List<Polyline> _buildMapPolylines() {
    if (_locations.length < 2) return [];
    
    final points = _locations
        .map((loc) => LatLng(loc.latitude, loc.longitude))
        .toList();
    
    return [
      Polyline(
        points: points,
        strokeWidth: 3.0,
        color: AppColors.primary.withValues(alpha: 0.7),
      ),
    ];
  }

  Widget _buildMapView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_locations.isEmpty) {
      return _buildEmptyState('No location data for selected time period');
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _locations.isNotEmpty 
            ? LatLng(_locations.first.latitude, _locations.first.longitude)
            : const LatLng(28.6139, 77.2090), // Default to Delhi
        initialZoom: 15.0,
        maxZoom: 18.0,
        minZoom: 1.0,
      ),
      children: [
        TileLayer(
          urlTemplate: ApiService.osmTileUrl,
          userAgentPackageName: 'com.safehorizon.tourist',
        ),
        PolylineLayer(polylines: _buildMapPolylines()),
        MarkerLayer(markers: _buildMapMarkers()),
      ],
    );
  }

  Widget _buildListView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_locations.isEmpty) {
      return _buildEmptyState('No location data for selected time period');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _locations.length,
      itemBuilder: (context, index) {
        final location = _locations[index];
        final isFirst = index == 0;
        final isLast = index == _locations.length - 1;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isFirst 
                  ? Colors.green.shade100 
                  : isLast 
                      ? AppColors.primaryLight 
                      : Colors.blue.shade100,
              child: Icon(
                isFirst 
                    ? Icons.play_arrow 
                    : isLast 
                        ? Icons.stop 
                        : Icons.location_on,
                color: isFirst 
                    ? Colors.green 
                    : isLast 
                        ? AppColors.primary 
                        : Colors.blue,
                size: 20,
              ),
            ),
            title: Text(
              '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDateTime(location.timestamp)),
                if (location.speed != null)
                  Text(
                    'Speed: ${location.speed!.toStringAsFixed(1)} km/h',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                if (location.accuracy != null)
                  Text(
                    'Accuracy: ±${location.accuracy!.toStringAsFixed(0)}m',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              onPressed: () {
                _mapController.move(
                  LatLng(location.latitude, location.longitude), 
                  16.0,
                );
                _tabController.animateTo(0); // Switch to map tab
              },
              icon: const Icon(Icons.map),
              tooltip: 'Show on map',
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Location Data',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final locationDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String datePrefix;
    if (locationDate == today) {
      datePrefix = 'Today';
    } else if (locationDate == today.subtract(const Duration(days: 1))) {
      datePrefix = 'Yesterday';
    } else {
      datePrefix = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    
    final timeString = '${dateTime.hour.toString().padLeft(2, '0')}:'
                      '${dateTime.minute.toString().padLeft(2, '0')}';
    
    return '$datePrefix at $timeString';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location History'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
              _loadLocationHistory();
            },
            itemBuilder: (context) => _timeFilters.map((filter) => PopupMenuItem(
              value: filter,
              child: Text(filter),
            )).toList(),
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _locations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('No location history'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _locations.length,
                  itemBuilder: (context, index) {
                    final location = _locations[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text('${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}'),
                      subtitle: Text(location.timestamp.toString()),
                    );
                  },
                ),
    );
  }
}
