import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/trip.dart';
import '../theme/app_theme.dart';
import 'start_trip_screen.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<Trip> _trips = [];
  bool _isLoading = true;
  bool _hasActiveTrip = false;

  @override
  void initState() {
    super.initState();
    _loadTripHistory();
  }

  Future<void> _loadTripHistory() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await _apiService.getTripHistory();
      final List<dynamic> tripsData = response['trips'] ?? [];
      final trips = tripsData.map((json) => Trip.fromJson(json as Map<String, dynamic>)).toList();
      
      setState(() {
        _trips = trips;
        _hasActiveTrip = trips.any((trip) => trip.isActive);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load trip history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _endActiveTrip() async {
    try {
      await _apiService.endTrip();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip ended successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadTripHistory(); // Reload to update the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEndTripDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Current Trip'),
        content: const Text('Are you sure you want to end your current trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _endActiveTrip();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.redPrimary),
            child: const Text('End Trip', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTrip(Trip trip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [AppColors.redPrimary.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _showEndTripDialog,
                    icon: const Icon(Icons.stop_circle),
                    color: AppColors.redPrimary,
                    tooltip: 'End Trip',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.redPrimary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.destination,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (trip.itinerary != null) ...[
                const SizedBox(height: 8),
                Text(
                  trip.itinerary!,
                  style: TextStyle(
                    color: AppColors.greyText,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: AppColors.greyText),
                  const SizedBox(width: 4),
                  Text(
                    'Started ${_formatDate(trip.startDate)}',
                    style: TextStyle(
                      color: AppColors.greyText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripItem(Trip trip) {
    if (trip.isActive) {
      return _buildActiveTrip(trip);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: trip.isCompleted 
              ? Colors.green.shade100 
              : Colors.grey.shade100,
          child: Icon(
            trip.isCompleted ? Icons.check : Icons.cancel,
            color: trip.isCompleted ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(
          trip.destination,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trip.itinerary != null) 
              Text(
                trip.itinerary!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              '${_formatDate(trip.startDate)} • ${trip.formattedDuration}',
              style: TextStyle(
                color: AppColors.greyText,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: trip.isCompleted 
                ? Colors.green.shade100 
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            trip.status.toUpperCase(),
            style: TextStyle(
              color: trip.isCompleted ? Colors.green.shade700 : Colors.grey.shade700,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip History'),
        backgroundColor: AppColors.redPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadTripHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadTripHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trips.length,
                    itemBuilder: (context, index) {
                      return _buildTripItem(_trips[index]);
                    },
                  ),
                ),
      floatingActionButton: !_hasActiveTrip
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StartTripScreen()),
                );
                if (result == true) {
                  _loadTripHistory(); // Refresh the list
                }
              },
              backgroundColor: AppColors.redPrimary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Start Trip',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 80,
              color: AppColors.greyText,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Trips Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start your first trip to begin tracking your journeys',
              style: TextStyle(
                color: AppColors.greyText,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StartTripScreen()),
                );
                if (result == true) {
                  _loadTripHistory();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.redPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Start Your First Trip'),
            ),
          ],
        ),
      ),
    );
  }
}