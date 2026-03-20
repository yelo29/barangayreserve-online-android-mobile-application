import requests
import json

BASE_URL = 'https://barangayreserve.dpdns.org'

def check_endpoints():
    """Check which Gmail auth endpoints are available"""
    print("🔍 Checking Gmail Authentication Endpoints")
    print("=" * 50)
    
    endpoints = [
        '/api/auth/google-login',
        '/api/auth/google-register'
    ]
    
    for endpoint in endpoints:
        print(f"\n📡 Checking: {endpoint}")
        
        # Try POST (expected method)
        try:
            response = requests.post(
                f'{BASE_URL}{endpoint}', 
                json={'idToken': 'test', 'email': 'test@test.com'},
                timeout=5
            )
            print(f"  POST: {response.status_code}")
            if response.status_code != 404:
                try:
                    data = response.json()
                    print(f"  Response: {data.get('message', 'No message')}")
                except:
                    print(f"  Response: {response.text[:100]}")
        except Exception as e:
            print(f"  POST: Error - {e}")
        
        # Try GET to see if endpoint exists
        try:
            response = requests.get(f'{BASE_URL}{endpoint}', timeout=5)
            print(f"  GET: {response.status_code}")
        except Exception as e:
            print(f"  GET: Error - {e}")

if __name__ == '__main__':
    check_endpoints()
