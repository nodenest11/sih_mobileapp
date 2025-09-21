Build a Flutter mobile app for tourists that supports live tracking, OpenStreetMap-based maps, heatmap, panic button (sends live location to backend), geo-fencing popup alerts, safety score, and location search.

🔧 Tech Stack

Flutter (latest stable)

Dart

Dependencies:

flutter_map → Map (OpenStreetMap tiles, free)

latlong2 → Coordinate support

geolocator → Location tracking

http → API calls

flutter_heatmap → Heatmap overlay

provider or riverpod → State management

📂 Folder Structure
/lib
  main.dart
  /screens
    login_screen.dart
    home_screen.dart
    map_screen.dart
    profile_screen.dart
  /widgets
    panic_button.dart
    safety_score_widget.dart
    search_bar.dart
  /services
    api_service.dart
    location_service.dart
  /models
    tourist.dart
    location.dart
    alert.dart

⚙️ Features & Implementation
1. Login / Onboarding

Screen: Tourist enters Name + Tourist ID.

Store ID locally (shared_preferences).

Mock registration API call:

POST /registerTourist
body = { name, tourist_id }

2. Live Location Tracking

Use geolocator → update every 10s.

API call:

POST /updateLocation
body = { tourist_id, lat, lon, timestamp }

3. Map View (with Heatmap)

Use flutter_map with OSM tiles.

Tourist marker → blue dot.

Heatmap overlay → call backend:

GET /heatmap
returns: [{ lat, lon, intensity }]

4. Geo-fencing Alert

Fetch zones from backend:

GET /restrictedZones
returns: [{ id, name, polygon_coordinates }]


If tourist enters → show popup alert dialog:

“⚠ You have entered a restricted/high-risk area.”

5. Panic Button

Floating action button → red.

On press:

POST /panic
body = { tourist_id, lat, lon, timestamp }


Police dashboard sees location in real time.

6. Safety Score

API call:

GET /safetyScore/{tourist_id}
returns: { score: 0–100 }


Display color-coded badge:

Green = Safe (>80)

Yellow = Medium (60–79)

Red = Risk (<60)

7. Search Box (Nominatim)

User enters location name.

API call:

GET /search?query=Delhi
returns: { lat, lon }


Move map to that location.