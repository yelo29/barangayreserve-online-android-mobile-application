#!/usr/bin/env python3
"""
Get real passwords for official accounts
"""

import sqlite3

def get_official_passwords():
    conn = sqlite3.connect('barangay.db')
    cursor = conn.cursor()
    
    cursor.execute('SELECT email, password FROM users WHERE role = ?', ('official',))
    officials = cursor.fetchall()
    
    print('🔐 OFFICIAL ACCOUNTS - REAL PASSWORDS:')
    print('=' * 50)
    
    for i, official in enumerate(officials, 1):
        email, password = official
        print(f'{i}. 👤 {email}')
        print(f'   🔑 Password: {password}')
        print('-' * 30)
    
    print(f'\n📊 Total Officials: {len(officials)}')
    
    conn.close()

if __name__ == "__main__":
    get_official_passwords()
