# Proximity Alert Feature

## Overview
The Proximity Alert feature automatically notifies tourists when they are near:
- **Unresolved Panic Alerts** (emergency situations reported by other tourists)
- **Restricted Zones** (dangerous or restricted areas)

This feature enhances tourist safety by providing real-time awareness of nearby hazards.

---

## Features

### 🚨 Panic Alert Monitoring
- **Automatic Detection**: Checks for panic alerts every 30 seconds
- **Only Unresolved Alerts**: Shows only pending/active emergencies (not resolved ones)
- **Distance-Based Filtering**: Alerts within 5km radius
- **Severity Levels**:
  - **Critical**: Within 1km (red notification, vibration, full-screen alert)
  - **High**: Within 2.5km (orange notification, vibration)
  - **Medium**: Within 5km (yellow notification)

### 🛑 Restricted Zone Monitoring
- **Geofencing**: Real-time monitoring of restricted zones
- **Proximity Alerts**:
  - **Inside Zone**: Immediate alert when entering
  - **Critical**: Within 100m (strong vibration)
  - **Nearby**: Within 500m (warning vibration)

### 📱 Notification System
- **Push Notifications**: Even when app is backgrounded
- **In-App Alerts**: Visual cards on home screen
- **Haptic Feedback**: Vibration patterns based on severity
- **Smart Deduplication**: Doesn't spam same alert multiple times

---

## Technical Implementation

### New Files Created

#### 1. `proximity_alert_service.dart`
```dart
lib/services/proximity_alert_service.dart
```
**Purpose**: Core service for monitoring proximity to panic alerts and zones

**Key Features**:
- Singleton pattern for app-wide access
- Background monitoring every 30 seconds
- Distance calculation using Haversine formula
- Notification channel management
- Event streaming for real-time updates

**Configuration**:
```dart
static const Duration _checkInterval = Duration(seconds: 30);
static const double _panicAlertRadiusKm = 5.0;
static const double _criticalDistanceKm = 1.0;
static const double _warningDistanceKm = 2.5;
```

#### 2. `proximity_alert_widget.dart`
```dart
lib/widgets/proximity_alert_widget.dart
```
**Purpose**: UI components for displaying proximity alerts

**Components**:
- `ProximityAlertWidget`: Card widget for alert list
- `ProximityAlertDialog`: Full dialog with alert details

---

## Integration

### Home Screen Integration
**File**: `lib/screens/home_screen.dart`

**Changes**:
1. Import proximity alert service and widget
2. Initialize service on app start
3. Listen to proximity events
4. Display alerts in dedicated section
5. Show dialog for critical alerts

**Code Flow**:
```dart
_initializeProximityAlerts()
  → _proximityAlertService.startMonitoring()
  → _proximityAlertService.events.listen()
  → Update _proximityAlerts list
  → Show dialog if severity == 'critical'
```

---

## API Integration

### Public Panic Alerts Endpoint
**Endpoint**: `GET /api/public/panic-alerts`

**Default Behavior** (No authentication required):
```http
GET /api/public/panic-alerts?limit=100&hours_back=24
```

**Response** (Only unresolved alerts):
```json
{
  "total_alerts": 4,
  "active_count": 1,
  "unresolved_count": 3,
  "resolved_count": 0,
  "alerts": [
    {
      "alert_id": 353,
      "type": "sos",
      "severity": "critical",
      "title": "🚨 SOS Emergency Alert",
      "location": {
        "lat": 23.4716367,
        "lon": 72.39096
      },
      "timestamp": "2025-10-03T03:27:14.960120+00:00",
      "time_ago": "1:10:20",
      "status": "active",
      "resolved": false
    }
  ]
}
```

**Key Points**:
- ✅ Public endpoint (no authentication)
- ✅ Only shows **unresolved** alerts by default
- ✅ Anonymized data (no personal information)
- ✅ Includes location for map display
- ✅ Status: `active` (<1hr) or `older` (1-24hr)

---

## User Experience

### Home Screen Display
```
┌─────────────────────────────────┐
│ 🚨 Nearby Alerts            [3] │
├─────────────────────────────────┤
│ ⚠️  Emergency situations or      │
│     restricted zones detected    │
│     near your location          │
├─────────────────────────────────┤
│ 🚨 Emergency Alert Nearby       │
│ Unresolved emergency reported   │
│ 2.3km away (45m ago)           │
│ [📍 2.3km] [🕐 45m ago]         │
├─────────────────────────────────┤
│ ⚠️  Restricted Zone Nearby      │
│ You are approaching a           │
│ restricted zone                 │
│ [📍 0.8km] [🕐 2m ago]          │
└─────────────────────────────────┘
```

### Dialog for Critical Alerts
```
┌─────────────────────────────────┐
│ 🚨 Emergency Alert Nearby       │
├─────────────────────────────────┤
│ [CRITICAL]                      │
│                                 │
│ Unresolved emergency reported   │
│ 0.8km away (15 minutes ago)    │
│                                 │
│ Distance: 0.8km                 │
│ Detected: 15 minutes ago        │
│ Status: Active (<1hr)           │
│                                 │
│ ⚠️ Stay alert! An emergency     │
│    was reported very close to   │
│    your location. Consider      │
│    moving to a safer area.      │
├─────────────────────────────────┤
│ [Dismiss]  [View on Map]        │
└─────────────────────────────────┘
```

---

## Notification Channels

### Android Notification Channels
```dart
1. proximity_panic_alerts
   - Name: "Nearby Panic Alerts"
   - Importance: Max
   - Sound: Enabled
   - Vibration: Enabled
   - LED: Red

2. proximity_zone_alerts
   - Name: "Nearby Restricted Zones"
   - Importance: High
   - Sound: Enabled
   - Vibration: Enabled
   - LED: Orange
```

---

## Privacy & Security

### Data Privacy
✅ **Anonymized Data**: No personal information in alerts
✅ **Location Only**: Only GPS coordinates, no names/emails
✅ **Public Endpoint**: No authentication required for alerts
✅ **Aggregated Data**: Shows general area, not exact locations

### Smart Filtering
✅ **Deduplication**: Tracks shown alerts, no spam
✅ **Distance-Based**: Only shows relevant nearby alerts
✅ **Time-Filtered**: Only recent alerts (last 24 hours)
✅ **Status-Aware**: Only unresolved alerts shown

---

## Performance

### Optimization Strategies
1. **Batch Processing**: Checks all alerts in single API call
2. **Smart Caching**: Acknowledged alerts tracked locally
3. **Periodic Updates**: Every 30 seconds (not real-time to save battery)
4. **Distance Pre-filtering**: Backend filters by time, app filters by distance
5. **Lazy Rendering**: Only renders visible alert widgets

### Battery Impact
- **Minimal**: Uses existing location service
- **Efficient**: 30-second check interval
- **Smart**: Reuses geofencing service monitoring

---

## Testing

### Manual Testing Steps
1. **Start app and login**
2. **Go to home screen**
3. **Wait for location tracking to start**
4. **Proximity alerts section appears** if alerts nearby
5. **Tap alert card** to view details
6. **Tap "View on Map"** (future: navigates to map)
7. **Dismiss alert** using X button

### Test Scenarios
- ✅ Alert within 1km (critical)
- ✅ Alert within 2.5km (high)
- ✅ Alert within 5km (medium)
- ✅ Multiple alerts at different distances
- ✅ Alert dismissed and not shown again
- ✅ New alert appears while app is open
- ✅ Background notification when alert detected

---

## Configuration

### Adjustable Parameters

**Check Interval** (in `proximity_alert_service.dart`):
```dart
static const Duration _checkInterval = Duration(seconds: 30);
// Change to 60 for less battery usage
// Change to 15 for more real-time updates
```

**Alert Radius** (in `proximity_alert_service.dart`):
```dart
static const double _panicAlertRadiusKm = 5.0;
// Increase for wider area coverage
// Decrease for more immediate threats only
```

**Distance Thresholds**:
```dart
static const double _criticalDistanceKm = 1.0;
static const double _warningDistanceKm = 2.5;
// Adjust based on urban vs rural areas
```

---

## Future Enhancements

### Planned Features
- [ ] **Map Integration**: Tap "View on Map" navigates to map screen
- [ ] **Alert Categories**: Filter by alert type (SOS, panic, zone)
- [ ] **Custom Radius**: Let users set their own alert radius
- [ ] **Notification Settings**: Per-severity notification controls
- [ ] **Alert History**: View dismissed alerts
- [ ] **Share Alerts**: Share alert with contacts
- [ ] **Directions**: "Navigate to safer area" button
- [ ] **Offline Mode**: Cache alerts for offline viewing

### Possible Improvements
- WebSocket for real-time updates (battery trade-off)
- Machine learning for alert priority
- Crowd-sourced alert verification
- Emergency contact auto-notification
- Integration with local emergency services

---

## Troubleshooting

### Common Issues

**1. No alerts showing**
- ✅ Check location permissions
- ✅ Ensure location tracking is active
- ✅ Verify network connection
- ✅ Check if any alerts exist in backend

**2. Duplicate notifications**
- ✅ Service tracking works correctly
- ✅ Should not happen - file bug if it does

**3. Battery drain**
- ✅ Increase check interval to 60 seconds
- ✅ Reduce alert radius
- ✅ Disable when not needed

**4. Alerts not updating**
- ✅ Check background service is running
- ✅ Verify API endpoint is accessible
- ✅ Check logs for errors

---

## Dependencies

### Required Packages
```yaml
flutter_local_notifications: ^19.4.2  # Push notifications
geolocator: ^14.0.2                   # Location services
vibration: ^3.1.4                     # Haptic feedback
latlong2: ^0.9.1                      # Coordinate handling
```

### Permissions Required
```xml
<!-- Android -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.VIBRATE" />
```

---

## Code Examples

### Initialize Service
```dart
final proximityService = ProximityAlertService.instance;
await proximityService.initialize();
await proximityService.startMonitoring();
```

### Listen to Events
```dart
proximityService.events.listen((event) {
  print('Alert: ${event.title}');
  print('Distance: ${event.distanceKm}km');
  print('Severity: ${event.severity}');
});
```

### Stop Monitoring
```dart
proximityService.stopMonitoring();
```

### Reset Acknowledged Alerts
```dart
proximityService.resetAcknowledged();
```

---

## Conclusion

The Proximity Alert feature provides critical safety awareness to tourists by:
- ✅ Monitoring nearby unresolved emergencies
- ✅ Alerting about restricted zones
- ✅ Providing real-time notifications
- ✅ Maintaining privacy and security
- ✅ Optimizing battery usage

This enhances the overall safety experience while maintaining performance and user privacy.
