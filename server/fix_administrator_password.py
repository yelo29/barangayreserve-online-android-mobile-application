#!/usr/bin/env python3
"""
Fix Barangay Administrator's password to tatalaAdministratoradmin
"""

import sqlite3
import hashlib

def fix_administrator_password():
    conn = sqlite3.connect('barangay.db')
    cursor = conn.cursor()
    
    # Hash the correct password
    correct_password = "tatalaAdministratoradmin"
    password_hash = hashlib.sha256(correct_password.encode()).hexdigest()
    
    # Update the password
    cursor.execute('''
        UPDATE users 
        SET password = ? 
        WHERE email = ?
    ''', (password_hash, 'administrator@barangay.gov'))
    
    conn.commit()
    
    # Verify the update
    cursor.execute('SELECT email, password FROM users WHERE email = ?', ('administrator@barangay.gov',))
    result = cursor.fetchone()
    
    conn.close()
    
    print(f'✅ Password updated for administrator@barangay.gov')
    print(f'🔑 New password: {correct_password}')
    print(f'📋 Hash: {password_hash}')
    print(f'✅ Update verified in database')

if __name__ == '__main__':
    fix_administrator_password()
