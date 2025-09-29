# Environment Configuration

## Setup Instructions

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Update the `.env` file with your configuration:**
   ```env
   # Backend Server URL - Update this when the server changes
   API_BASE_URL=http://172.15.1.112:8000
   API_PREFIX=/api

   # Network Configuration
   REQUEST_TIMEOUT_SECONDS=30

   # Debug Configuration
   DEBUG_MODE=true
   ```

## Configuration Options

### API_BASE_URL
The base URL of your SafeHorizon API server. Change this when your backend server IP or domain changes.

### API_PREFIX
The API path prefix (usually `/api`).

### REQUEST_TIMEOUT_SECONDS
HTTP request timeout in seconds (default: 30).

### DEBUG_MODE
Enable/disable debug logging throughout the app (true/false).

## Safety Score Fix

The safety score endpoint has been updated to properly handle the API response according to the backend documentation:

- ✅ Enhanced error handling for 401/403 authentication errors
- ✅ Better debugging with detailed request/response logging
- ✅ Fallback safety score when API fails
- ✅ Proper response format parsing

## Changes Made

1. **Added Environment Variables:**
   - Added `flutter_dotenv` dependency
   - Created `.env` configuration file
   - Updated ApiService to use environment variables

2. **Fixed Safety Score Endpoint:**
   - Enhanced error handling for authentication issues
   - Added detailed debug logging
   - Improved response format handling
   - Better fallback mechanisms

3. **Improved Debugging:**
   - Configurable debug mode via environment variables
   - Detailed request/response logging for troubleshooting
   - Better error messages for authentication issues

## Usage

The app will automatically load the environment configuration on startup. You can change the server URL by updating the `.env` file and restarting the app.

**Note:** The `.env` file is ignored by git to prevent sensitive configuration from being committed. Always use `.env.example` as a template for new setups.