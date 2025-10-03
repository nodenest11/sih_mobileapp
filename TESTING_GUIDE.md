# 🧪 Real-Time Features Testing Guide

## Quick Start Testing

### Prerequisites
1. ✅ Flutter app installed on physical device (recommended) or emulator
2. ✅ Location permissions granted (high accuracy)
3. ✅ Backend API running with test data
4. ✅ Internet connection active

---

## 1. 🚨 Panic Alert Detection Testing

### Setup:
```bash
# Create a test panic alert near your location via backend API
curl -X POST https://your-api.com/api/panic \
  -H "Content-Type: application/json" \
  -d '{
    "tourist_id": "TEST001",
    "latitude": 28.7041,  # Your lat + small offset
    "longitude": 77.1025, # Your lon + small offset
    "message": "Test emergency alert"
  }'
```

### Expected Behavior (within 10 seconds):
- [ ] **Notification**: Push notification with "🚨 Emergency Alert Nearby"
- [ ] **Vibration**: Strong 8-pulse pattern (800-300-800-300-800-300-500ms)
- [ ] **Home Screen**: Alert appears in "Nearby Alerts" section
- [ ] **Map Screen**: Red marker with distance badge appears
- [ ] **Badge Count**: App bar shows alert count

### Validation Steps:
1. Open app home screen
2. Wait maximum 10 seconds
3. Check notification tray
4. Verify home screen alert card
5. Navigate to map screen
6. Tap panic marker → See details dialog

---

## 2. 🗺️ Map Integration Testing

### Test Steps:
1. **Open Map Screen**
   ```
   Home → Navbar → Map Icon
   ```

2. **Verify Map Layers**:
   - [ ] Blue dot shows your current location
   - [ ] Heatmap zones visible (toggle with eye icon)
   - [ ] Restricted zones show as colored polygons (toggle with shield icon)
   - [ ] Red panic markers with distance badges

3. **Test Alert Badge**:
   - [ ] App bar shows alert count (e.g., "🚨 3")
   - [ ] Badge updates when new alerts detected

4. **Test Panic Marker**:
   - [ ] Tap marker → Opens details dialog
   - [ ] Distance shows in km (e.g., "2.3 km away")
   - [ ] Status shows "Unresolved emergency"
   - [ ] Coordinates displayed
   - [ ] Safety advisory visible
   - [ ] "Center on Map" button works

5. **Test Restricted Zones**:
   - [ ] Zones show as polygons with labels
   - [ ] Colors: Red (dangerous), Orange (high risk), Yellow (restricted)
   - [ ] Toggle button shows/hides zones
   - [ ] Zone names visible on polygons

---

## 3. 🔄 Real-Time Updates Testing

### Scenario: Create New Alert While App Open

1. **Keep map screen open**
2. **Create new panic alert via backend** (within 5km)
3. **Expected behavior** (within 10 seconds):
   - [ ] New red marker appears on map automatically
   - [ ] Alert count badge updates
   - [ ] Notification delivered
   - [ ] Vibration triggered

### Scenario: Move Location

1. **Start with app open on map screen**
2. **Walk/drive 50+ meters**
3. **Expected behavior**:
   - [ ] Blue user marker moves smoothly
   - [ ] Proximity re-calculated
   - [ ] Distance badges update
   - [ ] New checks triggered

---

## 4. 🚧 Geofencing Testing

### Setup: Create Test Restricted Zone
```bash
# Create via backend admin panel or API
Zone: {
  name: "Test Restricted Area",
  type: "restricted",
  center: { lat: 28.7041, lon: 77.1025 },
  radius_meters: 1000
}
```

### Test Steps:
1. **View zone on map**:
   - [ ] Polygon displayed with yellow/orange/red color
   - [ ] Border clearly visible
   - [ ] Zone name labeled

2. **Approach zone** (get within 500m):
   - [ ] Proximity warning may trigger
   - [ ] Distance updates continuously

3. **Enter zone** (cross boundary):
   - [ ] **Orange snackbar** appears: "⚠️ [Zone Name]"
   - [ ] Zone description shown
   - [ ] **Vibration** feedback
   - [ ] "OK" button to dismiss

4. **Exit zone**:
   - [ ] Exit event logged (check AppLogger)

---

## 5. 🏠 Home Screen Integration Testing

### Test Flow:
1. **Open home screen**
2. **Verify "Nearby Alerts" section**:
   - [ ] Shows up to 3 alerts
   - [ ] Each card displays:
     - Alert title
     - Distance (e.g., "1.2 km")
     - Severity color (red/orange/yellow)
     - Time indicator
   - [ ] "View All on Map" button visible

3. **Tap "View All on Map"**:
   - [ ] Navigates to map screen
   - [ ] Map shows all alerts
   - [ ] User location centered

4. **Tap alert card**:
   - [ ] Opens details dialog
   - [ ] Safety tips displayed
   - [ ] "View on Map" button works (not yet implemented - logs to console)

5. **Tap "View all X alerts"** (if >3):
   - [ ] Shows full list dialog
   - [ ] All alerts scrollable
   - [ ] Can tap individual alerts

---

## 6. 📱 Background Monitoring Testing

### Test Continuous Monitoring:

1. **Start monitoring**:
   - [ ] Open app
   - [ ] Proximity service auto-starts
   - [ ] Check logs: "✅ Proximity alert monitoring started (real-time mode)"

2. **Leave app open in background** (don't force close):
   - [ ] Location updates every 50m
   - [ ] Proximity checks every 10s
   - [ ] Geofence checks every 5s

3. **Create test alert while in background**:
   - [ ] Notification delivered
   - [ ] When app reopened, alert visible

4. **Monitor logs** (via Android Studio or Xcode):
   ```
   Look for:
   - "🌍 Continuous location tracking started"
   - "🔍 Checking for nearby panic alerts..."
   - "🚨 REAL-TIME ALERT: Unresolved panic alert X.Xkm away"
   ```

---

## 7. 🔔 Notification Testing

### Test Channels:

1. **Proximity Panic Alerts**:
   - [ ] High priority notification
   - [ ] Red LED color
   - [ ] Strong vibration
   - [ ] Sound plays

2. **Geofence Alerts**:
   - [ ] High priority notification
   - [ ] Orange LED color
   - [ ] Medium vibration
   - [ ] Sound plays

### Test Settings:
```
Android: Settings → Apps → SafeHorizon → Notifications
- Verify "Nearby Panic Alerts" channel enabled
- Verify "Nearby Restricted Zones" channel enabled
- Verify importance set to HIGH/MAX

iOS: Settings → Notifications → SafeHorizon
- Verify alerts enabled
- Verify sounds enabled
- Verify badges enabled
```

---

## 8. 🎯 Performance Testing

### Metrics to Monitor:

1. **Response Times**:
   - [ ] Alert detection: <10 seconds
   - [ ] Notification delivery: <2 seconds
   - [ ] Map marker appearance: <1 second
   - [ ] UI refresh: <500ms

2. **Battery Impact**:
   - Run for 30 minutes
   - Check battery drain (should be <5% with GPS)

3. **Memory Usage**:
   - Monitor via Android Studio Profiler
   - Should stay under 200MB

4. **Network Usage**:
   - Monitor API calls
   - Should be minimal (only on check intervals)

---

## 9. 🐛 Edge Case Testing

### Scenario: No Internet
1. Disable WiFi/Mobile data
2. Expected:
   - [ ] Map tiles cached (works offline)
   - [ ] Last known alerts still visible
   - [ ] No new alerts fetched (graceful error)
   - [ ] Location tracking still works

### Scenario: GPS Disabled
1. Disable location services
2. Expected:
   - [ ] Warning message displayed
   - [ ] Monitoring stops gracefully
   - [ ] No crashes

### Scenario: Multiple Alerts at Same Location
1. Create 3+ alerts at same coordinates
2. Expected:
   - [ ] Single marker displayed
   - [ ] Tapping shows first/nearest alert
   - [ ] All alerts accessible via home screen

### Scenario: Rapid Location Changes
1. Simulate via Android Studio location mock
2. Expected:
   - [ ] Location updates smooth
   - [ ] No excessive API calls
   - [ ] Distance calculations accurate

---

## 10. ✅ Acceptance Criteria Checklist

### Core Features:
- [ ] Panic alerts detected within 10 seconds
- [ ] Map shows all nearby alerts (within 5km)
- [ ] Restricted zones display as polygons
- [ ] Background monitoring continuous
- [ ] Notifications with vibration work
- [ ] Real-time updates without refresh
- [ ] Distance calculations accurate (<1% error)
- [ ] Geofence entry/exit detected

### User Experience:
- [ ] Smooth map interactions (no lag)
- [ ] Clear visual indicators (colors/badges)
- [ ] Intuitive navigation (home ↔ map)
- [ ] Informative dialogs (safety tips)
- [ ] Responsive UI (<500ms updates)

### Performance:
- [ ] Battery drain acceptable (<10%/hour)
- [ ] Memory usage stable (<200MB)
- [ ] Network usage minimal (<1MB/10min)
- [ ] No crashes or freezes

### Privacy & Safety:
- [ ] No sensitive location data sent to backend
- [ ] Public API used for panic alerts
- [ ] User location only on device
- [ ] Safety recommendations displayed

---

## 🚨 Known Issues & Limitations

### Current Limitations:
1. **iOS Background Limitations**: iOS may suspend background location updates after ~3 minutes unless using specific background modes
2. **Notification Permissions**: User must explicitly grant notification permissions
3. **Battery Impact**: Continuous GPS tracking will impact battery life
4. **Network Dependency**: Real-time alerts require active internet connection

### Workarounds:
- iOS: Implement background location updates with "Location updates when in use"
- Battery: Provide user toggle for monitoring frequency
- Offline: Cache last known alerts for offline viewing

---

## 📊 Success Metrics

### Testing Complete When:
- ✅ All 10 test sections passed
- ✅ No critical bugs found
- ✅ Performance within acceptable ranges
- ✅ User experience smooth and intuitive
- ✅ Edge cases handled gracefully

---

## 🔧 Debugging Commands

### View Logs:
```bash
# Android
adb logcat | grep -E "(SafeHorizon|ProximityAlert|Geofence)"

# iOS
xcrun simctl spawn booted log stream --predicate 'processImagePath contains "SafeHorizon"'

# Flutter
flutter logs
```

### Clear App Data (Fresh Start):
```bash
# Android
adb shell pm clear com.tourist.safety

# iOS
Reset via Settings → General → Reset → Reset Location & Privacy
```

### Mock Location (Android Studio):
```
Tools → Device Manager → Your Device → Location → Set coordinates
```

---

## 📞 Support

### If Tests Fail:
1. Check logs for errors
2. Verify API endpoint configurations
3. Confirm backend is returning test data
4. Validate location permissions granted
5. Restart app and try again

### Contact:
- Developer: Check GitHub Issues
- Logs: Attach `flutter logs` output
- Screenshots: Include for visual bugs

---

**Happy Testing! 🎉**

Last Updated: October 3, 2025
