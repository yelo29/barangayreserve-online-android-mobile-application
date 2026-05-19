#!/usr/bin/env python3
"""
Test captain login with hashed password
"""

import requests
import json

def test_captain_login():
    url = "http://localhost:8000/api/auth/login"
    
    data = {
        "email": "captain@barangay.gov",
        "password": "tatalaPunongBarangayadmin"
    }
    
    print("🧪 Testing Captain Login...")
    print(f"📧 Email: {data['email']}")
    print(f"🔑 Password: {data['password']}")
    print(f"🌐 URL: {url}")
    print("-" * 50)
    
    try:
        response = requests.post(url, json=data)
        print(f"📊 Status Code: {response.status_code}")
        print(f"📄 Response: {response.text}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ LOGIN SUCCESSFUL!")
            print(f"👤 User: {result.get('user', {}).get('full_name')}")
            print(f"🏷 Role: {result.get('user', {}).get('role')}")
            print(f"🎫 Token: {result.get('token')[:20]}...")
        else:
            print("❌ LOGIN FAILED!")
            
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    test_captain_login()
