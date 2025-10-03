# Proximity Alert System - Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER EXPERIENCE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  📱 Home Screen                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Safety Score Widget                                    │    │
│  ├────────────────────────────────────────────────────────┤    │
│  │  Location Status                                        │    │
│  ├────────────────────────────────────────────────────────┤    │
│  │  🚨 Nearby Alerts                               [3]     │    │
│  │  ────────────────────────────────────────────────────  │    │
│  │  ⚠️ Emergency situations detected nearby               │    │
│  │                                                         │    │
│  │  🚨 Emergency Alert Nearby                             │    │
│  │  Unresolved emergency 2.3km away                       │    │
│  │  [📍 2.3km] [🕐 45m] [✕]                               │    │
│  │                                                         │    │
│  │  🛑 Restricted Zone                                    │    │
│  │  Approaching dangerous area                            │    │
│  │  [📍 0.8km] [🕐 2m] [✕]                                │    │
│  └────────────────────────────────────────────────────────┘    │
│                           ↕                                      │
│                    User Interaction                             │
│                    (Tap / Dismiss)                              │
└─────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                      STATE MANAGEMENT                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  _HomeScreenState                                               │
│  ├─ _proximityAlerts: List<ProximityAlertEvent>                │
│  ├─ _proximityAlertService: ProximityAlertService.instance     │
│  │                                                              │
│  └─ Methods:                                                    │
│     ├─ _initializeProximityAlerts()                            │
│     ├─ _showProximityAlertDialog(event)                        │
│     └─ _buildProximityAlertsSection()                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                    BUSINESS LOGIC LAYER                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ProximityAlertService (Singleton)                              │
│  ├─ Configuration:                                              │
│  │  ├─ Check Interval: 30 seconds                              │
│  │  ├─ Alert Radius: 5km                                       │
│  │  ├─ Critical Distance: 1km                                  │
│  │  └─ Warning Distance: 2.5km                                 │
│  │                                                              │
│  ├─ State:                                                      │
│  │  ├─ _acknowledgedPanicAlerts: Set<int>                      │
│  │  ├─ _acknowledgedZones: Set<String>                         │
│  │  └─ _isMonitoring: bool                                     │
│  │                                                              │
│  ├─ Methods:                                                    │
│  │  ├─ initialize()                                            │
│  │  ├─ startMonitoring()                                       │
│  │  ├─ stopMonitoring()                                        │
│  │  ├─ _checkProximity()                                       │
│  │  ├─ _checkNearbyPanicAlerts()                              │
│  │  ├─ _showPanicAlertNotification()                          │
│  │  └─ _triggerHapticFeedback()                               │
│  │                                                              │
│  └─ Event Stream:                                               │
│     └─ events: Stream<ProximityAlertEvent>                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
            ↕                            ↕
┌──────────────────────┐    ┌────────────────────────────┐
│   Geofencing         │    │   Notification System      │
│   Service            │    │                            │
├──────────────────────┤    ├────────────────────────────┤
│ - Zone monitoring    │    │ - Push notifications       │
│ - Polygon detection  │    │ - Haptic feedback         │
│ - Entry/Exit events  │    │ - Vibration patterns      │
└──────────────────────┘    └────────────────────────────┘
            ↕
┌─────────────────────────────────────────────────────────────────┐
│                        DATA LAYER                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ApiService                                                      │
│  └─ getPublicPanicAlerts(limit, hoursBack)                     │
│     ├─ Endpoint: /api/public/panic-alerts                       │
│     ├─ Method: GET (No Auth Required)                           │
│     ├─ Default: show_resolved=false                             │
│     └─ Returns: Only unresolved alerts                          │
│                                                                  │
│  LocationService                                                 │
│  └─ getCurrentLocation()                                         │
│     └─ Returns: Position (lat, lon)                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                      BACKEND API                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  GET /api/public/panic-alerts                                   │
│  ├─ Query Params:                                               │
│  │  ├─ limit: 100                                               │
│  │  ├─ hours_back: 24                                           │
│  │  └─ show_resolved: false (default)                           │
│  │                                                              │
│  └─ Response:                                                   │
│     {                                                           │
│       "total_alerts": 4,                                        │
│       "active_count": 1,                                        │
│       "unresolved_count": 3,                                    │
│       "alerts": [                                               │
│         {                                                       │
│           "alert_id": 353,                                      │
│           "type": "sos",                                        │
│           "severity": "critical",                               │
│           "location": { "lat": 23.47, "lon": 72.39 },          │
│           "timestamp": "2025-10-03T03:27:14Z",                  │
│           "status": "active",                                   │
│           "resolved": false                                     │
│         }                                                       │
│       ]                                                         │
│     }                                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Sequence

```
1. APP STARTUP
   └─ HomeScreen.initState()
      └─ _initializeProximityAlerts()
         ├─ ProximityAlertService.initialize()
         │  └─ Create notification channels
         └─ ProximityAlertService.startMonitoring()
            └─ Start Timer (every 30s)

2. PERIODIC CHECK (Every 30 seconds)
   └─ _checkProximity()
      ├─ Geolocator.getCurrentPosition()
      │  └─ Returns: Position(lat: 23.47, lon: 72.39)
      │
      └─ _checkNearbyPanicAlerts(currentLocation)
         ├─ ApiService.getPublicPanicAlerts()
         │  └─ GET /api/public/panic-alerts?limit=100&hours_back=24
         │     └─ Returns: [alert1, alert2, alert3] (only unresolved)
         │
         ├─ Filter by distance (< 5km)
         │  └─ nearbyAlerts = [alert1, alert3]
         │
         ├─ Calculate severity based on distance
         │  ├─ alert1: 0.8km → critical
         │  └─ alert3: 3.2km → medium
         │
         ├─ Check if already acknowledged
         │  └─ Skip if already shown
         │
         └─ For each new alert:
            ├─ Create ProximityAlertEvent
            ├─ Add to _acknowledgedPanicAlerts
            ├─ Emit to event stream
            ├─ Show notification
            └─ Trigger vibration

3. EVENT HANDLING
   └─ HomeScreen listens to events
      ├─ proximityService.events.listen()
      │  └─ On new event:
      │     ├─ setState(() { _proximityAlerts.add(event) })
      │     └─ if (event.severity == 'critical')
      │        └─ showDialog(ProximityAlertDialog)
      │
      └─ UI Update:
         └─ _buildProximityAlertsSection()
            └─ Display ProximityAlertWidget for each alert

4. USER INTERACTION
   ├─ Tap alert card:
   │  └─ Show ProximityAlertDialog
   │     ├─ Display details
   │     ├─ Show safety tips
   │     └─ [View on Map] button
   │
   └─ Tap X (dismiss):
      └─ setState(() { _proximityAlerts.remove(alert) })
```

---

## Component Relationships

```
┌────────────────────────────────────────────────────────┐
│                    UI Components                        │
├────────────────────────────────────────────────────────┤
│                                                         │
│  ProximityAlertWidget                                  │
│  ├─ Props:                                             │
│  │  ├─ alert: ProximityAlertEvent                      │
│  │  ├─ onTap: VoidCallback                             │
│  │  └─ onDismiss: VoidCallback                         │
│  └─ Renders:                                           │
│     ├─ Icon (based on type)                            │
│     ├─ Title & Description                             │
│     ├─ Distance badge                                  │
│     └─ Time badge                                      │
│                                                         │
│  ProximityAlertDialog                                  │
│  ├─ Props:                                             │
│  │  └─ alert: ProximityAlertEvent                      │
│  └─ Renders:                                           │
│     ├─ Full alert details                              │
│     ├─ Severity badge                                  │
│     ├─ Safety tips                                     │
│     └─ Action buttons                                  │
│                                                         │
└────────────────────────────────────────────────────────┘
                       ↕ Uses
┌────────────────────────────────────────────────────────┐
│                   Data Models                           │
├────────────────────────────────────────────────────────┤
│                                                         │
│  ProximityAlertEvent                                   │
│  ├─ type: ProximityAlertType                           │
│  ├─ title: String                                      │
│  ├─ description: String                                │
│  ├─ location: LatLng                                   │
│  ├─ distanceKm: double                                 │
│  ├─ severity: String                                   │
│  ├─ timestamp: DateTime                                │
│  └─ metadata: Map<String, dynamic>?                    │
│                                                         │
│  ProximityAlertType (enum)                             │
│  ├─ panicAlert                                         │
│  └─ restrictedZone                                     │
│                                                         │
└────────────────────────────────────────────────────────┘
```

---

## Service Integration Map

```
┌──────────────────────────────────────────────────────┐
│           Existing Services (Reused)                  │
├──────────────────────────────────────────────────────┤
│                                                       │
│  LocationService                                     │
│  └─ Provides: Current user location                 │
│     Used by: ProximityAlertService                   │
│                                                       │
│  GeofencingService                                   │
│  └─ Provides: Restricted zone monitoring            │
│     Complements: ProximityAlertService               │
│                                                       │
│  ApiService                                          │
│  └─ Provides: Public panic alerts API               │
│     Used by: ProximityAlertService                   │
│                                                       │
│  FCMNotificationService                              │
│  └─ Provides: Push notification infrastructure      │
│     Used by: ProximityAlertService                   │
│                                                       │
└──────────────────────────────────────────────────────┘
              ↓ Integrated with
┌──────────────────────────────────────────────────────┐
│              New Service (Added)                      │
├──────────────────────────────────────────────────────┤
│                                                       │
│  ProximityAlertService                               │
│  └─ Provides: Proximity alert monitoring             │
│     ├─ Uses LocationService for position             │
│     ├─ Uses ApiService for alert data                │
│     ├─ Uses FCMNotificationService for notifications │
│     └─ Complements GeofencingService                 │
│                                                       │
└──────────────────────────────────────────────────────┘
```

This architecture ensures clean separation of concerns, reusability, and maintainability! 🎯
