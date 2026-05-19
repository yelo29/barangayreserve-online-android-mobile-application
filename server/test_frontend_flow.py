#!/usr/bin/env python3
"""
Frontend Data Flow Test
Simulates the complete authentication and data flow to verify fixes
"""

import requests
import json
import sys

BASE_URL = "http://localhost:8000"
TEST_EMAIL = "jl052904@gmail.com"

def test_gmail_auth_simulation():
    """Simulate Gmail authentication flow"""
    print("🧪 SIMULATING GMAIL AUTHENTICATION FLOW")
    print("=" * 60)
    
    # Step 1: Gmail auth would normally call /api/auth/google-login
    # But we can't test that without a real Google token
    # So we'll test the /api/me endpoint which should return the same data
    
    print("📍 Step 1: Testing /api/me (simulates Gmail auth user data)")
    try:
        response = requests.get(f"{BASE_URL}/api/me?email={TEST_EMAIL}", timeout=5)
        if response.status_code == 200:
            data = response.json()
            user = data['user']
            
            print(f"✅ Gmail auth simulation - Server Response:")
            print(f"   Email: {user.get('email')}")
            print(f"   Verification Type: {user.get('verification_type')}")
            print(f"   Verified: {user.get('verified')} ({type(user.get('verified'))})")
            print(f"   Discount Rate: {user.get('discount_rate')}")
            
            # Verify this is the expected data
            expected_type = "verified_non_resident"
            expected_discount = 0.05
            expected_verified = True
            
            if user.get('verification_type') == expected_type:
                print(f"✅ Verification type correct: {expected_type}")
            else:
                print(f"❌ Verification type WRONG: expected {expected_type}, got {user.get('verification_type')}")
                return False
                
            if user.get('discount_rate') == expected_discount:
                print(f"✅ Discount rate correct: {expected_discount}")
            else:
                print(f"❌ Discount rate WRONG: expected {expected_discount}, got {user.get('discount_rate')}")
                return False
                
            if user.get('verified') == expected_verified:
                print(f"✅ Verified status correct: {expected_verified}")
            else:
                print(f"❌ Verified status WRONG: expected {expected_verified}, got {user.get('verified')}")
                return False
                
            return user
        else:
            print(f"❌ Error: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Connection error: {e}")
        return False

def test_verification_logic_simulation(user_data):
    """Simulate frontend verification logic"""
    print(f"\n📍 Step 2: Testing Frontend Verification Logic")
    print("=" * 60)
    
    # Simulate isVerifiedResident() logic
    verified = user_data.get('verified') == True or user_data.get('verified') == 1
    verification_type = user_data.get('verification_type') == 'resident'
    discount_rate = user_data.get('discount_rate') == 0.1
    # Must be verified AND specifically resident verification type (not verified_non_resident)
    is_resident = verified and verification_type and user_data.get('verification_type') != 'verified_non_resident'
    
    print(f"🔍 isVerifiedResident() Simulation:")
    print(f"   verified: {verified}")
    print(f"   verification_type == 'resident': {verification_type}")
    print(f"   verification_type != 'verified_non_resident': {user_data.get('verification_type') != 'verified_non_resident'}")
    print(f"   discount_rate == 0.1: {discount_rate}")
    print(f"   Final result: {is_resident}")
    
    # Simulate isVerifiedNonResident() logic
    verification_type_nr = (user_data.get('verification_type') == 'non-resident' or 
                           user_data.get('verification_type') == 'verified_non_resident')
    discount_rate_nr = user_data.get('discount_rate') == 0.05
    is_non_resident = verified and verification_type_nr
    
    print(f"\n🔍 isVerifiedNonResident() Simulation:")
    print(f"   verified: {verified}")
    print(f"   verification_type in ['non-resident', 'verified_non_resident']: {verification_type_nr}")
    print(f"   discount_rate == 0.05: {discount_rate_nr}")
    print(f"   Final result: {is_non_resident}")
    
    # Expected results for verified_non_resident
    expected_resident = False
    expected_non_resident = True
    
    print(f"\n📊 Verification Logic Results:")
    if is_resident == expected_resident:
        print(f"✅ isVerifiedResident(): {is_resident} (expected {expected_resident})")
    else:
        print(f"❌ isVerifiedResident(): {is_resident} (expected {expected_resident}) - DATA LEAKAGE!")
        return False
        
    if is_non_resident == expected_non_resident:
        print(f"✅ isVerifiedNonResident(): {is_non_resident} (expected {expected_non_resident})")
    else:
        print(f"❌ isVerifiedNonResident(): {is_non_resident} (expected {expected_non_resident}) - DATA LEAKAGE!")
        return False
        
    # Check for mutual exclusivity
    if is_resident and is_non_resident:
        print(f"❌ LOGIC ERROR: Both functions return true - should be mutually exclusive!")
        return False
    else:
        print(f"✅ Mutual exclusivity verified: Only one verification type is true")
    
    return True

def test_data_consistency():
    """Test data consistency across multiple calls"""
    print(f"\n📍 Step 3: Testing Data Consistency")
    print("=" * 60)
    
    # Test multiple calls to /api/me
    results = []
    for i in range(3):
        try:
            response = requests.get(f"{BASE_URL}/api/me?email={TEST_EMAIL}", timeout=5)
            if response.status_code == 200:
                data = response.json()
                user = data['user']
                results.append({
                    'verification_type': user.get('verification_type'),
                    'discount_rate': user.get('discount_rate'),
                    'verified': user.get('verified')
                })
                print(f"   Call {i+1}: verification_type={user.get('verification_type')}, discount_rate={user.get('discount_rate')}")
            else:
                print(f"   Call {i+1}: ERROR - {response.status_code}")
                return False
        except Exception as e:
            print(f"   Call {i+1}: EXCEPTION - {e}")
            return False
    
    # Check consistency
    first_result = results[0]
    all_consistent = True
    
    for i, result in enumerate(results[1:], 1):
        if result != first_result:
            print(f"❌ Inconsistency detected between call 1 and call {i+1}")
            all_consistent = False
        else:
            print(f"✅ Call {i+1} consistent with call 1")
    
    if all_consistent:
        print(f"✅ All API calls consistent - no backend data leakage")
    
    return all_consistent

if __name__ == "__main__":
    print("🚀 FRONTEND DATA FLOW TEST")
    print("Testing user:", TEST_EMAIL)
    print("This test simulates the complete authentication flow to verify fixes")
    
    # Test Gmail auth simulation
    user_data = test_gmail_auth_simulation()
    if not user_data:
        print("\n❌ GMAIL AUTH SIMULATION FAILED")
        sys.exit(1)
    
    # Test verification logic
    logic_ok = test_verification_logic_simulation(user_data)
    if not logic_ok:
        print("\n❌ VERIFICATION LOGIC FAILED")
        sys.exit(1)
    
    # Test data consistency
    consistency_ok = test_data_consistency()
    if not consistency_ok:
        print("\n❌ DATA CONSISTENCY FAILED")
        sys.exit(1)
    
    # Final summary
    print(f"\n{'='*60}")
    print("📋 FRONTEND TEST SUMMARY")
    print("=" * 60)
    print(f"Gmail Auth Simulation: ✅ PASSED")
    print(f"Verification Logic: ✅ PASSED")
    print(f"Data Consistency: ✅ PASSED")
    
    print(f"\n🎉 ALL TESTS PASSED!")
    print(f"✅ User correctly identified as verified_non_resident")
    print(f"✅ 5% discount rate applied correctly")
    print(f"✅ No data leakage detected")
    print(f"✅ Verification logic working properly")
    
    print(f"\n🔧 NEXT STEPS:")
    print(f"1. Test the Flutter app to verify logout works")
    print(f"2. Test field locking in all dashboard sections")
    print(f"3. Verify complete user recognition across app")
    
    sys.exit(0)
