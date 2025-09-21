# Environment Configuration

This app uses environment variables to configure API endpoints. This approach provides better security and flexibility for different deployment environments.

## Setup Instructions

1. **Copy the example environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Update the `.env` file with your actual values:**
   ```env
   # Backend API Configuration
   BASE_URL=http://localhost:8000  # Replace with your actual backend URL
   API_TIMEOUT=10
   NOMINATIM_URL=https://nominatim.openstreetmap.org
   ```

## Environment Variables

| Variable | Description | Required | Default | Example |
|----------|-------------|----------|---------|---------|
| `BASE_URL` | Backend API base URL | ✅ Yes | - | `http://localhost:8000` |
| `API_TIMEOUT` | API request timeout (seconds) | ✅ Yes | - | `10` |
| `NOMINATIM_URL` | OpenStreetMap search service | ✅ Yes | - | `https://nominatim.openstreetmap.org` |

## Development vs Production

### Development
```env
BASE_URL=http://localhost:8000
API_TIMEOUT=10
NOMINATIM_URL=https://nominatim.openstreetmap.org
```

### Production
```env
BASE_URL=https://your-production-api.com/api
API_TIMEOUT=15
NOMINATIM_URL=https://nominatim.openstreetmap.org
```

## Security Notes

- ✅ The `.env` file is added to `.gitignore` to prevent committing sensitive data
- ✅ No hardcoded URLs or fallback mechanisms in the code
- ✅ Environment variables are loaded at app startup
- ✅ All API configurations are centralized in the `.env` file

## API Endpoints Used

The app connects to these backend endpoints:
- `POST {BASE_URL}/tourists/register` - Tourist registration
- `POST {BASE_URL}/locations/update` - Location tracking
- `GET {BASE_URL}/locations/heatmap` - Heatmap data
- `GET {BASE_URL}/restrictedZones` - Restricted zones
- `POST {BASE_URL}/alerts/panic` - Panic alerts
- `GET {BASE_URL}/admin/{id}/risk-assessment` - Safety scores
- `GET {NOMINATIM_URL}/search` - Location search

## Troubleshooting

**App fails to start:**
- Ensure `.env` file exists in the project root
- Verify all required variables are set
- Check that URLs are properly formatted (no trailing slashes)

**API calls fail:**
- Verify `BASE_URL` points to a running backend
- Check network connectivity
- Ensure backend CORS settings allow mobile app requests