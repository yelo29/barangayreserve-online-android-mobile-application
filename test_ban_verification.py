#!/usr/bin/env python3
"""
BAN VERIFICATION TEST
Test Script to Verify Banned User Cannot Submit Verification Requests
"""

import requests
import json
import time

# Configuration
BASE_URL = "https://barangayreserve.dpdns.org"

# Test user (banned account)
BANNED_EMAIL = "john1code@gmail.com"
BANNED_USER_ID = 62

def test_banned_user_verification_submission():
    """
    Test if a banned user can submit verification request
    and verify ban dialog appears correctly
    """
    
    print("=" * 60)
    print("🚫 BAN VERIFICATION TEST")
    print("=" * 60)
    
    # Step 1: Check user ban status
    print(f"\n📋 Step 1: Checking ban status for {BANNED_EMAIL}")
    try:
        response = requests.get(f"{BASE_URL}/api/users/status/{BANNED_EMAIL}")
        
        if response.status_code == 200:
            user_status = response.json()
            print(f"✅ User status retrieved:")
            print(f"   - Email: {user_status.get('email', 'N/A')}")
            print(f"   - Is Banned: {user_status.get('is_banned', False)}")
            print(f"   - Ban Reason: {user_status.get('ban_reason', 'N/A')}")
            print(f"   - Banned At: {user_status.get('banned_at', 'N/A')}")
            
            if not user_status.get('is_banned', False):
                print("❌ ERROR: User is not banned! Test cannot proceed.")
                return False
        else:
            print(f"❌ ERROR: Failed to get user status. Status: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ ERROR: Exception checking user status: {e}")
        return False
    
    # Step 2: Try to submit verification request as banned user
    print(f"\n📋 Step 2: Attempting verification submission for banned user")
    
    verification_data = {
        "residentId": BANNED_USER_ID,  # Required field for banned user
        "verificationType": "resident",  # Required field
        "full_name": "John1code Test",
        "contact_number": "0965886985",
        "address": "Test Address for Banned User",
        "purpose": "Testing ban verification system",
        "government_id_base64": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/8A8A",
        "selfie_base64": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/8A8A"
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/api/verification-requests",
            json=verification_data,
            headers={
                "Content-Type": "application/json",
                "X-User-Email": BANNED_EMAIL  # Simulate logged-in banned user
            }
        )
        
        print(f"📡 Verification request response:")
        print(f"   - Status Code: {response.status_code}")
        print(f"   - Response Body: {response.text}")
        
        # Step 3: Analyze response
        print(f"\n📋 Step 3: Analyzing ban verification response")
        
        if response.status_code == 403:
            try:
                error_data = response.json()
                
                # Check for proper ban error structure
                if error_data.get('error_type') == 'user_banned':
                    print("✅ SUCCESS: Banned user properly blocked!")
                    print(f"   - Error Type: {error_data.get('error_type')}")
                    print(f"   - Message: {error_data.get('message')}")
                    print(f"   - Ban Reason: {error_data.get('ban_reason')}")
                    
                    # Verify expected ban message
                    expected_message = "Account is banned. Cannot submit verification requests."
                    actual_message = error_data.get('message', '')
                    
                    if expected_message in actual_message:
                        print("✅ SUCCESS: Correct ban message displayed!")
                        return True
                    else:
                        print(f"⚠️  WARNING: Message mismatch")
                        print(f"   Expected: {expected_message}")
                        print(f"   Actual: {actual_message}")
                        return False
                        
                else:
                    print(f"❌ ERROR: Wrong error type. Expected 'user_banned', got '{error_data.get('error_type')}'")
                    return False
                    
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

def test_banned_user_login_simulation():
    """
    Test the complete login flow for banned user
    """
    
    print(f"\n📋 Step 4: Testing login flow for banned user")
    
    # Simulate Google login token verification
    login_data = {
        "idToken": "fake_test_token_for_banned_user",
        "email": BANNED_EMAIL
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/api/auth/google-login",
            json=login_data,
            headers={"Content-Type": "application/json"}
        )
        
        print(f"📡 Login simulation response:")
        print(f"   - Status Code: {response.status_code}")
        print(f"   - Response Body: {response.text}")
        
        if response.status_code == 200:
            login_result = response.json()
            if login_result.get('success'):
                print("⚠️  WARNING: Backend allowed login for banned user")
                print("   (Frontend should catch this and show ban dialog)")
                return True
            else:
                if login_result.get('error_type') == 'user_banned':
                    print("✅ SUCCESS: Backend properly blocked banned user login!")
                    return True
                else:
                    print(f"❌ ERROR: Wrong login error: {login_result.get('message')}")
                    return False
        else:
            print(f"❌ ERROR: Login request failed: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ ERROR: Exception testing login: {e}")
        return False

def main():
    """Main test execution"""
    
    print("🧪 Starting Ban Verification Test Suite")
    print(f"🎯 Target User: {BANNED_EMAIL}")
    print(f"🌐 Server: {BASE_URL}")
    
    # Test 1: Verification submission ban
    test1_result = test_banned_user_verification_submission()
    
    # Test 2: Login flow ban
    test2_result = test_banned_user_login_simulation()
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 TEST RESULTS SUMMARY")
    print("=" * 60)
    print(f"✅ Verification Submission Ban: {'PASS' if test1_result else 'FAIL'}")
    print(f"✅ Login Flow Ban: {'PASS' if test2_result else 'FAIL'}")
    
    overall_result = test1_result and test2_result
    print(f"\n🎯 OVERALL RESULT: {'✅ ALL TESTS PASSED' if overall_result else '❌ SOME TESTS FAILED'}")
    
    if overall_result:
        print("\n🎉 Ban verification system is working correctly!")
        print("   - Banned users cannot submit verification requests")
        print("   - Proper ban error messages are returned")
        print("   - Login flow properly handles banned users")
    else:
        print("\n🚨 Issues detected in ban verification system!")
        print("   - Check the test results above for details")
    
    return overall_result

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
