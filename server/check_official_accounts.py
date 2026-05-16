#!/usr/bin/env python3
"""
Check if official accounts exist in the database
"""

import sqlite3
import hashlib

def check_official_accounts():
    conn = sqlite3.connect('barangay.db')
    cursor = conn.cursor()
    
    # List of official accounts to check
    officials = [
        {
            'email': 'administrator@barangay.gov',
            'password': 'tatalaAdministratoradmin',
            'name': 'Barangay Administrator'
        },
        {
            'email': 'kagawad1@barangay.gov',
            'password': 'tatalaKagawad1admin',
            'name': 'Barangay Councilor'
        },
        {
            'email': 'planning@barangay.gov',
            'password': 'tatalaPlanningOfficeradmin',
            'name': 'Barangay Planning Officer'
        },
        {
            'email': 'utility@barangay.gov',
            'password': 'tatalaUtilityadmin',
            'name': 'Barangay Utility Worker'
        }
    ]
    
    print('🔍 CHECKING OFFICIAL ACCOUNTS IN DATABASE')
    print('=' * 60)
    
    for official in officials:
        # Hash the expected password
        expected_hash = hashlib.sha256(official['password'].encode()).hexdigest()
        
        # Check if account exists
        cursor.execute('''
            SELECT email, password, full_name, role, verified 
            FROM users 
            WHERE email = ?
        ''', (official['email'],))
        
        result = cursor.fetchone()
        
        print(f'\n👤 {official["name"]}')
        print(f'📧 Email: {official["email"]}')
        
        if result:
            db_email, db_password, db_name, db_role, db_verified = result
            print(f'✅ Account EXISTS in database')
            print(f'   📋 Full Name: {db_name}')
            print(f'   🎭 Role: {db_role}')
            print(f'   ✅ Verified: {db_verified}')
            
            # Check if password matches
            if db_password == expected_hash:
                print(f'   🔑 Password: ✅ MATCHES (tatalaAdministratoradmin)')
            else:
                print(f'   🔑 Password: ❌ DOES NOT MATCH')
                print(f'   📋 Expected hash: {expected_hash}')
                print(f'   📋 Actual hash: {db_password}')
        else:
            print(f'❌ Account DOES NOT EXIST in database')
            print(f'   🔑 Expected password: {official["password"]}')
    
    conn.close()
    print('\n' + '=' * 60)
    print('✅ Check complete')

if __name__ == '__main__':
    check_official_accounts()
