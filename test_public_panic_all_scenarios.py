"""
Comprehensive test suite for /api/public/panic-alerts endpoint
Tests all scenarios mentioned in PUBLIC_PANIC_ALERTS_API.md
"""
import requests
import json
from datetime import datetime

BASE_URL = "http://localhost:8000"
ENDPOINT = f"{BASE_URL}/api/public/panic-alerts"

def print_test_header(test_name):
    print("\n" + "="*80)
    print(f"TEST: {test_name}")
    print("="*80)

def print_response(response, show_full=False):
    print(f"Status Code: {response.status_code}")
    print(f"Response Time: {response.elapsed.total_seconds():.2f}s")
    
    if response.status_code == 200:
        data = response.json()
        print(f"\nSummary:")
        print(f"  Total Alerts: {data.get('total_alerts', 0)}")
        print(f"  Active Count: {data.get('active_count', 0)}")
        print(f"  Hours Back: {data.get('hours_back', 0)}")
        print(f"  Alerts Returned: {len(data.get('alerts', []))}")
        
        if show_full:
            print(f"\nFull Response:")
            print(json.dumps(data, indent=2))
        else:
            # Show first alert as sample
            alerts = data.get('alerts', [])
            if alerts:
                print(f"\nFirst Alert Sample:")
                print(json.dumps(alerts[0], indent=2))
    else:
        print(f"\nError Response:")
        try:
            print(json.dumps(response.json(), indent=2))
        except:
            print(response.text)

# Test 1: Default Parameters
print_test_header("1. Default Parameters (no query params)")
try:
    response = requests.get(ENDPOINT, timeout=10)
    print_response(response)
    assert response.status_code == 200, "Should return 200 OK"
    print("✅ PASSED")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Test 2: Custom limit parameter
print_test_header("2. Custom Limit (limit=10)")
try:
    response = requests.get(ENDPOINT, params={'limit': 10}, timeout=10)
    print_response(response)
    assert response.status_code == 200, "Should return 200 OK"
    data = response.json()
    assert len(data['alerts']) <= 10, "Should return max 10 alerts"
    print("✅ PASSED")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Test 3: Custom hours_back parameter
print_test_header("3. Custom Hours Back (hours_back=12)")
try:
    response = requests.get(ENDPOINT, params={'hours_back': 12}, timeout=10)
    print_response(response)
    assert response.status_code == 200, "Should return 200 OK"
    data = response.json()
    assert data['hours_back'] == 12, "Should show hours_back=12"
    print("✅ PASSED")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Test 4: Both parameters
print_test_header("4. Both Parameters (limit=5, hours_back=6)")
try:
    response = requests.get(ENDPOINT, params={'limit': 5, 'hours_back': 6}, timeout=10)
    print_response(response)
    assert response.status_code == 200, "Should return 200 OK"
    data = response.json()
    assert len(data['alerts']) <= 5, "Should return max 5 alerts"
    assert data['hours_back'] == 6, "Should show hours_back=6"
    print("✅ PASSED")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Test 5: Minimum valid values
print_test_header("5. Minimum Valid Values (limit=1, hours_back=1)")
try:
    response = requests.get(ENDPOINT, params={'limit': 1, 'hours_back': 1}, timeout=10)
    print_response(response)
    assert response.status_code == 200, "Should return 200 OK"
    data = response.json()
    assert len(data['alerts']) <= 1, "Should return max 1 alert"
    print("✅ PASSED")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Test 6: Maximum valid values
print_test_header("6. Maximum Valid Values (limit=1000, hours_back=168)")
try:
    response = requests.get(ENDPOINT, params={'limit': 1000, 'hours_back': 168}, timeout=10)
    print_response(response)
    assert response.status_code == 200, "Should return 200 OK"
    data = response.json()
    assert data['hours_back'] == 168, "Should show hours_back=168 (7 days)"
    print("✅ PASSED")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Test 7: Invalid limit (too low)
print_test_header("7. Invalid Limit - Too Low (limit=0)")
try:
    response = requests.get(ENDPOINT, params={'limit': 0}, timeout=10)
    print_response(response)
    assert response.status_code == 400, "Should return 400 Bad Request"
    print("✅ PASSED")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Test 8: Invalid limit (negative)
print_test_header("8. Invalid Limit - Negative (limit=-5)")
try:
    response = requests.get(ENDPOINT, params={'limit': -5}, timeout=10)
    print_response(response)
    assert response.status_code == 400, "Should return 400 Bad Request"
    print("✅ PASSED")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Test 9: Invalid hours_back (too low)
print_test_header("9. Invalid Hours Back - Too Low (hours_back=0)")
try:
    response = requests.get(ENDPOINT, params={'hours_back': 0}, timeout=10)
    print_response(response)
    assert response.status_code == 400, "Should return 400 Bad Request"
    print("✅ PASSED")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Test 10: Invalid hours_back (negative)
print_test_header("10. Invalid Hours Back - Negative (hours_back=-10)")
try:
    response = requests.get(ENDPOINT, params={'hours_back': -10}, timeout=10)
    print_response(response)
    assert response.status_code == 400, "Should return 400 Bad Request"
    print("✅ PASSED")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Test 11: Invalid parameter type (string for limit)
print_test_header("11. Invalid Type - String for Limit (limit='abc')")
try:
    response = requests.get(ENDPOINT, params={'limit': 'abc'}, timeout=10)
    print_response(response)
    assert response.status_code == 422, "Should return 422 Validation Error"
    print("✅ PASSED")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Test 12: Invalid parameter type (string for hours_back)
print_test_header("12. Invalid Type - String for Hours (hours_back='xyz')")
try:
    response = requests.get(ENDPOINT, params={'hours_back': 'xyz'}, timeout=10)
    print_response(response)
    assert response.status_code == 422, "Should return 422 Validation Error"
    print("✅ PASSED")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Test 13: Response structure validation
print_test_header("13. Response Structure Validation")
try:
    response = requests.get(ENDPOINT, params={'limit': 10}, timeout=10)
    assert response.status_code == 200, "Should return 200 OK"
    
    data = response.json()
    
    # Check top-level fields
    assert 'total_alerts' in data, "Should have total_alerts field"
    assert 'active_count' in data, "Should have active_count field"
    assert 'hours_back' in data, "Should have hours_back field"
    assert 'alerts' in data, "Should have alerts array"
    assert 'timestamp' in data, "Should have timestamp field"
    assert 'note' in data, "Should have note field"
    
    # Check alert structure if alerts exist
    if data['alerts']:
        alert = data['alerts'][0]
        required_fields = ['alert_id', 'type', 'severity', 'title', 'description', 
                          'location', 'timestamp', 'time_ago', 'status']
        for field in required_fields:
            assert field in alert, f"Alert should have {field} field"
        
        # Check location structure if present
        if alert['location'] is not None:
            assert 'lat' in alert['location'], "Location should have lat"
            assert 'lon' in alert['location'], "Location should have lon"
            assert 'timestamp' in alert['location'], "Location should have timestamp"
    
    print_response(response, show_full=True)
    print("✅ PASSED - All required fields present")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Test 14: Privacy verification (no personal info)
print_test_header("14. Privacy Verification (No Personal Data)")
try:
    response = requests.get(ENDPOINT, params={'limit': 50}, timeout=10)
    assert response.status_code == 200, "Should return 200 OK"
    
    data = response.json()
    
    # Check that personal info fields are NOT present in alert objects
    forbidden_fields = ['email', 'phone', 'user_id', 'tourist_id', 
                        'first_name', 'last_name', 'password']
    
    # Check each alert for forbidden fields
    for alert in data.get('alerts', []):
        alert_text = json.dumps(alert).lower()
        for field in forbidden_fields:
            assert field not in alert_text, f"Alert should not contain {field} field"
    
    # Verify generic descriptions only
    for alert in data.get('alerts', []):
        assert alert['description'] == "Emergency situation - assistance needed", \
               "Should use generic description"
    
    print_response(response)
    print("✅ PASSED - No personal information exposed")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Test 15: Alert status verification
print_test_header("15. Alert Status Values Verification")
try:
    response = requests.get(ENDPOINT, params={'hours_back': 24}, timeout=10)
    assert response.status_code == 200, "Should return 200 OK"
    
    data = response.json()
    alerts = data.get('alerts', [])
    
    if alerts:
        statuses = set(alert['status'] for alert in alerts)
        valid_statuses = {'active', 'older'}
        
        for status in statuses:
            assert status in valid_statuses, f"Invalid status: {status}"
        
        print_response(response)
        print(f"\nFound statuses: {statuses}")
        print("✅ PASSED - All statuses are valid")
    else:
        print("No alerts to verify")
        print("✅ PASSED (no data)")
except Exception as e:
    print(f"❌ FAILED: {e}")

# Summary
print("\n" + "="*80)
print("TEST SUMMARY")
print("="*80)
print("All tests completed! Check results above for details.")
print("="*80)
