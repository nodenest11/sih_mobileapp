// Quick API test to understand the safety score failure
// Run this in your browser's developer console after opening the Flutter app
// Or use curl commands to test the API directly

const API_BASE_URL = 'http://192.168.31.239:8000';

// Test 1: Check auth status
async function testAuth() {
  const token = localStorage.getItem('tourist_token');
  console.log('🔑 Stored token:', token ? token.substring(0, 20) + '...' : 'none');
  
  const response = await fetch(`${API_BASE_URL}/api/auth/validate`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  
  console.log('🔍 Auth validation:', response.status, await response.text());
}

// Test 2: Check safety score directly
async function testSafetyScore() {
  const token = localStorage.getItem('tourist_token');
  
  const response = await fetch(`${API_BASE_URL}/api/safety/score`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  
  console.log('📊 Safety score response:', response.status);
  console.log('📊 Response body:', await response.text());
}

// Test 3: Check all API endpoints
async function testAllEndpoints() {
  const token = localStorage.getItem('tourist_token');
  const endpoints = [
    '/api/auth/validate',
    '/api/safety/score',
    '/api/zones/list',
    '/api/alerts/recent'
  ];
  
  for (const endpoint of endpoints) {
    try {
      const response = await fetch(`${API_BASE_URL}${endpoint}`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      console.log(`${endpoint}: ${response.status} ${response.statusText}`);
    } catch (error) {
      console.log(`${endpoint}: ERROR - ${error.message}`);
    }
  }
}

// Run tests
console.log('🧪 Running API tests...');
testAuth();
testSafetyScore(); 
testAllEndpoints();