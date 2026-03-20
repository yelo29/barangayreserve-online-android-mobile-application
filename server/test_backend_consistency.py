#!/usr/bin/env python3
"""
Comprehensive Backend Test for User Data Consistency
Tests all endpoints to ensure data consistency across the board
"""

import requests
import json
import sys

BASE_URL = "http://localhost:8000"
TEST_EMAIL = "jl052904@gmail.com"

def test_endpoint(endpoint, description):
    """Test a single endpoint and return user data"""
    try:
        response = requests.get(f"{BASE_URL}{endpoint}", timeout=5)
        print(f"\n{'='*60}")
        print(f"🔍 TESTING: {description}")
        print(f"📍 Endpoint: {endpoint}")
        print(f"📊 Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            if 'user' in data:
                user = data['user']
                print(f"✅ SUCCESS - User Data:")
                print(f"   Email: {user.get('email', 'N/A')}")
                print(f"   Verification Type: {user.get('verification_type', 'N/A')}")
                print(f"   Verified: {user.get('verified', 'N/A')} ({type(user.get('verified', 'N/A'))})")
                print(f"   Discount Rate: {user.get('discount_rate', 'N/A')}")
                print(f"   Full Name: {user.get('full_name', 'N/A')}")
                return user
            else:
                print(f"❌ ERROR: No user data in response")
                print(f"   Response: {data}")
                return None
        else:
            print(f"❌ ERROR: HTTP {response.status_code}")
            print(f"   Response: {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ CONNECTION ERROR: {e}")
        return None

def compare_data_sources():
    """Compare data from all endpoints"""
    print("🧪 COMPREHENSIVE BACKEND CONSISTENCY TEST")
    print("=" * 60)
    
    # Test all endpoints
    endpoints = [
        (f"/api/me?email={TEST_EMAIL}", "Current User (/api/me)"),
        (f"/api/users/profile/{TEST_EMAIL}", "User Profile (/api/users/profile)"),
    ]
    
    results = {}
    
    for endpoint, description in endpoints:
        user_data = test_endpoint(endpoint, description)
        if user_data:
            results[description] = user_data
    
    # Compare results
    print(f"\n{'='*60}")
    print("🔍 DATA CONSISTENCY ANALYSIS")
    print("=" * 60)
    
    if len(results) < 2:
        print("❌ INSUFFICIENT DATA: Need at least 2 endpoints to compare")
        return False
    
    # Get first result as baseline
    baseline = list(results.values())[0]
    baseline_name = list(results.keys())[0]
    
    all_consistent = True
    
    for name, data in results.items():
        if name == baseline_name:
            continue
            
        print(f"\n📊 Comparing {baseline_name} vs {name}:")
        
        # Check key fields
        key_fields = ['verification_type', 'discount_rate', 'verified', 'email', 'full_name']
        
        for field in key_fields:
            baseline_val = baseline.get(field)
            current_val = data.get(field)
            
            if baseline_val != current_val:
                print(f"   ❌ MISMATCH - {field}:")
                print(f"      {baseline_name}: {baseline_val}")
                print(f"      {name}: {current_val}")
                all_consistent = False
            else:
                print(f"   ✅ MATCH - {field}: {baseline_val}")
    
    # Final verdict
    print(f"\n{'='*60}")
    if all_consistent:
        print("✅ ALL ENDPOINTS CONSISTENT - No data leakage detected")
    else:
        print("❌ DATA INCONSISTENCY DETECTED - Fix required")
    
    return all_consistent

def test_database_direct():
    """Test database directly for ground truth"""
    print(f"\n{'='*60}")
    print("🗄️  DATABASE DIRECT QUERY")
    print("=" * 60)
    
    try:
        import sqlite3
        conn = sqlite3.connect('barangay.db')
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM users WHERE email = ?', (TEST_EMAIL,))
        user = cursor.fetchone()
        
        if user:
            columns = [description[0] for description in cursor.description]
            print("✅ Database Record:")
            for i, (col, val) in enumerate(zip(columns, user)):
                print(f"   {col}: {val}")
            
            # Find key indices
            key_indices = {}
            for i, col in enumerate(columns):
                if col in ['verification_type', 'discount_rate', 'verified', 'email', 'full_name']:
                    key_indices[col] = i
            
            print(f"\n🎯 KEY FIELDS FROM DATABASE:")
            for field, index in key_indices.items():
                print(f"   {field}: {user[index]}")
                
            conn.close()
            return True
        else:
            print("❌ User not found in database")
            conn.close()
            return False
            
    except Exception as e:
        print(f"❌ Database error: {e}")
        return False

if __name__ == "__main__":
    print("🚀 STARTING BACKEND CONSISTENCY TEST")
    print("Testing user:", TEST_EMAIL)
    
    # Test database first
    db_ok = test_database_direct()
    
    # Test API endpoints
    api_consistent = compare_data_sources()
    
    # Final summary
    print(f"\n{'='*60}")
    print("📋 FINAL TEST SUMMARY")
    print("=" * 60)
    print(f"Database Access: {'✅ OK' if db_ok else '❌ FAILED'}")
    print(f"API Consistency: {'✅ CONSISTENT' if api_consistent else '❌ INCONSISTENT'}")
    
    if db_ok and api_consistent:
        print("\n🎉 BACKEND IS HEALTHY - Issue is in frontend")
        sys.exit(0)
    else:
        print("\n🚨 BACKEND ISSUES DETECTED - Fix backend first")
        sys.exit(1)
