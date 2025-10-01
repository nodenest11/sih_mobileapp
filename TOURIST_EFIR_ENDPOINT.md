# 🚨 E-FIR Generation Endpoint for Tourist Mobile App

## Overview
This endpoint allows tourists to generate an **Electronic First Information Report (E-FIR)** directly from their mobile app to report incidents like harassment, theft, assault, or any emergency situations. The E-FIR is stored on a blockchain-backed system for immutability and legal validity.

---

## 📍 Endpoint Details

### **POST** `/api/tourist/efir/generate`

Generate an E-FIR for tourist-reported incidents with blockchain verification.

---

## 🔐 Authentication

**Required:** Bearer Token (JWT)

```http
Authorization: Bearer <your_jwt_token>
```

**Role Required:** `tourist` or `admin`

---

## 📥 Request

### Headers
```http
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Body Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `incident_description` | string | ✅ Yes | Detailed description of the incident (max 5000 chars recommended) |
| `incident_type` | string | ✅ Yes | Type of incident: `"harassment"`, `"theft"`, `"assault"`, `"fraud"`, `"emergency"`, `"other"` |
| `location` | string | ❌ Optional | Human-readable location (e.g., "Near Taj Mahal, Agra"). If not provided, uses last GPS location |
| `timestamp` | string (ISO 8601) | ❌ Optional | When incident occurred. Defaults to current time. Format: `"2025-10-02T14:30:00Z"` |
| `witnesses` | array[string] | ❌ Optional | List of witness names or descriptions |
| `additional_details` | string | ❌ Optional | Any additional information, evidence references, or notes |

### Request Example

```json
{
  "incident_description": "I was approached by two individuals near India Gate who attempted to snatch my bag. They were on a motorcycle and threatened me when I resisted. I managed to escape and reach a nearby shop.",
  "incident_type": "assault",
  "location": "India Gate, New Delhi, near Gate No. 2",
  "timestamp": "2025-10-02T14:45:00Z",
  "witnesses": [
    "Shop owner - Ram's Electronics",
    "Security guard at India Gate entrance"
  ],
  "additional_details": "Motorcycle: Black color, no visible number plate. Suspects: Two males, approximately 25-30 years old, wearing black jackets."
}
```

### cURL Example

```bash
curl -X POST "https://api.safehorizon.com/api/tourist/efir/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "incident_description": "Attempted theft at tourist location",
    "incident_type": "theft",
    "location": "Connaught Place, New Delhi",
    "timestamp": "2025-10-02T15:00:00Z",
    "witnesses": ["Local shopkeeper"],
    "additional_details": "Suspect wore red shirt and blue jeans"
  }'
```

---

## 📤 Response

### Success Response (200 OK)

```json
{
  "message": "E-FIR generated successfully",
  "fir_number": "EFIR-2025-10-550e8400e29b41d4a716446655440000-1727877600",
  "blockchain_tx_id": "0xa3f5b8c2d1e4f9a7b6c3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1",
  "timestamp": "2025-10-02T15:00:00Z",
  "verification_url": "/api/blockchain/verify/0xa3f5b8c2d1e4f9a7b6c3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1",
  "status": "submitted",
  "reference_number": "REF-TOURIST-1234"
}
```

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `message` | string | Success message |
| `fir_number` | string | Unique E-FIR number (Format: `EFIR-YYYY-MM-{tourist_id}-{timestamp}`) |
| `blockchain_tx_id` | string | Blockchain transaction ID for verification (starts with `0x`) |
| `timestamp` | string | When the E-FIR was generated |
| `verification_url` | string | URL to verify the E-FIR on blockchain |
| `status` | string | Submission status: `"submitted"` |
| `reference_number` | string | Internal reference number for tracking |

---

## ❌ Error Responses

### 401 Unauthorized
```json
{
  "detail": "Invalid authentication credentials"
}
```

### 403 Forbidden
```json
{
  "detail": "Access denied: Tourist role required. Current role: authority"
}
```

### 404 Not Found
```json
{
  "detail": "Tourist not found"
}
```

### 500 Internal Server Error
```json
{
  "detail": "Failed to generate E-FIR: Database connection error"
}
```

---

## 🔄 What Happens After E-FIR Generation?

1. **Blockchain Storage** 🔗
   - E-FIR is cryptographically hashed and stored
   - Transaction ID generated for immutable proof
   - Cannot be modified or deleted

2. **Alert Creation** 🚨
   - Automatic alert created in the system
   - Alert type: `MANUAL`
   - Severity: `MEDIUM`

3. **Police Notification** 👮
   - Real-time WebSocket notification sent to police dashboard
   - Police can view incident details immediately
   - Authorities can acknowledge and respond

4. **Tourist Tracking** 📊
   - E-FIR linked to tourist profile
   - Tourist can view submission status
   - Reference number provided for follow-up

---

## 📱 Mobile App Integration Examples

### React Native / Expo

```javascript
import AsyncStorage from '@react-native-async-storage/async-storage';

const generateEFIR = async (incidentData) => {
  try {
    // Get JWT token
    const token = await AsyncStorage.getItem('auth_token');
    
    const response = await fetch('https://api.safehorizon.com/api/tourist/efir/generate', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({
        incident_description: incidentData.description,
        incident_type: incidentData.type,
        location: incidentData.location,
        timestamp: new Date().toISOString(),
        witnesses: incidentData.witnesses || [],
        additional_details: incidentData.additionalDetails
      })
    });
    
    const data = await response.json();
    
    if (response.ok) {
      console.log('E-FIR Generated:', data.fir_number);
      console.log('Reference:', data.reference_number);
      console.log('Blockchain TX:', data.blockchain_tx_id);
      
      // Show success message to user
      Alert.alert(
        'E-FIR Submitted Successfully',
        `Your report has been filed.\nReference: ${data.reference_number}\nFIR Number: ${data.fir_number}`,
        [{ text: 'OK' }]
      );
      
      return data;
    } else {
      throw new Error(data.detail || 'Failed to generate E-FIR');
    }
  } catch (error) {
    console.error('E-FIR Generation Error:', error);
    Alert.alert('Error', error.message);
    throw error;
  }
};

// Usage Example
const handleReportIncident = async () => {
  const incidentData = {
    description: 'Attempted theft at market',
    type: 'theft',
    location: 'Chandni Chowk Market',
    witnesses: ['Shop owner - Ram Kumar'],
    additionalDetails: 'Suspect wore blue shirt'
  };
  
  await generateEFIR(incidentData);
};
```

### Flutter / Dart

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

Future<Map<String, dynamic>> generateEFIR({
  required String incidentDescription,
  required String incidentType,
  String? location,
  List<String>? witnesses,
  String? additionalDetails,
}) async {
  try {
    // Get JWT token
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    final response = await http.post(
      Uri.parse('https://api.safehorizon.com/api/tourist/efir/generate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'incident_description': incidentDescription,
        'incident_type': incidentType,
        'location': location,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'witnesses': witnesses ?? [],
        'additional_details': additionalDetails,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      print('E-FIR Generated: ${data['fir_number']}');
      print('Reference: ${data['reference_number']}');
      
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to generate E-FIR');
    }
  } catch (e) {
    print('E-FIR Generation Error: $e');
    rethrow;
  }
}

// Usage
await generateEFIR(
  incidentDescription: 'Harassment by local vendors',
  incidentType: 'harassment',
  location: 'Janpath Market, Delhi',
  witnesses: ['Market security guard'],
  additionalDetails: 'Multiple vendors involved',
);
```

### JavaScript / Axios

```javascript
import axios from 'axios';

const generateEFIR = async (incidentData) => {
  try {
    const token = localStorage.getItem('auth_token');
    
    const response = await axios.post(
      'https://api.safehorizon.com/api/tourist/efir/generate',
      {
        incident_description: incidentData.description,
        incident_type: incidentData.type,
        location: incidentData.location,
        timestamp: new Date().toISOString(),
        witnesses: incidentData.witnesses || [],
        additional_details: incidentData.additionalDetails
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        }
      }
    );
    
    console.log('E-FIR Generated:', response.data);
    return response.data;
    
  } catch (error) {
    console.error('E-FIR Generation Error:', error.response?.data || error.message);
    throw error;
  }
};
```

---

## 🎯 Incident Types Reference

| Type | Description | Use Case |
|------|-------------|----------|
| `harassment` | Verbal or physical harassment | Unwanted attention, stalking, catcalling |
| `theft` | Theft or attempted theft | Pickpocketing, bag snatching, robbery |
| `assault` | Physical assault | Physical attack, violence |
| `fraud` | Fraud or scam | Overcharging, fake services, scams |
| `emergency` | Emergency situation | Immediate danger, accident |
| `other` | Other incidents | Any other reportable incident |

---

## 🔍 E-FIR Verification

After generating an E-FIR, tourists can verify it using the blockchain transaction ID:

```http
GET /api/blockchain/verify/{blockchain_tx_id}
```

### Verification Response

```json
{
  "valid": true,
  "tx_id": "0xa3f5b8c2d1e4f9a7b6c3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1",
  "status": "confirmed",
  "chain_id": "safehorizon-efir-chain",
  "verified_at": "2025-10-02T15:05:00Z"
}
```

---

## 📋 Best Practices

### For Tourists

1. **Provide Detailed Information**
   - Include as much detail as possible in the description
   - Mention specific locations, times, and people involved
   - Add witnesses if available

2. **Use Correct Incident Type**
   - Select the most appropriate incident type
   - Use `"other"` if unsure

3. **Include Location Data**
   - Either provide a text location or ensure GPS is enabled
   - The system will use your last known GPS coordinates if no location is provided

4. **Keep Reference Number**
   - Save the FIR number and reference number
   - Use these for follow-up with authorities

5. **Immediate Danger?**
   - If in immediate danger, use the SOS button instead: `/api/sos/trigger`
   - E-FIR is for reporting incidents, not emergency response

### For Developers

1. **Error Handling**
   - Always handle network errors gracefully
   - Show user-friendly error messages
   - Retry failed submissions

2. **Token Management**
   - Ensure JWT token is valid before submission
   - Refresh token if expired

3. **Offline Support**
   - Cache E-FIR data locally if submission fails
   - Retry when connection is restored

4. **User Feedback**
   - Show loading indicator during submission
   - Display success message with reference number
   - Allow users to copy/share FIR details

---

## 🔒 Security & Privacy

- **Blockchain Immutability:** Once generated, E-FIR cannot be modified
- **Cryptographic Verification:** SHA-256 hashing ensures data integrity
- **Access Control:** Only tourist and authorities can access E-FIR details
- **Data Privacy:** Personal information is encrypted in transit (HTTPS)

---

## 📞 Support

If tourists face issues with E-FIR generation:

1. Check JWT token validity
2. Ensure network connectivity
3. Verify all required fields are provided
4. Contact support: `support@safehorizon.com`
5. Use reference number for tracking

---

## 🔗 Related Endpoints

- **SOS Emergency:** `POST /api/sos/trigger` - Immediate emergency response
- **View Alerts:** `GET /api/tourist/alerts` - View generated alerts
- **Location Update:** `POST /api/location/update` - Update GPS location
- **Safety Score:** `GET /api/safety/score` - Check current safety score

---

## 📊 E-FIR Workflow Diagram

```
Tourist Mobile App
       |
       | POST /api/tourist/efir/generate
       v
  FastAPI Server
       |
       ├──> Validate JWT Token
       ├──> Fetch Tourist Data
       ├──> Generate Unique FIR Number
       ├──> Create Blockchain Transaction (SHA-256)
       ├──> Store in Database (alerts table)
       ├──> Notify Police Dashboard (WebSocket)
       └──> Return FIR Number & Blockchain TX ID
              |
              v
       Tourist receives:
       ✅ FIR Number
       ✅ Reference Number
       ✅ Blockchain TX ID
       ✅ Verification URL
```

---

## 📝 Notes

- **FIR Number Format:** `EFIR-{YYYY-MM}-{tourist_id}-{unix_timestamp}`
- **Blockchain TX ID:** 66-character hexadecimal string starting with `0x`
- **Alert Type:** Auto-created alert with type `MANUAL` and severity `MEDIUM`
- **WebSocket Notification:** Police dashboard receives real-time notification
- **Legal Validity:** E-FIR can be used as evidence due to blockchain backing

---

## 🆘 Emergency vs E-FIR

| Feature | E-FIR | SOS |
|---------|-------|-----|
| **Purpose** | Report past incidents | Immediate emergency |
| **Response** | Police review & follow-up | Instant alert to authorities |
| **Urgency** | Non-urgent documentation | Critical/urgent |
| **Use Case** | Theft, fraud, harassment | Danger, assault, emergency |
| **Endpoint** | `/tourist/efir/generate` | `/sos/trigger` |

**Rule of Thumb:** 
- **In danger NOW?** → Use SOS button
- **Reporting past incident?** → Use E-FIR

---

**Last Updated:** October 2, 2025  
**API Version:** v1.0  
**Contact:** support@safehorizon.com
