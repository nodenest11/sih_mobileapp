import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alert.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

class NotificationScreen extends StatefulWidget {
  final String touristId;
  final List<Alert> initialAlerts;

  const NotificationScreen({
    super.key,
    required this.touristId,
    required this.initialAlerts,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ApiService _apiService = ApiService();
  List<Alert> _alerts = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  AlertType? _selectedFilter;
  
  @override
  void initState() {
    super.initState();
    _alerts = List.from(widget.initialAlerts);
    _markAllAsRead();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final touristIdInt = int.tryParse(widget.touristId);
      if (touristIdInt != null) {
        final alerts = await _apiService.getAlerts(touristIdInt);
        setState(() {
          _alerts = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load notifications: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshAlerts() async {
    setState(() {
      _isRefreshing = true;
    });
    await _loadAlerts();
    setState(() {
      _isRefreshing = false;
    });
  }

  Future<void> _markAllAsRead() async {
    // Mark all unread alerts as read
    final unreadAlerts = _alerts.where((alert) => !alert.isRead).toList();
    if (unreadAlerts.isNotEmpty) {
      try {
        // Update alerts as read on the server
        for (final alert in unreadAlerts) {
          await _apiService.markAlertAsRead(alert.id);
        }
        
        // Update local state
        setState(() {
          _alerts = _alerts.map((alert) {
            return alert.copyWith(isRead: true);
          }).toList();
        });
      } catch (e) {
        // Handle error silently for now
        AppLogger.warning('Failed to mark alerts as read');
      }
    }
  }

  Future<void> _deleteAlert(String alertId) async {
    try {
      await _apiService.deleteAlert(alertId);
      setState(() {
        _alerts.removeWhere((alert) => alert.id == alertId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notification: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Alert> get _filteredAlerts {
    if (_selectedFilter == null) {
      return _alerts;
    }
    return _alerts.where((alert) => alert.type == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshAlerts,
            icon: _isRefreshing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<AlertType?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter notifications',
            onSelected: (AlertType? filter) {
              setState(() {
                _selectedFilter = filter;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Notifications'),
              ),
              ...AlertType.values.map((type) => PopupMenuItem(
                value: type,
                child: Text(_getAlertTypeDisplayName(type)),
              )),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAlerts,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _alerts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final filteredAlerts = _filteredAlerts;
    
    if (filteredAlerts.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        if (_selectedFilter != null) _buildFilterChip(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredAlerts.length,
            itemBuilder: (context, index) {
              final alert = filteredAlerts[index];
              return _buildNotificationCard(alert);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Chip(
        label: Text('Filtered by: ${_getAlertTypeDisplayName(_selectedFilter!)}'),
        onDeleted: () {
          setState(() {
            _selectedFilter = null;
          });
        },
        deleteIcon: const Icon(Icons.close, size: 18),
        backgroundColor: Colors.blue.shade50,
        side: BorderSide(color: Colors.blue.shade200),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedFilter != null 
                ? Icons.filter_list_off 
                : Icons.notifications_none,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter != null
                ? 'No notifications for this filter'
                : 'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter != null
                ? 'Try changing the filter or check back later'
                : 'You\'ll see important updates and alerts here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Alert alert) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getSeverityColor(alert.severity).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAlertDetails(alert),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getSeverityColor(alert.severity).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getAlertTypeIcon(alert.type),
                      color: _getSeverityColor(alert.severity),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                alert.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _showDeleteConfirmation(alert);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 18),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alert.message,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getTypeColor(alert.type).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getTypeColor(alert.type).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                _getAlertTypeDisplayName(alert.type),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _getTypeColor(alert.type),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatTimestamp(alert.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  void _showAlertDetails(Alert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getSeverityColor(alert.severity).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getAlertTypeIcon(alert.type),
                color: _getSeverityColor(alert.severity),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                alert.title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert.message,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM dd, yyyy at hh:mm a').format(alert.timestamp),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (alert.location != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Location: ${alert.location!.latitude.toStringAsFixed(4)}, ${alert.location!.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getSeverityColor(alert.severity).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_getSeverityDisplayName(alert.severity)} Priority',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _getSeverityColor(alert.severity),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Alert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: Text('Are you sure you want to delete "${alert.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAlert(alert.id);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return DateFormat('MMM dd').format(timestamp);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  IconData _getAlertTypeIcon(AlertType type) {
    switch (type) {
      case AlertType.panic:
        return Icons.crisis_alert;
      case AlertType.geoFence:
        return Icons.location_on;
      case AlertType.safety:
        return Icons.security;
      case AlertType.general:
        return Icons.info;
      case AlertType.emergency:
        return Icons.emergency;
    }
  }

  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return Colors.blue;
      case AlertSeverity.medium:
        return Colors.orange;
      case AlertSeverity.high:
        return Colors.red;
      case AlertSeverity.critical:
        return Colors.red.shade800;
    }
  }

  Color _getTypeColor(AlertType type) {
    switch (type) {
      case AlertType.panic:
        return Colors.red;
      case AlertType.geoFence:
        return Colors.orange;
      case AlertType.safety:
        return Colors.green;
      case AlertType.general:
        return Colors.blue;
      case AlertType.emergency:
        return Colors.red.shade800;
    }
  }

  String _getAlertTypeDisplayName(AlertType type) {
    switch (type) {
      case AlertType.panic:
        return 'Panic Alert';
      case AlertType.geoFence:
        return 'Geofence Alert';
      case AlertType.safety:
        return 'Safety Alert';
      case AlertType.general:
        return 'General';
      case AlertType.emergency:
        return 'Emergency';
    }
  }

  String _getSeverityDisplayName(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return 'Low';
      case AlertSeverity.medium:
        return 'Medium';
      case AlertSeverity.high:
        return 'High';
      case AlertSeverity.critical:
        return 'Critical';
    }
  }
}