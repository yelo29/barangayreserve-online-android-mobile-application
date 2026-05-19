#!/usr/bin/env python3
"""
Verify captain's updated password
"""

import sqlite3

def verify_captain_password():
    conn = sqlite3.connect('barangay.db')
    cursor = conn.cursor()
    
    cursor.execute('SELECT email, password FROM users WHERE email = ?', ('captain@barangay.gov',))
    result = cursor.fetchone()
    
    if result:
        email, password = result
        print('👤 KAPITAN IPIN - UPDATED CREDENTIALS:')
        print(f'📧 Email: {email}')
        print(f'🔑 Password: {password}')
        print('✅ Password updated successfully!')
    else:
        print('❌ Captain account not found')
    
    conn.close()

if __name__ == "__main__":
    verify_captain_password()
