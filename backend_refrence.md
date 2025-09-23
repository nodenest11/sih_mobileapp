# Smart Tourist Safety API - Backend Reference

## 🌐 Base URL
```
Development: http://localhost:8000
Production: https://your-domain.com/api
```

## 📋 Table of Contents
- [Quick Start](#quick-start)
- [Authentication](#authentication)
- [API Endpoints](#api-endpoints)
  - [Tourist Management](#tourist-management)
  - [Location Tracking](#location-tracking)
  - [Alert System](#alert-system)
  - [Admin Functions](#admin-functions)
- [Restricted Zones](#restricted-zones)
- [Data Models](#data-models)
- [Error Handling](#error-handling)
- [Safety Score System](#safety-score-system)
- [Integration Examples](#integration-examples)

---

## 🚀 Quick Start

### API Documentation
- **Interactive Docs**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

### Core Concepts
- **Safety Score System**: 0-100 (100 = safest)
- **Geofencing**: 23 restricted zones across North India
- **Real-time Tracking**: Location updates with timestamps
- **Emergency Alerts**: Panic buttons and zone violations

---

## 🔐 Authentication

Currently **no authentication** required for development. All endpoints are publicly accessible.

**Headers Required:**
```json
{
  "Content-Type": "application/json"
}
```

---

## 📡 API Endpoints

### 🧑‍🤝‍🧑 Tourist Management

#### Register New Tourist
```http
POST /tourists/register
```

**Request Body:**
```json
{
  "name": "Aarav Sharma",
  "contact": "9876543210",
  "trip_info": "Golden Triangle tour (Delhi-Agra-Jaipur)",
  "emergency_contact": "9876543211"
}
```

**Response (201 Created):**
```json
{
  "id": 1,
  "name": "Aarav Sharma",
  "contact": "9876543210",
  "trip_info": "Golden Triangle tour (Delhi-Agra-Jaipur)",
  "emergency_contact": "9876543211",
  "safety_score": 100,
  "created_at": "2025-09-24T10:30:00Z",
  "updated_at": null
}
```

**Validation Rules:**
- `name`: 1-100 characters, required
- `contact`: 10-20 characters (Indian phone numbers), required
- `emergency_contact`: 10-20 characters, required
- `trip_info`: Optional text field

---

#### Get Tourist Details
```http
GET /tourists/{tourist_id}
```

**Response (200 OK):**
```json
{
  "id": 1,
  "name": "Aarav Sharma",
  "contact": "9876543210",
  "trip_info": "Golden Triangle tour (Delhi-Agra-Jaipur)",
  "emergency_contact": "9876543211",
  "safety_score": 80,
  "created_at": "2025-09-24T10:30:00Z",
  "updated_at": "2025-09-24T11:45:00Z"
}
```

**Error Response (404):**
```json
{
  "detail": "Tourist not found"
}
```

---

### 📍 Location Tracking

#### Update Tourist Location
```http
POST /locations/update
```

**Request Body:**
```json
{
  "tourist_id": 1,
  "latitude": 28.6139,
  "longitude": 77.2090
}
```

**Response (201 Created):**
```json
{
  "id": 15,
  "tourist_id": 1,
  "latitude": 28.6139,
  "longitude": 77.2090,
  "timestamp": "2025-09-24T12:15:30Z"
}
```

**Validation Rules:**
- `latitude`: -90 to 90 degrees
- `longitude`: -180 to 180 degrees
- `tourist_id`: Must exist in database

---

#### Get All Latest Locations
```http
GET /locations/all
```

**Response (200 OK):**
```json
[
  {
    "id": 15,
    "tourist_id": 1,
    "latitude": 28.6139,
    "longitude": 77.2090,
    "timestamp": "2025-09-24T12:15:30Z"
  },
  {
    "id": 23,
    "tourist_id": 2,
    "latitude": 15.2993,
    "longitude": 74.1240,
    "timestamp": "2025-09-24T12:10:15Z"
  }
]
```

**Note:** Returns only the latest location for each tourist.

---

### 🚨 Alert System

#### Create Panic Alert
```http
POST /alerts/panic
```

**Request Body:**
```json
{
  "tourist_id": 1,
  "latitude": 28.6139,
  "longitude": 77.2090
}
```

**Response (201 Created):**
```json
{
  "id": 5,
  "tourist_id": 1,
  "type": "panic",
  "message": "PANIC ALERT: Aarav Sharma has triggered an emergency alert at coordinates (28.6139, 77.2090)",
  "timestamp": "2025-09-24T12:20:45Z",
  "status": "active",
  "latitude": 28.6139,
  "longitude": 77.2090
}
```

**Side Effects:**
- Tourist's safety score decreases by 40 points
- Alert is created with status "active"

---

#### Create Geofence Alert
```http
POST /alerts/geofence
```

**Request Body:**
```json
{
  "tourist_id": 1,
  "latitude": 28.6570,
  "longitude": 77.2420,
  "zone_name": "Delhi Red Fort Military Zone"
}
```

**Response (201 Created):**
```json
{
  "id": 6,
  "tourist_id": 1,
  "type": "geofence",
  "message": "GEOFENCE ALERT: Aarav Sharma has entered restricted zone 'Delhi Red Fort Military Zone' at coordinates (28.6570, 77.2420)",
  "timestamp": "2025-09-24T12:25:10Z",
  "status": "active",
  "latitude": 28.6570,
  "longitude": 77.2420
}
```

**Side Effects:**
- Tourist's safety score decreases by 20 points
- Alert is created with status "active"

---

#### Get All Alerts
```http
GET /alerts
```

**Response (200 OK):**
```json
[
  {
    "id": 6,
    "tourist_id": 1,
    "type": "geofence",
    "message": "GEOFENCE ALERT: Aarav Sharma has entered restricted zone 'Delhi Red Fort Military Zone' at coordinates (28.6570, 77.2420)",
    "timestamp": "2025-09-24T12:25:10Z",
    "status": "active",
    "latitude": 28.6570,
    "longitude": 77.2420
  },
  {
    "id": 5,
    "tourist_id": 1,
    "type": "panic",
    "message": "PANIC ALERT: Aarav Sharma has triggered an emergency alert at coordinates (28.6139, 77.2090)",
    "timestamp": "2025-09-24T12:20:45Z",
    "status": "resolved",
    "latitude": 28.6139,
    "longitude": 77.2090
  }
]
```

**Note:** Returns all alerts ordered by timestamp (newest first).

---

#### Resolve Alert
```http
PUT /alerts/{alert_id}/resolve
```

**Response (200 OK):**
```json
{
  "message": "Alert resolved successfully"
}
```

**Error Response (404):**
```json
{
  "detail": "Alert not found"
}
```

---

### ⚙️ Admin Functions

#### Initialize Database
```http
POST /admin/initialize-database
```

**Response (200 OK):**
```json
{
  "message": "Database initialized with restricted zones",
  "restricted_zones_created": 3
}
```

**What it does:**
- Clears existing restricted zones
- Creates predefined restricted zones (basic set)

---

#### Health Check
```http
GET /admin/health
```

**Response (200 OK):**
```json
{
  "status": "healthy",
  "timestamp": "2025-09-24T12:30:00Z",
  "supabase": "connected"
}
```

**Unhealthy Response:**
```json
{
  "status": "unhealthy",
  "timestamp": "2025-09-24T12:30:00Z",
  "supabase": "error: connection failed"
}
```

---

## 🏛️ Restricted Zones

The system includes **23 comprehensive restricted zones** across North India:

### Zone Distribution by State

| State | Zones | Zone Types |
|-------|-------|------------|
| **Delhi** | 3 | Presidential Security, Military, Aviation |
| **Punjab** | 3 | Border Security, Military Cantonment |
| **Haryana** | 3 | Corporate Security, Air Force, Army Training |
| **Uttar Pradesh** | 4 | Heritage Protection, Government, Industrial, Religious |
| **Rajasthan** | 4 | Heritage Protection, Military Training, Border, Nuclear |
| **Himachal Pradesh** | 2 | Government Security, VIP Protection |
| **Uttarakhand** | 1 | Critical Infrastructure |
| **Other** | 3 | Legacy zones (Goa, Meghalaya) |

### Sample Restricted Zones

```json
[
  {
    "name": "Delhi Red Fort Military Zone",
    "coordinates": [[28.6562, 77.2410], [28.6580, 77.2440], ...],
    "type": "Historical Protection Zone",
    "state": "Delhi"
  },
  {
    "name": "Amritsar Border Security Force Area",
    "coordinates": [[31.6240, 74.8623], [31.6340, 74.8823], ...],
    "type": "Border Security Zone",
    "state": "Punjab"
  },
  {
    "name": "Agra Taj Mahal Protected Zone",
    "coordinates": [[27.1717, 78.0401], [27.1817, 78.0501], ...],
    "type": "Heritage Protection Zone",
    "state": "Uttar Pradesh"
  }
]
```

### Zone Types

- **Military**: Army training areas, air force stations, cantonments
- **Border Security**: International border areas with Pakistan
- **Heritage Protection**: UNESCO sites, historical monuments
- **Government Security**: Official residences, administrative complexes
- **Industrial Safety**: Chemical plants, hazardous manufacturing areas
- **Aviation Security**: Airport restricted airspace zones
- **Nuclear Security**: Nuclear test sites and buffer zones
- **VIP Protection**: High-profile residence security zones

---

## 📊 Data Models

### Tourist Model
```typescript
interface Tourist {
  id: number;
  name: string;                    // 1-100 characters
  contact: string;                 // 10-20 characters (Indian phone)
  trip_info?: string;              // Optional trip description
  emergency_contact: string;       // 10-20 characters
  safety_score: number;            // 0-100
  created_at: string;              // ISO 8601 timestamp
  updated_at?: string;             // ISO 8601 timestamp
}
```

### Location Model
```typescript
interface Location {
  id: number;
  tourist_id: number;
  latitude: number;                // -90 to 90
  longitude: number;               // -180 to 180
  timestamp: string;               // ISO 8601 timestamp
}
```

### Alert Model
```typescript
interface Alert {
  id: number;
  tourist_id: number;
  type: "panic" | "geofence";
  message: string;
  timestamp: string;               // ISO 8601 timestamp
  status: "active" | "resolved";
  latitude?: number;               // Optional
  longitude?: number;              // Optional
}
```

### Restricted Zone Model
```typescript
interface RestrictedZone {
  id: number;
  name: string;
  coordinates: number[][];         // Array of [lat, lon] coordinates
  created_at: string;
}
```

---

## ⚠️ Error Handling

### Standard Error Response Format
```json
{
  "detail": "Error message description"
}
```

### Common HTTP Status Codes

| Code | Meaning | When it occurs |
|------|---------|----------------|
| 200 | OK | Successful GET/PUT requests |
| 201 | Created | Successful POST requests |
| 400 | Bad Request | Invalid request data/validation errors |
| 404 | Not Found | Resource doesn't exist |
| 500 | Internal Server Error | Server/database errors |

### Validation Errors
```json
{
  "detail": [
    {
      "loc": ["body", "latitude"],
      "msg": "ensure this value is greater than or equal to -90",
      "type": "value_error.number.not_ge"
    }
  ]
}
```

---

## 🏆 Safety Score System

### Initial Score
- Every tourist starts with **100 points** (maximum safety)

### Score Deductions
| Event | Points Lost | Reason |
|-------|-------------|--------|
| Panic Alert | -40 | Emergency situation triggered |
| Geofence Violation | -20 | Entered restricted area |

### Score Rules
- **Minimum**: 0 points
- **Maximum**: 100 points
- **Updates**: Automatic when alerts are created
- **Tracking**: All changes logged with timestamps

### Safety Level Interpretation
- **90-100**: Excellent safety record (Green)
- **70-89**: Good safety record (Yellow)
- **50-69**: Moderate risk (Orange)
- **30-49**: High risk (Red)
- **0-29**: Critical risk level (Dark Red)

---

## 🔧 Integration Examples

### JavaScript/TypeScript Frontend

#### Register Tourist
```javascript
const registerTourist = async (touristData) => {
  try {
    const response = await fetch('http://localhost:8000/tourists/register', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(touristData)
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const tourist = await response.json();
    return tourist;
  } catch (error) {
    console.error('Error registering tourist:', error);
    throw error;
  }
};

// Usage with Indian tourist data
const newTourist = await registerTourist({
  name: "Priya Gupta",
  contact: "9876543210",
  trip_info: "Religious pilgrimage to Varanasi and Haridwar",
  emergency_contact: "9876543211"
});
```

#### Send Location Update
```javascript
const updateLocation = async (touristId, latitude, longitude) => {
  try {
    const response = await fetch('http://localhost:8000/locations/update', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        tourist_id: touristId,
        latitude: latitude,
        longitude: longitude
      })
    });
    
    return await response.json();
  } catch (error) {
    console.error('Error updating location:', error);
    throw error;
  }
};

// Usage with North Indian coordinates
await updateLocation(1, 28.6139, 77.2090); // New Delhi
await updateLocation(2, 26.9124, 75.7873); // Jaipur
await updateLocation(3, 31.6340, 74.8723); // Amritsar
```

#### Check for Geofence Violations
```javascript
const checkGeofenceViolation = async (touristId, latitude, longitude) => {
  // This would typically be done on the backend, but for demonstration:
  const restrictedZones = [
    {
      name: "Delhi Red Fort Military Zone",
      bounds: {
        minLat: 28.6562, maxLat: 28.6580,
        minLon: 77.2410, maxLon: 77.2440
      }
    },
    {
      name: "Agra Taj Mahal Protected Zone",
      bounds: {
        minLat: 27.1717, maxLat: 27.1817,
        minLon: 78.0401, maxLon: 78.0501
      }
    }
  ];
  
  for (const zone of restrictedZones) {
    if (latitude >= zone.bounds.minLat && latitude <= zone.bounds.maxLat &&
        longitude >= zone.bounds.minLon && longitude <= zone.bounds.maxLon) {
      
      // Create geofence alert
      const alert = await fetch('http://localhost:8000/alerts/geofence', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          tourist_id: touristId,
          latitude: latitude,
          longitude: longitude,
          zone_name: zone.name
        })
      });
      
      return await alert.json();
    }
  }
  
  return null; // No violation
};
```

#### Trigger Panic Alert
```javascript
const triggerPanicAlert = async (touristId, latitude, longitude) => {
  try {
    const response = await fetch('http://localhost:8000/alerts/panic', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        tourist_id: touristId,
        latitude: latitude,
        longitude: longitude
      })
    });
    
    const alert = await response.json();
    
    // Show emergency UI
    showEmergencyAlert(alert);
    
    return alert;
  } catch (error) {
    console.error('Error creating panic alert:', error);
    throw error;
  }
};

const showEmergencyAlert = (alert) => {
  // Display emergency notification to user
  alert('🚨 EMERGENCY ALERT SENT 🚨\n' + 
        'Emergency services have been notified!\n' + 
        'Your safety score has been updated.');
};
```

#### Get Real-time Dashboard Data
```javascript
const getDashboardData = async () => {
  try {
    const [locationsResponse, alertsResponse] = await Promise.all([
      fetch('http://localhost:8000/locations/all'),
      fetch('http://localhost:8000/alerts')
    ]);
    
    const locations = await locationsResponse.json();
    const alerts = await alertsResponse.json();
    
    return { 
      locations, 
      alerts,
      activeAlerts: alerts.filter(alert => alert.status === 'active'),
      emergencyAlerts: alerts.filter(alert => alert.type === 'panic' && alert.status === 'active')
    };
  } catch (error) {
    console.error('Error fetching dashboard data:', error);
    throw error;
  }
};

// Usage for admin dashboard
const updateDashboard = async () => {
  const data = await getDashboardData();
  
  // Update map with tourist locations
  data.locations.forEach(location => {
    updateMapMarker(location.tourist_id, location.latitude, location.longitude);
  });
  
  // Show active alerts
  displayActiveAlerts(data.activeAlerts);
  
  // Highlight emergency situations
  if (data.emergencyAlerts.length > 0) {
    showEmergencyDashboard(data.emergencyAlerts);
  }
};
```

### React Hook Example
```javascript
import { useState, useEffect } from 'react';

const useTouristData = (touristId) => {
  const [tourist, setTourist] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  useEffect(() => {
    const fetchTourist = async () => {
      try {
        setLoading(true);
        const response = await fetch(`http://localhost:8000/tourists/${touristId}`);
        
        if (!response.ok) {
          throw new Error('Tourist not found');
        }
        
        const data = await response.json();
        setTourist(data);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };
    
    if (touristId) {
      fetchTourist();
    }
  }, [touristId]);
  
  return { tourist, loading, error };
};

// Usage in React component
const TouristProfile = ({ touristId }) => {
  const { tourist, loading, error } = useTouristData(touristId);
  
  if (loading) return <div>Loading tourist data...</div>;
  if (error) return <div>Error: {error}</div>;
  if (!tourist) return <div>Tourist not found</div>;
  
  const getSafetyColor = (score) => {
    if (score >= 90) return 'green';
    if (score >= 70) return 'yellow';
    if (score >= 50) return 'orange';
    if (score >= 30) return 'red';
    return 'darkred';
  };
  
  return (
    <div className="tourist-profile">
      <h2>{tourist.name}</h2>
      <div className="safety-score" style={{ color: getSafetyColor(tourist.safety_score) }}>
        Safety Score: {tourist.safety_score}/100
      </div>
      <p>Contact: {tourist.contact}</p>
      <p>Emergency Contact: {tourist.emergency_contact}</p>
      <p>Trip: {tourist.trip_info}</p>
    </div>
  );
};
```

### Mobile App Integration (React Native)
```javascript
import { Alert } from 'react-native';
import * as Location from 'expo-location';

const sendLocationUpdate = async (touristId) => {
  try {
    // Request location permission
    const { status } = await Location.requestForegroundPermissionsAsync();
    if (status !== 'granted') {
      Alert.alert('Permission denied', 'Location access is required for safety tracking');
      return;
    }
    
    // Get current location
    const location = await Location.getCurrentPositionAsync({
      accuracy: Location.Accuracy.High
    });
    
    // Send to backend
    const response = await fetch('http://localhost:8000/locations/update', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        tourist_id: touristId,
        latitude: location.coords.latitude,
        longitude: location.coords.longitude
      })
    });
    
    if (response.ok) {
      console.log('Location updated successfully');
    }
  } catch (error) {
    console.error('Error updating location:', error);
    Alert.alert('Error', 'Failed to update location');
  }
};

// Emergency panic button
const triggerEmergencyAlert = async (touristId) => {
  try {
    const location = await Location.getCurrentPositionAsync({});
    
    const response = await fetch('http://localhost:8000/alerts/panic', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        tourist_id: touristId,
        latitude: location.coords.latitude,
        longitude: location.coords.longitude
      })
    });
    
    if (response.ok) {
      Alert.alert(
        '🚨 Emergency Alert Sent',
        'Emergency services have been notified of your location. Help is on the way!',
        [{ text: 'OK' }]
      );
    }
  } catch (error) {
    console.error('Error sending emergency alert:', error);
    Alert.alert('Error', 'Failed to send emergency alert');
  }
};

// Auto location tracking with geofence checking
const startLocationTracking = (touristId) => {
  return Location.watchPositionAsync(
    {
      accuracy: Location.Accuracy.High,
      timeInterval: 30000, // Update every 30 seconds
      distanceInterval: 100, // Update every 100 meters
    },
    async (location) => {
      // Send location update
      await sendLocationUpdate(touristId);
      
      // Check for geofence violations (handled by backend)
      console.log(`Location updated: ${location.coords.latitude}, ${location.coords.longitude}`);
    }
  );
};
```

---

## 📱 Real-time Features

### Location Polling
```javascript
// Poll for location updates every 30 seconds
const startLocationPolling = (touristId, callback) => {
  return setInterval(async () => {
    try {
      const response = await fetch(`http://localhost:8000/locations/all`);
      const locations = await response.json();
      const touristLocation = locations.find(loc => loc.tourist_id === touristId);
      
      if (touristLocation) {
        callback(touristLocation);
      }
    } catch (error) {
      console.error('Error polling location:', error);
    }
  }, 30000);
};

// Usage
const stopPolling = startLocationPolling(1, (location) => {
  console.log(`Tourist is at: ${location.latitude}, ${location.longitude}`);
  updateMapPosition(location.latitude, location.longitude);
});

// Don't forget to clear the interval
// clearInterval(stopPolling);
```

### Alert Monitoring
```javascript
// Monitor for new alerts
const monitorAlerts = (callback) => {
  let lastAlertId = 0;
  
  return setInterval(async () => {
    try {
      const response = await fetch('http://localhost:8000/alerts');
      const alerts = await response.json();
      
      const newAlerts = alerts.filter(alert => alert.id > lastAlertId);
      
      if (newAlerts.length > 0) {
        lastAlertId = Math.max(...alerts.map(a => a.id));
        callback(newAlerts);
      }
    } catch (error) {
      console.error('Error monitoring alerts:', error);
    }
  }, 10000); // Check every 10 seconds
};

// Usage
const stopMonitoring = monitorAlerts((newAlerts) => {
  newAlerts.forEach(alert => {
    if (alert.type === 'panic') {
      showEmergencyNotification(alert);
    } else if (alert.type === 'geofence') {
      showGeofenceWarning(alert);
    }
  });
});
```

---

## 🌍 CORS Configuration

The backend is configured to accept requests from any origin (`*`) for development. In production, update the CORS settings in `main.py`:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://yourdomain.com"],  # Specific domains
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT"],
    allow_headers=["*"],
)
```

---

## 📖 Interactive Documentation

Visit these URLs when the server is running:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

These provide interactive API testing interfaces where you can:
- Test all endpoints with real data
- View request/response schemas
- See validation rules
- Try different input values
- Test with the 50+ sample tourists already in the database

---

## 🗺️ Sample Data Available

The system comes pre-populated with:
- **50 Indian tourists** with authentic names and phone numbers
- **165+ location updates** across North Indian cities
- **20+ sample alerts** (panic and geofence)
- **23 restricted zones** covering North India

### Sample Tourist Names
- Aarav Sharma, Priya Gupta, Vivaan Agrawal, Ananya Singh
- Krishna Kumar, Diya Malhotra, Arjun Bansal, Kavya Pandey
- And 42 more with diverse Indian names...

### Sample Locations Covered
- **Delhi**: New Delhi, Gurgaon, Noida, Faridabad
- **Punjab**: Amritsar, Ludhiana, Chandigarh, Patiala
- **Rajasthan**: Jaipur, Jodhpur, Udaipur, Bikaner
- **Uttar Pradesh**: Lucknow, Kanpur, Agra, Varanasi
- **Himachal Pradesh**: Shimla, Manali, Dharamshala
- **Uttarakhand**: Dehradun, Haridwar, Rishikesh, Nainital

---

## 🚀 Quick Start Checklist

1. **Server Setup**
   - [x] FastAPI server running on port 8000
   - [x] Database connected (Supabase)
   - [x] 23 restricted zones initialized
   - [x] 50 sample tourists registered

2. **Frontend Integration**
   - [ ] Set base URL: `http://localhost:8000`
   - [ ] Handle JSON requests/responses
   - [ ] Implement error handling
   - [ ] Test with sample tourist IDs (2-51)

3. **Testing Flow**
   - [ ] Get tourist details: `GET /tourists/2`
   - [ ] Send location update: `POST /locations/update`
   - [ ] Trigger panic alert: `POST /alerts/panic`
   - [ ] Check safety score changes
   - [ ] Resolve alerts: `PUT /alerts/{id}/resolve`

4. **Dashboard Features**
   - [ ] Real-time location map with 50+ tourists
   - [ ] Active alerts monitoring
   - [ ] Safety score visualization
   - [ ] Geofence violation tracking

---

## 🔍 Testing Examples

### Quick API Tests
```bash
# Check server status
curl http://localhost:8000/health

# Get a sample tourist
curl http://localhost:8000/tourists/2

# Get all current locations
curl http://localhost:8000/locations/all

# Get all alerts
curl http://localhost:8000/alerts

# Interactive documentation
# Visit: http://localhost:8000/docs
```

---

**Need Help?** 
- Check `/health` endpoint for API status
- Use `/docs` for interactive testing
- Test with existing tourist IDs (2-51)
- All North Indian coordinates are pre-validated
- Emergency alerts are fully functional
- Geofencing works with 23 real restricted zones