# 🚀 SafeHorizon API Documentation for Frontend Developers

Welcome to the SafeHorizon Tourist Safety Platform API! This comprehensive guide will help you integrate with our backend services for building mobile apps and web dashboards.

## 📋 Base Information

- **Base URL**: `http://localhost:8000` (Development) or `https://your-domain.com` (Production)
- **API Prefix**: `/api`
- **Authentication**: Bearer Token (JWT)
- **Content-Type**: `application/json`

## ✅ Recent Fixes & Updates

### Authentication System Fixed ✅
- **Issue**: Mobile app receiving 403 Forbidden errors on tourist endpoints
- **Root Cause**: bcrypt compatibility issue between `passlib` and `bcrypt` v4.3.0
- **Solution**: Migrated to native `bcrypt` library with proper byte encoding
- **Status**: All authentication endpoints working correctly
- **Impact**: JWT tokens no longer expire, password verification works properly

### JWT Token Corruption Issue Fixed ✅
- **Issue**: "Invalid authentication credentials" error with valid-looking tokens
- **Root Cause**: Token corruption during copy/paste from terminal output
- **Symptoms**: Character differences in JWT signature (e.g., `YF2p` vs `YI2p`)
- **Solution**: Added token length validation and preview in login response
- **Prevention**: Use the `/api/auth/debug-token` endpoint to verify token validity
- **Note**: Always copy tokens carefully from API responses, avoiding line breaks

### Mobile App 403 Errors Fixed ✅
- **Issue**: Mobile app getting 403 Forbidden on tourist endpoints
- **Root Cause**: Incorrect dependency injection - using `AuthUser` instead of `Tourist` 
- **Solution**: Fixed endpoint dependencies to use `current_tourist: Tourist = Depends(get_current_tourist)`
- **Fixed Endpoints**: `/api/safety/score`, `/api/auth/me`, `/api/zones/list` (newly added for tourists)

### Working Endpoints Confirmed ✅
- ✅ Tourist registration (`/api/auth/register`)
- ✅ Tourist login (`/api/auth/login`) - now includes token info
- ✅ Tourist profile (`/api/auth/me`) - fixed dependency
- ✅ Safety score (`/api/safety/score`) - fixed dependency
- ✅ Safety zones (`/api/zones/list`) - newly added for tourists
- ✅ Location updates (`/api/location/update`)
- ✅ Authority authentication and dashboard access
- ✅ Debug token validation (`/api/auth/debug-token`)

## 🔐 Authentication

All protected endpoints require a Bearer token in the Authorization header:
```
Authorization: Bearer <your_jwt_token>
```

---

## 📱 Tourist Mobile App Endpoints

### Authentication

#### 1. Register Tourist
```http
POST /api/auth/register
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securepass123",
  "name": "John Doe",                    // Optional
  "phone": "+1234567890",                // Optional
  "emergency_contact": "Jane Doe",       // Optional
  "emergency_phone": "+0987654321"       // Optional
}
```

**Response:**
```json
{
  "message": "Tourist registered successfully",
  "user_id": "abc123def456",
  "email": "user@example.com"
}
```

#### 2. Login Tourist
```http
POST /api/auth/login
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securepass123"
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsIn...",
  "token_type": "bearer",
  "user_id": "abc123def456",
  "email": "user@example.com",
  "role": "tourist"
}
```

#### 3. Get Current User Profile
```http
GET /api/auth/me
```
*Requires Authentication*

**Response:**
```json
{
  "id": "abc123def456",
  "email": "user@example.com",
  "name": "John Doe",
  "phone": "+1234567890",
  "safety_score": 85,
  "last_seen": "2025-09-28T12:30:00.000Z"
}
```

### Trip Management

#### 4. Start New Trip
```http
POST /api/trip/start
```
*Requires Authentication*

**Request Body:**
```json
{
  "destination": "Paris, France",
  "itinerary": "Visit Eiffel Tower, Louvre..."  // Optional
}
```

**Response:**
```json
{
  "trip_id": 123,
  "destination": "Paris, France",
  "status": "active",
  "start_date": "2025-09-28T12:00:00.000Z"
}
```

#### 5. End Current Trip
```http
POST /api/trip/end
```
*Requires Authentication*

**Response:**
```json
{
  "trip_id": 123,
  "status": "completed",
  "end_date": "2025-09-28T18:00:00.000Z"
}
```

#### 6. Get Trip History
```http
GET /api/trip/history
```
*Requires Authentication*

**Response:**
```json
[
  {
    "id": 123,
    "destination": "Paris, France",
    "status": "completed",
    "start_date": "2025-09-28T12:00:00.000Z",
    "end_date": "2025-09-28T18:00:00.000Z",
    "created_at": "2025-09-28T11:55:00.000Z"
  }
]
```

### Location Tracking

#### 7. Update Location (GPS)
```http
POST /api/location/update
```
*Requires Authentication*

**Request Body:**
```json
{
  "lat": 48.8584,
  "lon": 2.2945,
  "speed": 5.2,                          // Optional (km/h)
  "altitude": 35.0,                      // Optional (meters)
  "accuracy": 10.0,                      // Optional (meters)
  "timestamp": "2025-09-28T12:30:00.000Z" // Optional (auto-generated if not provided)
}
```

**Response:**
```json
{
  "status": "location_updated",
  "location_id": 456,
  "safety_score": 85,
  "risk_level": "low",
  "lat": 48.8584,
  "lon": 2.2945,
  "timestamp": "2025-09-28T12:30:00.000Z"
}
```

#### 8. Get Location History
```http
GET /api/location/history?limit=50
```
*Requires Authentication*

**Query Parameters:**
- `limit` (optional): Number of locations to retrieve (default: 100)

**Response:**
```json
[
  {
    "id": 456,
    "lat": 48.8584,
    "lon": 2.2945,
    "speed": 5.2,
    "altitude": 35.0,
    "accuracy": 10.0,
    "timestamp": "2025-09-28T12:30:00.000Z"
  }
]
```

### Safety & Emergency

#### 9. Get Safety Score
```http
GET /api/safety/score
```
*Requires Authentication*

**Response:**
```json
{
  "safety_score": 85,
  "risk_level": "low",
  "last_updated": "2025-09-28T12:30:00.000Z"
}
```

#### 10. Trigger SOS Emergency
```http
POST /api/sos/trigger
```
*Requires Authentication*

**Response:**
```json
{
  "status": "sos_triggered",
  "alert_id": 789,
  "notifications_sent": {
    "emergency_contacts": 1,
    "authorities": 1
  },
  "timestamp": "2025-09-28T12:35:00.000Z"
}
```

---

## 👮 Police Dashboard Endpoints

### Authentication

#### 11. Register Authority
```http
POST /api/auth/register-authority
```

**Request Body:**
```json
{
  "email": "officer@police.gov",
  "password": "securepass123",
  "name": "Officer Smith",
  "badge_number": "BADGE123",
  "department": "Metropolitan Police",
  "rank": "Sergeant"                     // Optional
}
```

**Response:**
```json
{
  "message": "Authority registered successfully",
  "user_id": "xyz789abc456",
  "badge_number": "BADGE123",
  "department": "Metropolitan Police"
}
```

#### 12. Authority Login
```http
POST /api/auth/login-authority
```

**Request Body:**
```json
{
  "email": "officer@police.gov",
  "password": "securepass123"
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsIn...",
  "token_type": "bearer",
  "user": {
    "id": "xyz789abc456",
    "email": "officer@police.gov"
  }
}
```

### Tourist Monitoring

#### 13. Get Active Tourists
```http
GET /api/tourists/active
```
*Requires Authority Authentication*

**Response:**
```json
[
  {
    "id": "abc123def456",
    "name": "John Doe",
    "email": "user@example.com",
    "safety_score": 85,
    "last_location": {
      "lat": 48.8584,
      "lon": 2.2945
    },
    "last_seen": "2025-09-28T12:30:00.000Z"
  }
]
```

#### 14. Track Specific Tourist
```http
GET /api/tourist/{tourist_id}/track
```
*Requires Authority Authentication*

**Response:**
```json
{
  "tourist": {
    "id": "abc123def456",
    "name": "John Doe",
    "email": "user@example.com",
    "phone": "+1234567890",
    "safety_score": 85,
    "last_seen": "2025-09-28T12:30:00.000Z"
  },
  "locations": [
    {
      "id": 456,
      "lat": 48.8584,
      "lon": 2.2945,
      "speed": 5.2,
      "altitude": 35.0,
      "timestamp": "2025-09-28T12:30:00.000Z"
    }
  ],
  "recent_alerts": [
    {
      "id": 789,
      "type": "sos",
      "severity": "critical",
      "title": "🚨 SOS Emergency Alert",
      "description": "Emergency SOS triggered by John Doe",
      "is_acknowledged": false,
      "created_at": "2025-09-28T12:35:00.000Z"
    }
  ]
}
```

#### 15. Get Tourist Alerts
```http
GET /api/tourist/{tourist_id}/alerts
```
*Requires Authority Authentication*

**Response:**
```json
[
  {
    "id": 789,
    "type": "sos",
    "severity": "critical",
    "title": "🚨 SOS Emergency Alert",
    "description": "Emergency SOS triggered by John Doe",
    "is_acknowledged": true,
    "acknowledged_by": "xyz789abc456",
    "acknowledged_at": "2025-09-28T12:40:00.000Z",
    "is_resolved": false,
    "resolved_at": null,
    "created_at": "2025-09-28T12:35:00.000Z"
  }
]
```

### Alert Management

#### 16. Get Recent Alerts
```http
GET /api/alerts/recent?limit=20&severity=high
```
*Requires Authority Authentication*

**Query Parameters:**
- `limit` (optional): Number of alerts to retrieve
- `severity` (optional): Filter by severity (low, medium, high, critical)

**Response:**
```json
[
  {
    "id": 789,
    "tourist_id": "abc123def456",
    "tourist_name": "John Doe",
    "type": "sos",
    "severity": "critical",
    "title": "🚨 SOS Emergency Alert",
    "description": "Emergency SOS triggered by John Doe",
    "location": {
      "lat": 48.8584,
      "lon": 2.2945
    },
    "is_acknowledged": false,
    "created_at": "2025-09-28T12:35:00.000Z"
  }
]
```

#### 17. Acknowledge Incident
```http
POST /api/incident/acknowledge
```
*Requires Authority Authentication*

**Request Body:**
```json
{
  "alert_id": 789,
  "notes": "Officer dispatched to location"  // Optional
}
```

**Response:**
```json
{
  "status": "acknowledged",
  "incident_number": "INC-2025-0928-001",
  "acknowledged_at": "2025-09-28T12:40:00.000Z",
  "assigned_to": "xyz789abc456"
}
```

#### 18. Close Incident
```http
POST /api/incident/close
```
*Requires Authority Authentication*

**Request Body:**
```json
{
  "alert_id": 789,
  "resolution_notes": "Tourist found safe. False alarm."
}
```

**Response:**
```json
{
  "status": "closed",
  "resolved_at": "2025-09-28T13:00:00.000Z",
  "resolution_notes": "Tourist found safe. False alarm."
}
```

#### 19. Generate E-FIR
```http
POST /api/efir/generate
```
*Requires Authority Authentication*

**Request Body:**
```json
{
  "alert_id": 789,
  "incident_details": "Emergency response for tourist safety alert",
  "action_taken": "Tourist located and provided assistance"
}
```

**Response:**
```json
{
  "efir_reference": "EFIR-2025-0928-001",
  "blockchain_hash": "0x1234567890abcdef...",
  "timestamp": "2025-09-28T13:00:00.000Z",
  "status": "generated"
}
```

### Zone Management

#### 20. List Safety Zones
```http
GET /api/zones/list
```
*Requires Authority Authentication*

**Response:**
```json
[
  {
    "id": 101,
    "name": "Tourist District Safe Zone",
    "description": "Main tourist area with high security",
    "zone_type": "safe",
    "center_latitude": 48.8566,
    "center_longitude": 2.3522,
    "radius_meters": 1000,
    "is_active": true,
    "created_at": "2025-09-28T10:00:00.000Z"
  }
]
```

#### 21. Create Safety Zone
```http
POST /api/zones/create
```
*Requires Authority Authentication*

**Request Body:**
```json
{
  "name": "New Safe Zone",
  "description": "Protected area around embassy",
  "zone_type": "safe",                   // "safe", "risky", "restricted"
  "coordinates": [
    [2.3522, 48.8566],                   // [longitude, latitude]
    [2.3532, 48.8576],
    [2.3542, 48.8566],
    [2.3522, 48.8556]
  ]
}
```

**Response:**
```json
{
  "zone_id": 102,
  "status": "created",
  "message": "Safety zone created successfully"
}
```

#### 22. Delete Safety Zone
```http
DELETE /api/zones/{zone_id}
```
*Requires Authority Authentication*

**Response:**
```json
{
  "status": "deleted",
  "message": "Zone deleted successfully"
}
```

---

## ⚙️ Admin System Endpoints

#### 23. System Status
```http
GET /api/system/status
```
*Requires Admin Authentication*

**Response:**
```json
{
  "status": "healthy",
  "database": "connected",
  "ai_models": "loaded",
  "active_tourists": 125,
  "active_authorities": 15,
  "recent_alerts": 3,
  "uptime": "5 days, 12 hours",
  "version": "1.0.0"
}
```

#### 24. Retrain AI Models
```http
POST /api/system/retrain-model
```
*Requires Admin Authentication*

**Request Body:**
```json
{
  "model_type": "all",                   // "all", "anomaly", "sequence", "classification"
  "force_retrain": false                 // Optional
}
```

**Response:**
```json
{
  "status": "retraining_started",
  "job_id": "retrain-2025-0928-001",
  "estimated_completion": "2025-09-28T15:00:00.000Z"
}
```

#### 25. List Users
```http
GET /api/users/list?role=tourist&limit=50
```
*Requires Admin Authentication*

**Query Parameters:**
- `role` (optional): Filter by role (tourist, authority, admin)
- `limit` (optional): Number of users to retrieve
- `is_active` (optional): Filter by active status

**Response:**
```json
[
  {
    "id": "abc123def456",
    "email": "user@example.com",
    "name": "John Doe",
    "role": "tourist",
    "is_active": true,
    "last_seen": "2025-09-28T12:30:00.000Z",
    "created_at": "2025-09-20T10:00:00.000Z"
  }
]
```

#### 26. Suspend User
```http
PUT /api/users/{user_id}/suspend
```
*Requires Admin Authentication*

**Request Body:**
```json
{
  "reason": "Violation of terms of service",
  "duration_days": 7                     // Optional, permanent if not specified
}
```

**Response:**
```json
{
  "status": "suspended",
  "user_id": "abc123def456",
  "suspended_until": "2025-10-05T12:00:00.000Z"
}
```

---

## 🤖 AI Services Endpoints

#### 27. Check Geofence
```http
POST /api/ai/geofence/check
```
*Internal Use / Requires Authentication*

**Request Body:**
```json
{
  "lat": 48.8584,
  "lon": 2.2945
}
```

**Response:**
```json
{
  "status": "safe",                      // "safe", "risky", "restricted"
  "zone_name": "Tourist District Safe Zone",
  "distance_to_zone": 50.5,
  "recommendations": ["Stay in well-lit areas", "Keep emergency contacts ready"]
}
```

#### 28. Anomaly Detection (Single Point)
```http
POST /api/ai/anomaly/point
```
*Internal Use / Requires Authentication*

**Request Body:**
```json
{
  "lat": 48.8584,
  "lon": 2.2945,
  "speed": 25.0,
  "time_of_day": "22:30",
  "day_of_week": "friday"
}
```

**Response:**
```json
{
  "is_anomaly": true,
  "anomaly_score": 0.85,
  "confidence": 0.92,
  "factors": ["unusual_speed", "late_hour"]
}
```

#### 29. Compute Safety Score
```http
POST /api/ai/score/compute
```
*Internal Use / Requires Authentication*

**Request Body:**
```json
{
  "lat": 48.8584,
  "lon": 2.2945,
  "location_history": [
    {
      "latitude": 48.8580,
      "longitude": 2.2940,
      "speed": 5.0,
      "timestamp": "2025-09-28T12:25:00.000Z"
    }
  ],
  "current_location_data": {
    "latitude": 48.8584,
    "longitude": 2.2945,
    "speed": 5.2,
    "timestamp": "2025-09-28T12:30:00.000Z"
  }
}
```

**Response:**
```json
{
  "safety_score": 85,
  "risk_level": "low",
  "risk_factors": [],
  "recommendations": ["Continue with current route"],
  "confidence": 0.91
}
```

---

## 🔔 Notification Endpoints

#### 30. Send Push Notification
```http
POST /api/notify/push
```
*Requires Authority Authentication*

**Request Body:**
```json
{
  "user_id": "abc123def456",
  "title": "Safety Alert",
  "message": "Please proceed to the nearest safe zone",
  "type": "safety_alert",               // "info", "warning", "emergency", "safety_alert"
  "data": {                             // Optional additional data
    "alert_id": 789,
    "location": "Tourist District"
  }
}
```

**Response:**
```json
{
  "status": "sent",
  "notification_id": "notif-123",
  "sent_at": "2025-09-28T12:45:00.000Z"
}
```

#### 31. Send SMS Alert
```http
POST /api/notify/sms
```
*Requires Authority Authentication*

**Request Body:**
```json
{
  "phone": "+1234567890",
  "message": "SAFETY ALERT: Please proceed to nearest safe zone immediately. Call 911 if emergency.",
  "priority": "high"                    // "low", "medium", "high", "critical"
}
```

**Response:**
```json
{
  "status": "sent",
  "sms_id": "sms-456",
  "sent_at": "2025-09-28T12:45:00.000Z",
  "cost": 0.05
}
```

---

## 🌐 WebSocket Endpoints

### Real-time Alert Subscription (Police Dashboard)
```
WS /api/alerts/subscribe
```
*Requires Authority Authentication*

**Connection:**
```javascript
const ws = new WebSocket('ws://localhost:8000/api/alerts/subscribe?token=<auth_token>');

ws.onmessage = (event) => {
  const alert = JSON.parse(event.data);
  console.log('New alert:', alert);
};
```

**Message Format:**
```json
{
  "type": "sos_alert",
  "alert_id": 789,
  "tourist_id": "abc123def456",
  "tourist_name": "John Doe",
  "severity": "critical",
  "location": {
    "lat": 48.8584,
    "lon": 2.2945
  },
  "timestamp": "2025-09-28T12:35:00.000Z"
}
```

---

## 📊 Response Status Codes

- **200 OK** - Successful request
- **201 Created** - Resource created successfully
- **400 Bad Request** - Invalid request data
- **401 Unauthorized** - Missing or invalid authentication
- **403 Forbidden** - Insufficient permissions
- **404 Not Found** - Resource not found
- **422 Unprocessable Entity** - Validation errors
- **500 Internal Server Error** - Server error

---

## 🔒 Security Notes

1. **Always use HTTPS** in production
2. **Store JWT tokens securely** (e.g., secure storage, not localStorage)
3. **Implement token refresh** logic for long-lived sessions
4. **Validate user input** before sending to API
5. **Handle rate limiting** (respect 429 responses)
6. **Log security events** (failed logins, suspicious activity)

---

## 📱 Example Mobile App Integration

### React Native Example
```javascript
// API Client Setup
const API_BASE = 'http://localhost:8000/api';

class SafeHorizonAPI {
  constructor() {
    this.token = null;
  }

  async login(email, password) {
    const response = await fetch(`${API_BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });
    
    const data = await response.json();
    if (data.access_token) {
      this.token = data.access_token;
    }
    return data;
  }

  async updateLocation(lat, lon, speed = null) {
    const response = await fetch(`${API_BASE}/location/update`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.token}`
      },
      body: JSON.stringify({ lat, lon, speed })
    });
    
    return await response.json();
  }

  async triggerSOS() {
    const response = await fetch(`${API_BASE}/sos/trigger`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.token}`
      }
    });
    
    return await response.json();
  }
}
```

### Web Dashboard Example
```javascript
// Police Dashboard WebSocket Connection
class PoliceWebSocket {
  constructor(token) {
    this.token = token;
    this.connect();
  }

  connect() {
    this.ws = new WebSocket(`ws://localhost:8000/api/alerts/subscribe?token=${this.token}`);
    
    this.ws.onmessage = (event) => {
      const alert = JSON.parse(event.data);
      this.handleAlert(alert);
    };
  }

  handleAlert(alert) {
    // Update UI with new alert
    console.log('New alert received:', alert);
    
    // Show notification
    if (alert.severity === 'critical') {
      this.showEmergencyNotification(alert);
    }
  }

  showEmergencyNotification(alert) {
    // Implementation for emergency UI updates
  }
}
```

---

## 📞 Support & Contact

For technical support and API questions:
- **Email**: dev-support@safehorizon.com
- **Documentation**: https://api.safehorizon.com/docs
- **Status Page**: https://status.safehorizon.com

---

*This documentation is for SafeHorizon API v1.0.0. Last updated: September 28, 2025*