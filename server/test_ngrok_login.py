#!/usr/bin/env python3
"""
Test captain login through ngrok URL
"""

import requests
import json

def test_ngrok_login():
    # Test with ngrok URL
    url = "https://unstanding-unmenaced-pete.ngrok-free.dev/api/auth/login"
    
    data = {
        "email": "captain@barangay.gov",
        "password": "tatalaPunongBarangayadmin"
    }
    
    print("🧪 Testing Captain Login via Ngrok...")
    print(f"📧 Email: {data['email']}")
    print(f"🔑 Password: {data['password']}")
    print(f"🌐 URL: {url}")
    print("-" * 50)
    
    try:
        response = requests.post(url, json=data, timeout=10)
        print(f"📊 Status Code: {response.status_code}")
        print(f"📄 Response: {response.text}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ NGROK LOGIN SUCCESSFUL!")
            print(f"👤 User: {result.get('user', {}).get('full_name')}")
            print(f"🏷 Role: {result.get('user', {}).get('role')}")
        else:
            print("❌ NGROK LOGIN FAILED!")
            if response.status_code == 403:
                print("🚫 403 FORBIDDEN - Check CORS or authentication!")
            
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    test_ngrok_login()
