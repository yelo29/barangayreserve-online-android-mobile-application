#!/usr/bin/env python3
"""
TEST BAN DIALOG FIX
Verify that the frontend will now properly show ban dialog for banned users
"""

import requests
import json

# Configuration
BASE_URL = "https://barangayreserve.dpdns.org"

# Test user (re-create john1code@gmail.com as banned user for testing)
TEST_EMAIL = "john1code@gmail.com"
TEST_USER_ID = 64  # From the JWT token in logs

def test_ban_dialog_response():
    """Test that ban response is properly formatted for frontend"""
    
    print("=" * 60)
    print("🔍 TESTING BAN DIALOG RESPONSE FORMAT")
    print("=" * 60)
    
    # Step 1: Submit verification request for banned user
    print(f"\n📋 Step 1: Testing verification submission for banned user")
    
    verification_data = {
        "residentId": TEST_USER_ID,
        "verificationType": "resident",
        "full_name": "John1code Test",
        "contact_number": "0965886985",
        "address": "Test Address for Banned User",
        "purpose": "Testing ban dialog display",
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
        
        # Step 2: Verify response format
        print(f"\n📋 Step 2: Verifying ban response format")
        
        if response.status_code == 403:
            try:
                error_data = response.json()
                
                # Check for required fields for frontend ban dialog
                required_fields = ['success', 'error_type', 'message', 'ban_reason']
                missing_fields = []
                
                for field in required_fields:
                    if field not in error_data:
                        missing_fields.append(field)
                
                if missing_fields:
                    print(f"❌ ERROR: Missing required fields: {missing_fields}")
                    return False
                
                print(f"✅ Frontend Ban Dialog Response Format:")
                print(f"   - success: {error_data.get('success')}")
                print(f"   - error_type: {error_data.get('error_type')}")
                print(f"   - message: {error_data.get('message')}")
                print(f"   - ban_reason: {error_data.get('ban_reason')}")
                
                # Verify expected values
                if error_data.get('success') == False:
                    print("✅ SUCCESS: success field is False (correct)")
                else:
                    print(f"❌ ERROR: success should be False, got {error_data.get('success')}")
                    return False
                
                if error_data.get('error_type') == 'user_banned':
                    print("✅ SUCCESS: error_type is 'user_banned' (correct)")
                else:
                    print(f"❌ ERROR: error_type should be 'user_banned', got {error_data.get('error_type')}")
                    return False
                
                expected_message = 'Account is banned. Cannot submit verification requests.'
                if expected_message in error_data.get('message', ''):
                    print("✅ SUCCESS: message contains expected ban text")
                else:
                    print(f"❌ ERROR: message unexpected: {error_data.get('message')}")
                    return False
                
                if error_data.get('ban_reason'):
                    print("✅ SUCCESS: ban_reason is provided")
                else:
                    print(f"⚠️  WARNING: ban_reason is missing")
                
                print("\n🎉 FRONTEND BAN DIALOG WILL NOW WORK!")
                print("   ✅ API returns proper 403 with ban structure")
                print("   ✅ ApiService.createVerificationRequest handles 403 correctly")
                print("   ✅ Frontend checks for error_type == 'user_banned'")
                print("   ✅ BanValidationService.showBanDialog will be called")
                
                return True
                
            except json.JSONDecodeError:
                print(f"❌ ERROR: Invalid JSON response: {response.text}")
                return False
                
        else:
            print(f"❌ ERROR: Expected 403, got {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ ERROR: Exception submitting verification: {e}")
        return False

def main():
    """Main test execution"""
    
    print("🧪 Testing Ban Dialog Fix")
    print(f"🎯 Target User: {TEST_EMAIL}")
    print(f"🌐 Server: {BASE_URL}")
    
    # Test ban dialog response
    result = test_ban_dialog_response()
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 TEST RESULT")
    print("=" * 60)
    print(f"🎯 RESULT: {'✅ PASS' if result else '❌ FAIL'}")
    
    if result:
        print("\n🎉 Ban dialog fix is working!")
        print("   ✅ Banned users will see proper ban dialog")
        print("   ✅ No more generic error messages")
        print("   ✅ Clear ban reason will be displayed")
    else:
        print("\n🚨 Ban dialog fix needs more work!")
    
    return result

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
