#!/usr/bin/env python3
"""
Update Secretary Sally's password to tatalaSecretaryadmin
"""

import sqlite3
import hashlib

def update_secretary_password():
    conn = sqlite3.connect('barangay.db')
    cursor = conn.cursor()
    
    # Hash the new password
    new_password = "tatalaSecretaryadmin"
    password_hash = hashlib.sha256(new_password.encode()).hexdigest()
    
    # Update the password
    cursor.execute('''
        UPDATE users 
        SET password = ? 
        WHERE email = ?
    ''', (password_hash, 'secretary@barangay.gov'))
    
    conn.commit()
    
    # Verify the update
    cursor.execute('SELECT email, password FROM users WHERE email = ?', ('secretary@barangay.gov',))
    result = cursor.fetchone()
    
    conn.close()
    
    print(f'✅ Password updated for secretary@barangay.gov')
    print(f'🔑 New password: {new_password}')
    print(f'📋 Hash: {password_hash}')
    print(f'✅ Update verified in database')

if __name__ == '__main__':
    update_secretary_password()
