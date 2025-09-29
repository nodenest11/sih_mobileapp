# 📱 SafeHorizon Tourist Mobile App - Complete Solution Prompt

## 🎯 Project Overview

Build a **React Native Tourist Safety Mobile App** that integrates with the SafeHorizon FastAPI backend for real-time safety monitoring, location tracking, and emergency response.

## 📋 Core Features Required

### 🔐 Authentication & Profile
- User registration and login
- Profile management with emergency contacts
- Persistent authentication (JWT tokens without expiration)
- Biometric authentication support (fingerprint/face)

### 🗺️ Location & Safety
- Real-time GPS tracking with background location updates
- Safety score display (0-100) with visual indicators
- Geofencing alerts for restricted/unsafe zones
- Trip planning and tracking
- Offline map caching for emergencies

### 🚨 Emergency Features
- One-tap SOS button with audio/visual feedback
- Automatic emergency contact notifications
- Police dashboard integration for real-time alerts
- Panic mode with discrete activation
- Voice-activated emergency commands

### 📊 Safety Intelligence
- AI-powered risk assessment based on location patterns
- Real-time safety recommendations
- Crowd-sourced safety reports
- Weather and local event integration
- Smart route suggestions avoiding high-risk areas

---

## 🏗️ Technical Architecture

### Frontend (React Native)
```
tourist-app/
├── src/
│   ├── components/           # Reusable UI components
│   │   ├── auth/            # Login, register forms
│   │   ├── safety/          # Safety score, alerts
│   │   ├── maps/            # Map components, markers
│   │   ├── emergency/       # SOS button, panic mode
│   │   └── common/          # Headers, buttons, modals
│   ├── screens/             # Main app screens
│   │   ├── AuthScreen.js
│   │   ├── HomeScreen.js
│   │   ├── MapScreen.js
│   │   ├── ProfileScreen.js
│   │   ├── EmergencyScreen.js
│   │   └── TripScreen.js
│   ├── services/            # API and business logic
│   │   ├── api.js           # Backend API integration
│   │   ├── location.js      # GPS and location services
│   │   ├── auth.js          # Authentication logic
│   │   ├── emergency.js     # Emergency response
│   │   └── websocket.js     # Real-time communications
│   ├── store/               # State management (Redux/Zustand)
│   │   ├── authSlice.js
│   │   ├── locationSlice.js
│   │   ├── safetySlice.js
│   │   └── emergencySlice.js
│   ├── utils/               # Helper functions
│   │   ├── permissions.js   # Device permissions
│   │   ├── storage.js       # Local storage
│   │   ├── notifications.js # Push notifications
│   │   └── encryption.js    # Data security
│   └── assets/              # Images, icons, fonts
├── android/                 # Android-specific code
├── ios/                     # iOS-specific code
└── package.json
```

### Key Dependencies
```json
{
  "dependencies": {
    "react-native": "^0.72.0",
    "@react-navigation/native": "^6.1.0",
    "@react-navigation/stack": "^6.3.0",
    "react-native-maps": "^1.7.0",
    "react-native-geolocation-service": "^5.3.0",
    "@react-native-async-storage/async-storage": "^1.19.0",
    "react-native-push-notification": "^8.1.0",
    "@reduxjs/toolkit": "^1.9.0",
    "react-redux": "^8.1.0",
    "axios": "^1.4.0",
    "react-native-websocket": "^1.0.0",
    "react-native-keychain": "^8.1.0",
    "react-native-biometrics": "^3.0.0",
    "react-native-voice": "^3.2.0",
    "react-native-sound": "^0.11.0",
    "react-native-vibration": "^1.1.0",
    "react-native-permissions": "^3.8.0"
  }
}
```

---

## 🔗 Backend Integration

### API Base Configuration
```javascript
// src/services/api.js
import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';

const API_BASE_URL = 'http://your-backend-url:8000/api';

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor to add auth token
api.interceptors.request.use(async (config) => {
  const token = await AsyncStorage.getItem('auth_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (error.response?.status === 401) {
      await AsyncStorage.removeItem('auth_token');
      // Navigate to login screen
    }
    return Promise.reject(error);
  }
);

export default api;
```

### Authentication Service
```javascript
// src/services/auth.js
import api from './api';
import AsyncStorage from '@react-native-async-storage/async-storage';

export const authService = {
  async register(userData) {
    const response = await api.post('/auth/register', userData);
    return response.data;
  },

  async login(email, password) {
    const response = await api.post('/auth/login', { email, password });
    const { access_token, user_id, email: userEmail, role } = response.data;
    
    // Store token and user info
    await AsyncStorage.multiSet([
      ['auth_token', access_token],
      ['user_id', user_id],
      ['user_email', userEmail],
      ['user_role', role],
    ]);
    
    return response.data;
  },

  async getCurrentUser() {
    const response = await api.get('/auth/me');
    return response.data;
  },

  async logout() {
    await AsyncStorage.multiRemove([
      'auth_token',
      'user_id', 
      'user_email',
      'user_role'
    ]);
  },

  async isAuthenticated() {
    const token = await AsyncStorage.getItem('auth_token');
    return !!token;
  }
};
```

---

## 📍 Location & Safety Services

### GPS Location Service
```javascript
// src/services/location.js
import Geolocation from 'react-native-geolocation-service';
import { PermissionsAndroid, Platform } from 'react-native';
import api from './api';

export const locationService = {
  async requestPermissions() {
    if (Platform.OS === 'android') {
      const granted = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION
      );
      return granted === PermissionsAndroid.RESULTS.GRANTED;
    }
    return true;
  },

  async getCurrentLocation() {
    return new Promise((resolve, reject) => {
      Geolocation.getCurrentPosition(
        (position) => resolve(position),
        (error) => reject(error),
        { 
          enableHighAccuracy: true, 
          timeout: 15000, 
          maximumAge: 10000 
        }
      );
    });
  },

  async startLocationTracking(callback) {
    const watchId = Geolocation.watchPosition(
      callback,
      (error) => console.error('Location error:', error),
      {
        enableHighAccuracy: true,
        distanceFilter: 10, // Update every 10 meters
        interval: 30000,    // Update every 30 seconds
        fastestInterval: 5000,
      }
    );
    return watchId;
  },

  stopLocationTracking(watchId) {
    Geolocation.clearWatch(watchId);
  },

  async updateLocationToServer(position) {
    const locationData = {
      lat: position.coords.latitude,
      lon: position.coords.longitude,
      speed: position.coords.speed || 0,
      altitude: position.coords.altitude || 0,
      accuracy: position.coords.accuracy,
      timestamp: new Date().toISOString()
    };

    try {
      const response = await api.post('/location/update', locationData);
      return response.data;
    } catch (error) {
      console.error('Failed to update location:', error);
      throw error;
    }
  }
};
```

### Safety Score Service
```javascript
// src/services/safety.js
import api from './api';

export const safetyService = {
  async getSafetyScore() {
    const response = await api.get('/safety/score');
    return response.data;
  },

  async getLocationSafety(lat, lon) {
    const response = await api.post('/ai/geofence/check', { lat, lon });
    return response.data;
  },

  async reportIncident(incidentData) {
    const response = await api.post('/incidents/report', incidentData);
    return response.data;
  },

  getRiskLevelColor(score) {
    if (score >= 80) return '#4CAF50'; // Green - Safe
    if (score >= 60) return '#FF9800'; // Orange - Moderate  
    if (score >= 40) return '#F44336'; // Red - High Risk
    return '#9C27B0'; // Purple - Critical
  },

  getRiskLevelText(score) {
    if (score >= 80) return 'Safe';
    if (score >= 60) return 'Moderate Risk';
    if (score >= 40) return 'High Risk';
    return 'Critical Risk';
  }
};
```

---

## 🚨 Emergency Response System

### Emergency Service
```javascript
// src/services/emergency.js
import api from './api';
import { Vibration, Alert } from 'react-native';
import Sound from 'react-native-sound';

export const emergencyService = {
  async triggerSOS(location) {
    try {
      // Immediate UI feedback
      Vibration.vibrate([500, 500, 500]);
      this.playEmergencySound();

      // Send SOS to backend
      const response = await api.post('/sos/trigger', {
        lat: location.latitude,
        lon: location.longitude,
        timestamp: new Date().toISOString(),
        emergency_type: 'sos'
      });

      return response.data;
    } catch (error) {
      console.error('SOS trigger failed:', error);
      throw error;
    }
  },

  async triggerPanicMode(location) {
    // Discrete panic mode - no sound/vibration
    try {
      const response = await api.post('/sos/trigger', {
        lat: location.latitude,
        lon: location.longitude,
        timestamp: new Date().toISOString(),
        emergency_type: 'panic',
        discrete: true
      });

      return response.data;
    } catch (error) {
      console.error('Panic mode trigger failed:', error);
      throw error;
    }
  },

  playEmergencySound() {
    const sound = new Sound('emergency_alert.mp3', Sound.MAIN_BUNDLE, (error) => {
      if (!error) {
        sound.play();
      }
    });
  },

  async sendEmergencyContacts(alertData) {
    const response = await api.post('/notify/emergency-contacts', alertData);
    return response.data;
  }
};
```

---

## 🗺️ Map Integration

### Map Component
```javascript
// src/components/maps/SafetyMap.js
import React, { useState, useEffect } from 'react';
import MapView, { Marker, Circle } from 'react-native-maps';
import { locationService, safetyService } from '../../services';

const SafetyMap = ({ currentLocation, safetyScore }) => {
  const [restrictedZones, setRestrictedZones] = useState([]);

  useEffect(() => {
    loadRestrictedZones();
  }, []);

  const loadRestrictedZones = async () => {
    try {
      const zones = await api.get('/zones/list');
      setRestrictedZones(zones.data);
    } catch (error) {
      console.error('Failed to load zones:', error);
    }
  };

  const getMarkerColor = (zoneType) => {
    switch (zoneType) {
      case 'safe': return '#4CAF50';
      case 'risky': return '#FF9800';
      case 'restricted': return '#F44336';
      default: return '#2196F3';
    }
  };

  return (
    <MapView
      style={{ flex: 1 }}
      region={{
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        latitudeDelta: 0.01,
        longitudeDelta: 0.01,
      }}
      showsUserLocation={true}
      showsMyLocationButton={true}
    >
      {/* Current location marker */}
      <Marker
        coordinate={currentLocation}
        title="Your Location"
        description={`Safety Score: ${safetyScore}`}
        pinColor={safetyService.getRiskLevelColor(safetyScore)}
      />

      {/* Restricted/Safe zones */}
      {restrictedZones.map((zone, index) => (
        <Circle
          key={index}
          center={{
            latitude: zone.center_lat,
            longitude: zone.center_lon
          }}
          radius={zone.radius}
          fillColor={`${getMarkerColor(zone.zone_type)}33`}
          strokeColor={getMarkerColor(zone.zone_type)}
          strokeWidth={2}
        />
      ))}
    </MapView>
  );
};

export default SafetyMap;
```

---

## 📱 Core Screens Implementation

### Home Screen with Safety Dashboard
```javascript
// src/screens/HomeScreen.js
import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert } from 'react-native';
import { useDispatch, useSelector } from 'react-redux';
import { emergencyService, safetyService, locationService } from '../services';

const HomeScreen = ({ navigation }) => {
  const [safetyScore, setSafetyScore] = useState(100);
  const [currentLocation, setCurrentLocation] = useState(null);
  const [isTracking, setIsTracking] = useState(false);

  useEffect(() => {
    initializeLocation();
    loadSafetyScore();
  }, []);

  const initializeLocation = async () => {
    try {
      const hasPermission = await locationService.requestPermissions();
      if (hasPermission) {
        const location = await locationService.getCurrentLocation();
        setCurrentLocation(location.coords);
        startLocationTracking();
      }
    } catch (error) {
      Alert.alert('Location Error', error.message);
    }
  };

  const startLocationTracking = async () => {
    const watchId = await locationService.startLocationTracking(
      async (position) => {
        setCurrentLocation(position.coords);
        await locationService.updateLocationToServer(position);
        await loadSafetyScore();
      }
    );
    setIsTracking(true);
  };

  const loadSafetyScore = async () => {
    try {
      const scoreData = await safetyService.getSafetyScore();
      setSafetyScore(scoreData.safety_score);
    } catch (error) {
      console.error('Failed to load safety score:', error);
    }
  };

  const handleSOS = async () => {
    if (!currentLocation) {
      Alert.alert('Error', 'Location not available');
      return;
    }

    Alert.alert(
      'Emergency SOS',
      'Are you sure you want to trigger emergency alert?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'YES - EMERGENCY',
          style: 'destructive',
          onPress: async () => {
            try {
              await emergencyService.triggerSOS(currentLocation);
              Alert.alert('Emergency Alert Sent', 'Help is on the way!');
            } catch (error) {
              Alert.alert('Error', 'Failed to send emergency alert');
            }
          }
        }
      ]
    );
  };

  return (
    <View style={styles.container}>
      {/* Safety Score Display */}
      <View style={styles.safetyCard}>
        <Text style={styles.safetyTitle}>Your Safety Score</Text>
        <Text style={[
          styles.safetyScore,
          { color: safetyService.getRiskLevelColor(safetyScore) }
        ]}>
          {safetyScore}
        </Text>
        <Text style={styles.riskLevel}>
          {safetyService.getRiskLevelText(safetyScore)}
        </Text>
      </View>

      {/* Quick Actions */}
      <View style={styles.actionsContainer}>
        <TouchableOpacity 
          style={styles.mapButton}
          onPress={() => navigation.navigate('Map')}
        >
          <Text style={styles.buttonText}>View Map</Text>
        </TouchableOpacity>

        <TouchableOpacity 
          style={styles.tripButton}
          onPress={() => navigation.navigate('Trip')}
        >
          <Text style={styles.buttonText}>Start Trip</Text>
        </TouchableOpacity>
      </View>

      {/* Emergency SOS Button */}
      <TouchableOpacity 
        style={styles.sosButton}
        onPress={handleSOS}
      >
        <Text style={styles.sosText}>🚨 SOS</Text>
      </TouchableOpacity>

      {/* Status Indicators */}
      <View style={styles.statusContainer}>
        <Text style={styles.statusText}>
          📍 Location Tracking: {isTracking ? 'Active' : 'Inactive'}
        </Text>
        {currentLocation && (
          <Text style={styles.locationText}>
            📍 {currentLocation.latitude.toFixed(4)}, {currentLocation.longitude.toFixed(4)}
          </Text>
        )}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
    padding: 20,
  },
  safetyCard: {
    backgroundColor: 'white',
    borderRadius: 15,
    padding: 30,
    alignItems: 'center',
    marginBottom: 30,
    elevation: 3,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  safetyTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 10,
  },
  safetyScore: {
    fontSize: 48,
    fontWeight: 'bold',
    marginBottom: 5,
  },
  riskLevel: {
    fontSize: 16,
    color: '#666',
  },
  actionsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 30,
  },
  mapButton: {
    flex: 1,
    backgroundColor: '#2196F3',
    padding: 15,
    borderRadius: 10,
    marginRight: 10,
    alignItems: 'center',
  },
  tripButton: {
    flex: 1,
    backgroundColor: '#4CAF50',
    padding: 15,
    borderRadius: 10,
    marginLeft: 10,
    alignItems: 'center',
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
  sosButton: {
    backgroundColor: '#F44336',
    padding: 20,
    borderRadius: 50,
    alignItems: 'center',
    marginBottom: 30,
    elevation: 5,
  },
  sosText: {
    color: 'white',
    fontSize: 24,
    fontWeight: 'bold',
  },
  statusContainer: {
    backgroundColor: 'white',
    padding: 15,
    borderRadius: 10,
    elevation: 2,
  },
  statusText: {
    fontSize: 14,
    color: '#666',
    marginBottom: 5,
  },
  locationText: {
    fontSize: 12,
    color: '#999',
  },
});

export default HomeScreen;
```

---

## 🔄 Real-time Features

### WebSocket Integration
```javascript
// src/services/websocket.js
class WebSocketService {
  constructor() {
    this.ws = null;
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 5;
  }

  connect(userId) {
    try {
      this.ws = new WebSocket(`ws://your-backend-url:8000/ws/tourist/${userId}`);
      
      this.ws.onopen = () => {
        console.log('WebSocket connected');
        this.reconnectAttempts = 0;
      };

      this.ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        this.handleMessage(data);
      };

      this.ws.onclose = () => {
        console.log('WebSocket disconnected');
        this.reconnect(userId);
      };

      this.ws.onerror = (error) => {
        console.error('WebSocket error:', error);
      };
    } catch (error) {
      console.error('Failed to connect WebSocket:', error);
    }
  }

  handleMessage(data) {
    switch (data.type) {
      case 'safety_alert':
        this.showSafetyAlert(data.message);
        break;
      case 'emergency_response':
        this.showEmergencyResponse(data);
        break;
      case 'location_warning':
        this.showLocationWarning(data);
        break;
    }
  }

  showSafetyAlert(message) {
    // Show in-app notification
    Alert.alert('Safety Alert', message);
  }

  reconnect(userId) {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      setTimeout(() => this.connect(userId), 5000);
    }
  }

  disconnect() {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}

export default new WebSocketService();
```

---

## 📋 Implementation Checklist

### Phase 1: Basic App Structure ✅
- [ ] Set up React Native project with navigation
- [ ] Implement authentication screens (login/register)
- [ ] Create basic home screen with safety score display
- [ ] Integrate with SafeHorizon backend APIs
- [ ] Add location permissions and basic GPS tracking

### Phase 2: Safety Features ✅
- [ ] Implement real-time location tracking
- [ ] Add safety score visualization with color coding
- [ ] Create SOS emergency button with backend integration
- [ ] Build map screen with current location and safety zones
- [ ] Add push notifications for alerts

### Phase 3: Advanced Features ✅
- [ ] Implement trip planning and tracking
- [ ] Add offline map support
- [ ] Create panic mode (discrete emergency)
- [ ] Integrate voice commands for hands-free SOS
- [ ] Add biometric authentication

### Phase 4: Polish & Production ✅
- [ ] Comprehensive error handling and offline support
- [ ] Performance optimization and battery management
- [ ] Accessibility features and internationalization
- [ ] Security hardening and data encryption
- [ ] App store deployment and distribution

---

## 🚀 Quick Start Commands

```bash
# Create new React Native project
npx react-native init SafeHorizonTouristApp
cd SafeHorizonTouristApp

# Install core dependencies
npm install @react-navigation/native @react-navigation/stack
npm install react-native-maps react-native-geolocation-service
npm install @react-native-async-storage/async-storage
npm install @reduxjs/toolkit react-redux axios

# Install additional packages
npm install react-native-push-notification
npm install react-native-keychain react-native-biometrics
npm install react-native-voice react-native-sound
npm install react-native-permissions

# iOS specific setup
cd ios && pod install && cd ..

# Android permissions setup (add to android/app/src/main/AndroidManifest.xml)
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.VIBRATE" />

# Run the app
npx react-native run-android
# or
npx react-native run-ios
```

---

## 🔧 Configuration Files

### Backend API Configuration
```javascript
// src/config/api.js
export const API_CONFIG = {
  base_url: __DEV__ ? 'http://localhost:8000' : 'https://your-production-url.com',
  endpoints: {
    auth: {
      register: '/api/auth/register',
      login: '/api/auth/login',
      me: '/api/auth/me',
      debug: '/api/auth/debug-token',
    },
    location: {
      update: '/api/location/update',
      history: '/api/location/history',
    },
    safety: {
      score: '/api/safety/score',
      geofence: '/api/ai/geofence/check',
    },
    emergency: {
      sos: '/api/sos/trigger',
      contacts: '/api/notify/emergency-contacts',
    },
    trips: {
      start: '/api/trip/start',
      end: '/api/trip/end',
      history: '/api/trip/history',
    }
  }
};
```

This comprehensive solution provides everything needed to build a production-ready tourist safety mobile app that integrates seamlessly with your SafeHorizon backend! 🚀

The app will provide real-time safety monitoring, emergency response capabilities, and intelligent location-based recommendations to keep tourists safe during their travels.