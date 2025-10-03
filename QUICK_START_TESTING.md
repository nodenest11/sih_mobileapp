# Quick Start Guide - Testing Proximity Alerts

## 🚀 How to Test the New Feature

### Prerequisites
✅ App is running with location permissions enabled
✅ Backend API is accessible
✅ At least one unresolved panic alert exists in database

---

## Step-by-Step Testing

### 1. **Start the App**
```bash
flutter run
```

### 2. **Login**
- Use existing tourist credentials
- App will initialize all services

### 3. **Navigate to Home Screen**
- You should see:
  - Safety Score widget
  - Location status
  - SOS button
  - Quick actions

### 4. **Wait for Proximity Check**
- Service checks every 30 seconds
- First check happens immediately
- Watch console logs for:
  ```
  🔍 Checking for nearby panic alerts...
  📍 Found X unresolved panic alerts
  🚨 Found Y alerts within 5km
  ```

### 5. **If Alerts Found (within 5km)**

#### A. Home Screen Updates
You should see a new section appear:

```
┌─────────────────────────────────┐
│ 🚨 Nearby Alerts            [X] │
│                                 │
│ ⚠️  Emergency situations or      │
│     restricted zones detected   │
│                                 │
│ ─────────────────────────────── │
│                                 │
│ [Alert cards appear here]       │
└─────────────────────────────────┘
```

#### B. Notification
- **Critical (< 1km)**: Full-screen notification
- **High (< 2.5km)**: Standard notification
- **Medium (< 5km)**: In-app only

#### C. Vibration
- Haptic feedback triggered based on severity
- Check device vibrates

### 6. **Interact with Alerts**

#### Tap Alert Card
- Opens detailed dialog
- Shows:
  - Severity badge
  - Distance and time
  - Safety tips
  - Action buttons

#### Tap "View on Map"
- Currently logs to console
- Future: Will navigate to map

#### Tap X (Dismiss)
- Removes alert from list
- Will not show again (tracked)

---

## 🧪 Testing Scenarios

### Scenario 1: No Alerts Nearby
**Expected**:
- ✅ No "Nearby Alerts" section
- ✅ Console: "No panic alerts within 5km"
- ✅ No notifications

### Scenario 2: Alert at 3km (Medium)
**Expected**:
- ✅ "Nearby Alerts" section appears
- ✅ Yellow alert card shown
- ✅ In-app display only
- ✅ Single vibration

### Scenario 3: Alert at 1.5km (High)
**Expected**:
- ✅ Orange alert card
- ✅ Push notification
- ✅ Medium vibration (2 pulses)
- ✅ In-app card

### Scenario 4: Alert at 0.5km (Critical)
**Expected**:
- ✅ Red alert card
- ✅ Full-screen notification
- ✅ Strong vibration (3 pulses)
- ✅ Automatic dialog popup
- ✅ In-app card

### Scenario 5: Multiple Alerts
**Expected**:
- ✅ Up to 3 cards shown
- ✅ "View all X alerts" button if > 3
- ✅ Sorted by distance (nearest first)
- ✅ Each with different severity color

### Scenario 6: Dismiss Alert
**Steps**:
1. Tap X on an alert card
2. Card disappears immediately
3. Refresh app (pull-to-refresh)
4. Alert does not reappear

**Expected**:
- ✅ Alert removed from list
- ✅ Tracked in acknowledged set
- ✅ Won't show again

---

## 📱 Console Logs to Watch

### Initialization
```
🔔 Initializing Firebase Cloud Messaging...
✅ FCM initialized at app startup
✅ Proximity Alert Service initialized
🔍 Starting proximity alert monitoring...
✅ Proximity alert monitoring started
✅ Proximity alerts monitoring initialized
```

### Periodic Checks
```
🔍 Checking for nearby panic alerts...
📡 Fetching public panic alerts (no auth required)
🚨 Public panic alerts: 1 active / 4 total
📍 Found 4 unresolved panic alerts
🚨 Found 2 unresolved panic alerts within 5km
```

### Alert Detection
```
🚨 Proximity alert: Unresolved panic alert 2.3km away (HIGH)
📲 Panic alert notification sent
```

### User Interaction
```
User wants to view alert on map
```

---

## 🐛 Troubleshooting

### Problem: No Alerts Section Showing
**Solutions**:
1. ✅ Check location permissions granted
2. ✅ Ensure location tracking is active
3. ✅ Verify backend has unresolved alerts
4. ✅ Check console for API errors
5. ✅ Ensure alerts are within 5km

### Problem: Notifications Not Showing
**Solutions**:
1. ✅ Check notification permissions
2. ✅ Verify notification channels created
3. ✅ Check device notification settings
4. ✅ Look for errors in console

### Problem: Same Alert Keeps Appearing
**Solutions**:
1. ✅ Check `_acknowledgedPanicAlerts` set
2. ✅ Verify alert_id is unique
3. ✅ Clear app data and retry
4. ✅ Check for duplicate API responses

### Problem: Vibration Not Working
**Solutions**:
1. ✅ Check device has vibration support
2. ✅ Verify vibration permission
3. ✅ Check device is not in silent mode
4. ✅ Test on physical device (not simulator)

---

## 🔧 Developer Testing Tools

### Force Refresh Acknowledged Alerts
Add to home screen temporarily:
```dart
ElevatedButton(
  onPressed: () {
    _proximityAlertService.resetAcknowledged();
    setState(() {
      _proximityAlerts.clear();
    });
  },
  child: Text('Reset Alerts'),
),
```

### Manual Trigger Test
Add to home screen temporarily:
```dart
ElevatedButton(
  onPressed: () async {
    await _proximityAlertService._checkProximity();
  },
  child: Text('Check Now'),
),
```

### View Acknowledged Set
Add temporary logging:
```dart
print('Acknowledged alerts: ${_proximityAlertService._acknowledgedPanicAlerts}');
```

---

## 📊 Success Criteria

### ✅ Feature is Working If:
1. **Service starts** without errors
2. **API calls succeed** every 30 seconds
3. **Alerts appear** when within 5km
4. **Notifications show** for high/critical
5. **Vibration works** based on severity
6. **UI updates** correctly
7. **Dismiss works** (no re-appearance)
8. **Dialog shows** for critical alerts
9. **No duplicate** notifications
10. **Battery usage** is reasonable

---

## 🎯 Test Checklist

Print and check off as you test:

- [ ] App starts without errors
- [ ] Location permission granted
- [ ] Notification permission granted
- [ ] Service initializes successfully
- [ ] First check happens immediately
- [ ] Periodic checks every 30s
- [ ] API calls succeed
- [ ] Alerts appear if nearby
- [ ] Correct severity colors
- [ ] Correct distance shown
- [ ] Correct time shown
- [ ] Tap card opens dialog
- [ ] Dialog shows all details
- [ ] Safety tips relevant
- [ ] Dismiss removes card
- [ ] View all button works (if >3)
- [ ] Critical alerts auto-dialog
- [ ] Notifications appear
- [ ] Vibration triggers
- [ ] No duplicate alerts
- [ ] Pull-to-refresh works

---

## 📸 Screenshots to Verify

Take screenshots of:

1. **Home screen** with "Nearby Alerts" section
2. **Alert card** (medium severity - yellow)
3. **Alert card** (high severity - orange)
4. **Alert card** (critical severity - red)
5. **Alert detail dialog**
6. **Notification** (from notification shade)
7. **"View all" dialog** (if >3 alerts)
8. **Empty state** (no alerts nearby)

---

## 🚦 Status Indicators

### Everything Working:
```
✅ Green indicators:
   - Location tracking active
   - Proximity monitoring active
   - No errors in console

🚨 Alerts showing:
   - Nearby Alerts section visible
   - Correct severity colors
   - Accurate distances
```

### Something Wrong:
```
❌ Red flags:
   - API errors in console
   - No alerts despite nearby incidents
   - Duplicate notifications
   - App crashes
```

---

## 💡 Pro Tips

1. **Use real device** for testing (not simulator)
2. **Check console** for detailed logs
3. **Test different distances** by moving around
4. **Test different severities** with varying distances
5. **Test dismiss functionality** for each alert
6. **Monitor battery usage** during extended testing
7. **Check notification settings** if issues arise
8. **Verify backend data** has unresolved alerts

---

## 📞 Need Help?

**Check logs for**:
- API errors
- Location errors
- Permission errors
- Initialization errors

**Common fixes**:
- Restart app
- Clear app data
- Check permissions
- Verify backend connection
- Update dependencies

---

Happy Testing! 🎉
