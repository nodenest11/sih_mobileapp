# Backend API Reference for Frontend Developers

## Quick Start Guide for Frontend Integration

### Base URL
```
Development: http://localhost:8000
Production: https://your-domain.com/api
```

### API Documentation
- **Interactive Docs**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

---

## Authentication
Currently **no authentication** is required. All endpoints are open for development.

---

## Core Concepts

### Safety Score System
- **Range**: 0-100 (100 = safest)
- **Risk Levels**:
  - 0-29: Critical (red)
  - 30-49: High risk (orange) 
  - 50-69: Medium risk (yellow)
  - 70-100: Low risk (green)

### Alert Types
- **panic**: Emergency/distress alert
- **geofence**: Entered restricted area

### Alert Status
- **active**: Needs attention
- **resolved**: Handled/closed

---

## API Endpoints Reference

### 🏠 System Health

#### GET /health
Check if API is running
```javascript
fetch('/health')
  .then(res => res.json())
  .then(data => console.log(data)); // {status: "healthy"}
```

---

### 👤 Tourist Management

#### POST /tourists/register
Register a new tourist
```javascript
const touristData = {
  name: "John Doe",
  contact: "9876543210", 
  trip_info: "Visiting Delhi for business",
  emergency_contact: "9876543211"
};

fetch('/tourists/register', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify(touristData)
})
.then(res => res.json())
.then(tourist => {
  console.log('Tourist ID:', tourist.id);
  console.log('Safety Score:', tourist.safety_score); // starts at 100
});
```

**Response Example:**
```json
{
  "id": 101,
  "name": "John Doe",
  "contact": "9876543210",
  "trip_info": "Visiting Delhi for business", 
  "emergency_contact": "9876543211",
  "safety_score": 100,
  "created_at": "2025-09-21T15:56:34",
  "updated_at": "2025-09-21T15:56:34"
}
```

#### GET /tourists/{id}
Get tourist details
```javascript
const touristId = 101;
fetch(`/tourists/${touristId}`)
  .then(res => res.json())
  .then(tourist => {
    console.log('Current Safety Score:', tourist.safety_score);
  });
```

#### GET /tourists/
Get all tourists (with pagination)
```javascript
fetch('/tourists/?skip=0&limit=50')
  .then(res => res.json())
  .then(tourists => {
    tourists.forEach(tourist => {
      console.log(`${tourist.name}: Score ${tourist.safety_score}`);
    });
  });
```

---

### 📍 Location Tracking

#### POST /locations/update
Update tourist's current location
```javascript
const locationData = {
  tourist_id: 101,
  latitude: 28.6139,  // Delhi coordinates
  longitude: 77.2090
};

fetch('/locations/update', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify(locationData)
})
.then(res => res.json())
.then(location => {
  console.log('Location updated:', location.timestamp);
});
```

**Response Example:**
```json
{
  "id": 607,
  "tourist_id": 101,
  "latitude": 28.6139,
  "longitude": 77.2090,
  "timestamp": "2025-09-21T15:56:36",
  "tourist_name": "John Doe"
}
```

#### GET /locations/all
Get latest location of all tourists (for dashboard)
```javascript
fetch('/locations/all')
  .then(res => res.json())
  .then(locations => {
    locations.forEach(loc => {
      console.log(`${loc.tourist_name} at ${loc.latitude}, ${loc.longitude}`);
    });
  });
```

#### GET /locations/tourist/{id}
Get location history for specific tourist
```javascript
const touristId = 101;
fetch(`/locations/tourist/${touristId}?limit=10`)
  .then(res => res.json())
  .then(locations => {
    // locations are sorted by timestamp (newest first)
    locations.forEach(loc => {
      console.log(`Location at ${loc.timestamp}: ${loc.latitude}, ${loc.longitude}`);
    });
  });
```

#### GET /locations/latest/{id}
Get most recent location for a tourist
```javascript
const touristId = 101;
fetch(`/locations/latest/${touristId}`)
  .then(res => res.json())
  .then(location => {
    console.log('Latest position:', location.latitude, location.longitude);
  });
```

#### GET /locations/heatmap (or /heatmap)
Get heatmap data for geographic visualization
```javascript
// Basic heatmap for last 24 hours
fetch('/locations/heatmap')
  .then(res => res.json())
  .then(heatmap => {
    console.log(`Generated ${heatmap.points.length} heatmap points`);
    heatmap.points.forEach(point => {
      console.log(`Point: ${point.latitude}, ${point.longitude} - Intensity: ${point.intensity} (${point.risk_level})`);
    });
  });

// Advanced heatmap with custom parameters
const params = new URLSearchParams({
  hours: '72',           // Last 3 days
  include_alerts: 'true', // Include alert hotspots
  grid_size: '0.01'      // Larger grid for less detail
});

fetch(`/locations/heatmap?${params}`)
  .then(res => res.json())
  .then(heatmap => {
    // Use for map overlay visualization
    heatmap.points.forEach(point => {
      addHeatmapPoint(point.latitude, point.longitude, point.intensity, point.risk_level);
    });
  });
```

**Parameters:**
- `hours` (1-168): Time window in hours (default: 24)
- `include_alerts` (true/false): Include alert frequency in intensity (default: true)
- `grid_size` (0.001-0.1): Clustering precision - smaller = more detailed (default: 0.005)

**Response Example:**
```json
{
  "points": [
    {
      "latitude": 28.6139,
      "longitude": 77.2090,
      "intensity": 25,
      "risk_level": "medium"
    },
    {
      "latitude": 15.2993,
      "longitude": 74.1240,
      "intensity": 15,
      "risk_level": "low"
    }
  ],
  "metadata": {
    "total_points": 38,
    "time_window_hours": 24,
    "grid_size": 0.005,
    "includes_alerts": true
  }
}
```

**Risk Levels:**
- `low`: Intensity 0-20 (safe areas, good safety scores)
- `medium`: Intensity 21-40 (moderate activity, some concerns)
- `high`: Intensity 41+ (high tourist density, alerts, low safety scores)

---

### 🚨 Alert System

#### POST /alerts/panic
Create panic/emergency alert
```javascript
const panicData = {
  tourist_id: 101,
  latitude: 28.6139,
  longitude: 77.2090
};

fetch('/alerts/panic', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify(panicData)
})
.then(res => res.json())
.then(alert => {
  console.log('EMERGENCY ALERT CREATED:', alert.id);
  console.log('Message:', alert.message);
  // Safety score automatically reduced by 40 points
});
```

#### POST /alerts/geofence
Create geofence violation alert
```javascript
const geofenceData = {
  tourist_id: 101,
  latitude: 28.6562,  // Inside restricted zone
  longitude: 77.2410,
  zone_name: "Red Fort Restricted Area" // optional
};

fetch('/alerts/geofence', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify(geofenceData)
})
.then(res => res.json())
.then(alert => {
  console.log('Geofence violation:', alert.message);
  // Safety score automatically reduced by 20 points
});
```

#### GET /alerts/
Get all alerts with optional filtering
```javascript
// Get active alerts only
fetch('/alerts/?status_filter=active&limit=20')
  .then(res => res.json())
  .then(alerts => {
    alerts.forEach(alert => {
      console.log(`${alert.type.toUpperCase()}: ${alert.tourist_name}`);
      console.log(`Status: ${alert.status}`);
      console.log(`Time: ${alert.timestamp}`);
    });
  });

// Get all alerts (active + resolved)
fetch('/alerts/?status_filter=all')
  .then(res => res.json())
  .then(alerts => console.log(`Total alerts: ${alerts.length}`));
```

**Alert Response Example:**
```json
{
  "id": 12,
  "tourist_id": 101,
  "type": "panic",
  "message": "PANIC ALERT: John Doe has triggered a panic alert at coordinates (28.61, 77.23)",
  "latitude": 28.61,
  "longitude": 77.23,
  "timestamp": "2025-09-21T15:56:38",
  "status": "active",
  "resolved_at": null,
  "tourist_name": "John Doe"
}
```

#### PUT /alerts/{id}/resolve
Mark alert as resolved
```javascript
const alertId = 12;
fetch(`/alerts/${alertId}/resolve`, {
  method: 'PUT'
})
.then(res => res.json())
.then(alert => {
  console.log('Alert resolved at:', alert.resolved_at);
});
```

#### GET /alerts/tourist/{id}
Get alerts for specific tourist
```javascript
const touristId = 101;
fetch(`/alerts/tourist/${touristId}?status_filter=active`)
  .then(res => res.json())
  .then(alerts => {
    console.log(`${alerts.length} active alerts for this tourist`);
  });
```

---

### 📊 Analytics & Admin

#### GET /admin/{id}/risk-assessment
Get comprehensive risk assessment
```javascript
const touristId = 101;
fetch(`/admin/${touristId}/risk-assessment`)
  .then(res => res.json())
  .then(assessment => {
    console.log('Risk Level:', assessment.risk_level);
    console.log('Safety Score:', assessment.safety_score);
    console.log('Recent Alerts (24h):', assessment.recent_alerts_24h);
    console.log('Recommendations:', assessment.recommendations);
  });
```

**Risk Assessment Response:**
```json
{
  "tourist_id": 101,
  "tourist_name": "John Doe",
  "safety_score": 60,
  "risk_level": "medium",
  "recent_alerts_24h": 1,
  "panic_alerts_24h": 1,
  "geofence_alerts_24h": 0,
  "latest_location": {
    "latitude": 28.61,
    "longitude": 77.23,
    "timestamp": "2025-09-21T15:56:36"
  },
  "recommendations": [
    "Monitor tourist closely",
    "Consider reaching out to check status"
  ]
}
```

#### POST /admin/{id}/safe-checkin
Award points for safe check-in
```javascript
const touristId = 101;
fetch(`/admin/${touristId}/safe-checkin`, {method: 'POST'})
  .then(res => res.json())
  .then(result => {
    console.log('Score change:', result.score_change); // +5 points
  });
```

#### POST /admin/seed-database
Initialize sample data (development only)
```javascript
fetch('/admin/seed-database', {method: 'POST'})
  .then(res => res.json())
  .then(result => {
    console.log('Sample data loading:', result.status);
  });
```

---

## Frontend Implementation Examples

### Real-time Dashboard Components

#### Tourist List Component
```javascript
// React component example
const TouristList = () => {
  const [tourists, setTourists] = useState([]);
  
  useEffect(() => {
    fetch('/tourists/')
      .then(res => res.json())
      .then(setTourists);
  }, []);
  
  const getRiskColor = (score) => {
    if (score < 30) return 'red';
    if (score < 50) return 'orange';
    if (score < 70) return 'yellow';
    return 'green';
  };
  
  return (
    <div>
      {tourists.map(tourist => (
        <div key={tourist.id} style={{
          backgroundColor: getRiskColor(tourist.safety_score)
        }}>
          <h3>{tourist.name}</h3>
          <p>Safety Score: {tourist.safety_score}</p>
          <p>Contact: {tourist.contact}</p>
        </div>
      ))}
    </div>
  );
};
```

#### Live Alerts Component
```javascript
const LiveAlerts = () => {
  const [alerts, setAlerts] = useState([]);
  
  useEffect(() => {
    const fetchAlerts = () => {
      fetch('/alerts/?status_filter=active')
        .then(res => res.json())
        .then(setAlerts);
    };
    
    fetchAlerts();
    const interval = setInterval(fetchAlerts, 5000); // Poll every 5 seconds
    
    return () => clearInterval(interval);
  }, []);
  
  const resolveAlert = (alertId) => {
    fetch(`/alerts/${alertId}/resolve`, {method: 'PUT'})
      .then(() => {
        setAlerts(alerts.filter(alert => alert.id !== alertId));
      });
  };
  
  return (
    <div>
      <h2>Active Alerts ({alerts.length})</h2>
      {alerts.map(alert => (
        <div key={alert.id} className={`alert-${alert.type}`}>
          <h4>{alert.type.toUpperCase()} - {alert.tourist_name}</h4>
          <p>{alert.message}</p>
          <p>Location: {alert.latitude}, {alert.longitude}</p>
          <p>Time: {new Date(alert.timestamp).toLocaleString()}</p>
          <button onClick={() => resolveAlert(alert.id)}>
            Resolve
          </button>
        </div>
      ))}
    </div>
  );
};
```

#### Mobile App Location Tracking
```javascript
// Mobile app example - send location every 30 seconds
const startLocationTracking = (touristId) => {
  if ('geolocation' in navigator) {
    setInterval(() => {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const locationData = {
            tourist_id: touristId,
            latitude: position.coords.latitude,
            longitude: position.coords.longitude
          };
          
          fetch('/locations/update', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(locationData)
          })
          .then(res => res.json())
          .then(result => console.log('Location updated'));
        },
        (error) => console.error('Location error:', error)
      );
    }, 30000); // Every 30 seconds
  }
};
```

#### Panic Button Implementation
```javascript
const PanicButton = ({ touristId }) => {
  const triggerPanic = () => {
    if ('geolocation' in navigator) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const panicData = {
            tourist_id: touristId,
            latitude: position.coords.latitude,
            longitude: position.coords.longitude
          };
          
          fetch('/alerts/panic', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(panicData)
          })
          .then(res => res.json())
          .then(alert => {
            alert('Emergency alert sent! Alert ID: ' + alert.id);
          })
          .catch(error => {
            console.error('Failed to send panic alert:', error);
          });
        }
      );
    }
  };
  
  return (
    <button 
      onClick={triggerPanic}
      style={{
        backgroundColor: 'red',
        color: 'white',
        fontSize: '24px',
        padding: '20px',
        border: 'none',
        borderRadius: '50%'
      }}
    >
      🚨 PANIC
    </button>
  );
};
```

---

## Error Handling

### Common HTTP Status Codes
- **200**: Success
- **201**: Created successfully
- **400**: Bad request (invalid data)
- **404**: Not found
- **422**: Validation error
- **500**: Server error

### Error Response Format
```json
{
  "detail": [
    {
      "type": "validation_error",
      "loc": ["body", "latitude"],
      "msg": "ensure this value is greater than or equal to -90",
      "input": -91
    }
  ]
}
```

### JavaScript Error Handling Example
```javascript
const createTourist = async (touristData) => {
  try {
    const response = await fetch('/tourists/register', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(touristData)
    });
    
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.detail || 'Registration failed');
    }
    
    return await response.json();
  } catch (error) {
    console.error('Tourist registration error:', error.message);
    throw error;
  }
};
```

---

## Data Models Reference

### Tourist Object
```typescript
interface Tourist {
  id: number;
  name: string;
  contact: string;
  trip_info: string | null;
  emergency_contact: string;
  safety_score: number; // 0-100
  created_at: string; // ISO datetime
  updated_at: string; // ISO datetime
}
```

### Location Object
```typescript
interface Location {
  id: number;
  tourist_id: number;
  latitude: number; // -90 to 90
  longitude: number; // -180 to 180
  timestamp: string; // ISO datetime
  tourist_name?: string; // Included in some responses
}
```

### Alert Object
```typescript
interface Alert {
  id: number;
  tourist_id: number;
  type: 'panic' | 'geofence';
  message: string;
  latitude: number | null;
  longitude: number | null;
  timestamp: string; // ISO datetime
  status: 'active' | 'resolved';
  resolved_at: string | null; // ISO datetime
  tourist_name?: string; // Included in some responses
}
```

---

## Development Tips

### 1. Testing Your Integration
Always test with the sample data first:
```javascript
// Check if sample data is loaded
fetch('/tourists/')
  .then(res => res.json())
  .then(tourists => {
    console.log(`${tourists.length} tourists in database`);
    if (tourists.length === 0) {
      console.log('Run /admin/seed-database first');
    }
  });
```

### 2. Polling vs WebSockets
Currently use polling for real-time updates:
```javascript
// Poll for new alerts every 10 seconds
setInterval(() => {
  fetch('/alerts/?status_filter=active')
    .then(res => res.json())
    .then(updateAlertsUI);
}, 10000);
```

### 3. Local Development CORS
The backend has CORS enabled for all origins during development. In production, specify exact domains.

### 4. Date Handling
All timestamps are in ISO format (UTC). Convert to local time in frontend:
```javascript
const localTime = new Date(alert.timestamp).toLocaleString();
```

---

## Contact & Support

- **API Docs**: http://localhost:8000/docs
- **GitHub**: Repository for issues and contributions
- **Health Check**: Use `/health` endpoint to verify API status

This reference covers all endpoints and common integration patterns. For detailed API exploration, use the interactive Swagger documentation at `/docs`.