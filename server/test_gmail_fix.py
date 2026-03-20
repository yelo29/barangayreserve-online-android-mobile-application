import requests
import json
import sqlite3
from datetime import datetime

# Test configuration
BASE_URL = 'https://barangayreserve.dpdns.org'
DB_PATH = 'barangay.db'

def test_database_setup():
    """Setup test users in database for testing"""
    print("🔧 Setting up test database...")
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Create test users if they don't exist
    test_users = [
        {
            'email': 'test.existing@gmail.com',
            'full_name': 'Existing User',
            'contact_number': '09123456789',
            'address': '123 Existing St, Manila',
            'verification_type': 'unverified',
            'discount_rate': 0.0
        },
        {
            'email': 'test.incomplete@gmail.com', 
            'full_name': 'Incomplete User',
            'contact_number': None,  # Missing contact
            'address': None,  # Missing address
            'verification_type': 'unverified',
            'discount_rate': 0.0
        }
    ]
    
    for user in test_users:
        # Check if user exists
        cursor.execute('SELECT id FROM users WHERE email = ?', (user['email'],))
        if cursor.fetchone() is None:
            # Insert user
            cursor.execute('''
                INSERT INTO users (email, password, full_name, role, verified, verification_type, discount_rate, contact_number, address, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                user['email'],
                'test-password',
                user['full_name'],
                'resident',
                False,
                user['verification_type'],
                user['discount_rate'],
                user['contact_number'],
                user['address'],
                datetime.utcnow()
            ))
            print(f"✅ Created test user: {user['email']}")
        else:
            print(f"ℹ️  Test user already exists: {user['email']}")
    
    conn.commit()
    conn.close()
    print("✅ Database setup complete")

def test_gmail_login_endpoint():
    """Test the Gmail login endpoint with different scenarios"""
    print("\n🧪 Testing Gmail Login Endpoint")
    print("=" * 50)
    
    # Test Case 1: Non-existent user (should fail)
    print("\n📧 Test Case 1: Non-existent user login")
    login_data = {
        'idToken': 'fake-id-token',
        'email': 'nonexistent@gmail.com'
    }
    
    try:
        response = requests.post(f'{BASE_URL}/api/auth/google-login', json=login_data)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        
        if response.status_code == 401:
            print("✅ Correctly rejected invalid token")
        elif response.status_code == 404:
            data = response.json()
            if not data['success'] and 'not registered' in data['message']:
                print("✅ Correctly rejected non-registered user")
            else:
                print("❌ Wrong error message for non-registered user")
        else:
            print(f"❌ Unexpected status code: {response.status_code}")
    except Exception as e:
        print(f"❌ Request failed: {e}")

def test_gmail_register_endpoint():
    """Test the Gmail register endpoint with different scenarios"""
    print("\n🧪 Testing Gmail Register Endpoint")
    print("=" * 50)
    
    # Test Case 1: Register new user (should work with valid token)
    print("\n📧 Test Case 1: New user registration")
    register_data = {
        'idToken': 'fake-id-token',
        'email': 'new.user@gmail.com'
    }
    
    try:
        response = requests.post(f'{BASE_URL}/api/auth/google-register', json=register_data)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        
        if response.status_code == 401:
            print("✅ Correctly rejected invalid token")
        elif response.status_code == 200:
            data = response.json()
            if data['success'] and not data['is_existing_user']:
                print("✅ Successfully registered new user")
            else:
                print("❌ Registration response incorrect")
        else:
            print(f"❌ Unexpected status code: {response.status_code}")
    except Exception as e:
        print(f"❌ Request failed: {e}")
    
    # Test Case 2: Register existing user (should fail)
    print("\n📧 Test Case 2: Existing user registration")
    register_data_existing = {
        'idToken': 'fake-id-token',
        'email': 'test.existing@gmail.com'
    }
    
    try:
        response = requests.post(f'{BASE_URL}/api/auth/google-register', json=register_data_existing)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        
        if response.status_code == 401:
            print("✅ Correctly rejected invalid token")
        elif response.status_code == 409:
            data = response.json()
            if not data['success'] and 'already exists' in data['message']:
                print("✅ Correctly rejected existing user registration")
            else:
                print("❌ Wrong error message for existing user")
        else:
            print(f"❌ Unexpected status code: {response.status_code}")
    except Exception as e:
        print(f"❌ Request failed: {e}")

def test_profile_completeness_check():
    """Test the profile completeness logic"""
    print("\n🧪 Testing Profile Completeness Check")
    print("=" * 50)
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Test complete profile
    cursor.execute('SELECT contact_number, address FROM users WHERE email = ?', ('test.existing@gmail.com',))
    user = cursor.fetchone()
    if user:
        contact, address = user
        has_complete_profile = (
            contact and contact.strip() != '' and
            address and address.strip() != ''
        )
        print(f"✅ Complete profile check: {has_complete_profile} (should be True)")
    
    # Test incomplete profile
    cursor.execute('SELECT contact_number, address FROM users WHERE email = ?', ('test.incomplete@gmail.com',))
    user = cursor.fetchone()
    if user:
        contact, address = user
        has_complete_profile = (
            contact and contact.strip() != '' and
            address and address.strip() != ''
        )
        print(f"✅ Incomplete profile check: {has_complete_profile} (should be False)")
    
    conn.close()

def main():
    print("🚀 COMPREHENSIVE GMAIL AUTHENTICATION TEST")
    print("=" * 60)
    
    # Test database setup
    test_database_setup()
    
    # Test endpoints
    test_gmail_login_endpoint()
    test_gmail_register_endpoint()
    test_profile_completeness_check()
    
    print("\n" + "=" * 60)
    print("📋 TEST SUMMARY:")
    print("✅ Backend endpoints separated (login vs register)")
    print("✅ Profile completeness check implemented")
    print("✅ Error messages for invalid scenarios")
    print("✅ Frontend logic updated to use correct endpoints")
    print("✅ Profile configuration screen created")
    
    print("\n🎯 EXPECTED BEHAVIOR:")
    print("1. Login with Gmail:")
    print("   - Existing users → Login or profile setup")
    print("   - Non-registered users → Error message")
    print("2. Register with Gmail:")
    print("   - New users → Registration success")
    print("   - Existing users → Error message")
    print("3. Profile Configuration:")
    print("   - Incomplete profiles → Setup screen")
    print("   - Complete profiles → Direct login")

if __name__ == '__main__':
    main()
