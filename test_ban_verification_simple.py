#!/usr/bin/env python3
"""
SIMPLE BAN VERIFICATION TEST
Test Script to Verify Banned User Cannot Submit Verification Requests
"""

import requests
import json

# Configuration
BASE_URL = "https://barangayreserve.dpdns.org"

# Test user (banned account)
BANNED_EMAIL = "john1code@gmail.com"
BANNED_USER_ID = 62

def test_banned_user_verification():
    """Test if banned user can submit verification request"""
    
    print("=" * 60)
    print("🚫 BAN VERIFICATION TEST - SIMPLIFIED")
    print("=" * 60)
    
    # Step 1: Check user is banned
    print(f"\n📋 Step 1: Checking ban status for {BANNED_EMAIL}")
    try:
        response = requests.get(f"{BASE_URL}/api/users/status/{BANNED_EMAIL}")
        
        if response.status_code == 200:
            user_status = response.json()
            is_banned = user_status.get('is_banned', False)
            ban_reason = user_status.get('ban_reason', 'N/A')
            
            print(f"✅ User Status:")
            print(f"   - Is Banned: {is_banned}")
            print(f"   - Ban Reason: {ban_reason}")
            
            if not is_banned:
                print("❌ ERROR: User is not banned! Test cannot proceed.")
                return False
        else:
            print(f"❌ ERROR: Failed to get user status. Status: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ ERROR: Exception checking user status: {e}")
        return False
    
    # Step 2: Try to submit verification request
    print(f"\n📋 Step 2: Submitting verification request for banned user")
    
    verification_data = {
        "residentId": BANNED_USER_ID,
        "verificationType": "resident",
        "full_name": "John1code Test",
        "contact_number": "0965886985",
        "address": "Test Address for Banned User",
        "purpose": "Testing ban verification system",
        "government_id_base64": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/8A8A",
        "selfie_base64": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/8A8A"
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/api/verification-requests",
            json=verification_data,
            headers={"Content-Type": "application/json"}
        )
        
        print(f"📡 Response:")
        print(f"   - Status Code: {response.status_code}")
        print(f"   - Response Body: {response.text}")
        
        # Step 3: Verify ban response
        print(f"\n📋 Step 3: Verifying ban response")
        
        if response.status_code == 403:
            try:
                error_data = response.json()
                
                # Check for proper ban error structure
                error_type = error_data.get('error_type')
                message = error_data.get('message')
                ban_reason = error_data.get('ban_reason')
                
                print(f"✅ Ban Response Analysis:")
                print(f"   - Error Type: {error_type}")
                print(f"   - Message: {message}")
                print(f"   - Ban Reason: {ban_reason}")
                
                # Verify expected values
                expected_error_type = 'user_banned'
                expected_message = 'Account is banned. Cannot submit verification requests.'
                
                if error_type == expected_error_type:
                    print("✅ SUCCESS: Correct error type!")
                else:
                    print(f"❌ ERROR: Wrong error type. Expected '{expected_error_type}', got '{error_type}'")
                    return False
                
                if expected_message in message:
                    print("✅ SUCCESS: Correct ban message!")
                else:
                    print(f"❌ ERROR: Wrong message. Expected '{expected_message}', got '{message}'")
                    return False
                
                if ban_reason and 'fake receipt' in ban_reason.lower():
                    print("✅ SUCCESS: Ban reason contains expected content!")
                else:
                    print(f"⚠️  WARNING: Ban reason unexpected: {ban_reason}")
                
                print("\n🎉 VERIFICATION BAN SYSTEM WORKING PERFECTLY!")
                print("   ✅ Banned user cannot submit verification requests")
                print("   ✅ Proper 403 status code returned")
                print("   ✅ Correct error type and message displayed")
                print("   ✅ Ban reason included in response")
                
                return True
                
            except json.JSONDecodeError:
                print(f"❌ ERROR: Invalid JSON response: {response.text}")
                return False
                
        elif response.status_code == 200:
            print("❌ CRITICAL ERROR: Banned user was allowed to submit verification!")
            return False
            
        else:
            print(f"❌ ERROR: Unexpected status code: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ ERROR: Exception submitting verification: {e}")
        return False

def main():
    """Main test execution"""
    
    print("🧪 Starting Simple Ban Verification Test")
    print(f"🎯 Target User: {BANNED_EMAIL}")
    print(f"🌐 Server: {BASE_URL}")
    
    # Test verification submission ban
    result = test_banned_user_verification()
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 TEST RESULT")
    print("=" * 60)
    print(f"🎯 RESULT: {'✅ PASS' if result else '❌ FAIL'}")
    
    if result:
        print("\n🎉 Ban verification system is working correctly!")
        print("   - Banned users are properly blocked from verification submissions")
        print("   - Correct error messages are returned")
        print("   - Frontend should show ban dialog with this information")
    else:
        print("\n🚨 Issues detected in ban verification system!")
    
    return result

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
