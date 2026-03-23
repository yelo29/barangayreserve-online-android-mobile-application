#!/usr/bin/env python3
"""
TEST ACCOUNT SETTINGS BAN PROTECTION
Test Script to Verify Banned Users Cannot Access Account Settings
"""

import requests
import json

# Configuration
BASE_URL = "https://barangayreserve.dpdns.org"

def test_account_settings_ban_protection():
    """Test that account settings properly blocks banned users"""
    
    print("=" * 60)
    print("🚫 ACCOUNT SETTINGS BAN PROTECTION TEST")
    print("=" * 60)
    
    # Test 1: Create a banned user first
    print(f"\n📋 Step 1: Creating test banned user")
    
    # First create a test user
    register_data = {
        "email": "banned_test_user@gmail.com",
        "password": "test123456",
        "full_name": "Banned Test User",
        "contact_number": "0965886985",
        "address": "Test Address for Banned User"
    }
    
    try:
        # Register user
        response = requests.post(f"{BASE_URL}/api/auth/register", json=register_data)
        print(f"📡 Registration response: {response.status_code}")
        
        if response.status_code == 200:
            user_data = response.json()
            if user_data.get('success'):
                user_id = user_data['user']['id']
                print(f"✅ Test user created with ID: {user_id}")
                
                # Now ban the user
                print(f"\n📋 Step 2: Banning the test user")
                ban_data = {
                    "user_id": user_id,
                    "ban_reason": "Test ban for account settings protection"
                }
                
                ban_response = requests.post(f"{BASE_URL}/api/admin/ban-user", json=ban_data)
                print(f"📡 Ban response: {ban_response.status_code}")
                
                if ban_response.status_code == 200:
                    print("✅ Test user banned successfully")
                    
                    # Test 3: Try to access account settings (should be blocked)
                    print(f"\n📋 Step 3: Testing account settings access for banned user")
                    
                    # Get user status to verify ban
                    status_response = requests.get(f"{BASE_URL}/api/users/status/banned_test_user@gmail.com")
                    print(f"📡 User status response: {status_response.status_code}")
                    
                    if status_response.status_code == 200:
                        status_data = status_response.json()
                        print(f"✅ User status: {status_data}")
                        
                        if status_data.get('is_banned'):
                            print("✅ User is confirmed banned")
                            
                            # Test 4: Try to update profile (should be blocked)
                            print(f"\n📋 Step 4: Testing profile update for banned user")
                            
                            update_data = {
                                "full_name": "Updated Name",
                                "contact_number": "0987654321",
                                "address": "Updated Address"
                            }
                            
                            update_response = requests.put(
                                f"{BASE_URL}/api/users/{user_id}",
                                json=update_data,
                                headers={"Content-Type": "application/json"}
                            )
                            
                            print(f"📡 Profile update response: {update_response.status_code}")
                            print(f"📡 Response body: {update_response.text}")
                            
                            if update_response.status_code == 403:
                                try:
                                    error_data = update_response.json()
                                    if error_data.get('error_type') == 'user_banned':
                                        print("✅ SUCCESS: Profile update properly blocked for banned user!")
                                        print(f"   - Error Type: {error_data.get('error_type')}")
                                        print(f"   - Message: {error_data.get('message')}")
                                        return True
                                    else:
                                        print(f"❌ ERROR: Wrong error type: {error_data.get('error_type')}")
                                        return False
                                except:
                                    print(f"❌ ERROR: Invalid JSON response: {update_response.text}")
                                    return False
                            else:
                                print(f"❌ ERROR: Profile update should return 403, got {update_response.status_code}")
                                return False
                        else:
                            print("❌ ERROR: User is not banned")
                            return False
                    else:
                        print(f"❌ ERROR: Failed to get user status: {status_response.status_code}")
                        return False
                else:
                    print("❌ ERROR: Failed to ban test user")
                    return False
            else:
                print(f"❌ ERROR: Registration failed: {user_data.get('message')}")
                return False
        else:
            print(f"❌ ERROR: Registration failed with status: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ ERROR: Exception during test: {e}")
        return False

def main():
    """Main test execution"""
    
    print("🧪 Testing Account Settings Ban Protection")
    print(f"🌐 Server: {BASE_URL}")
    
    # Test account settings ban protection
    result = test_account_settings_ban_protection()
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 TEST RESULT")
    print("=" * 60)
    print(f"🎯 RESULT: {'✅ PASS' if result else '❌ FAIL'}")
    
    if result:
        print("\n🎉 Account settings ban protection is working!")
        print("   ✅ Banned users cannot access account settings")
        print("   ✅ Profile updates are blocked for banned users")
        print("   ✅ Proper error messages returned")
        print("   ✅ Frontend should show ban restriction screen")
    else:
        print("\n🚨 Account settings ban protection needs work!")
    
    return result

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
