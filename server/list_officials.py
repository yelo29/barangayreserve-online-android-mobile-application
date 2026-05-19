#!/usr/bin/env python3
"""
List all official accounts with their credentials
"""

import sqlite3

def list_official_accounts():
    conn = sqlite3.connect('barangay.db')
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT email, full_name, role, password 
        FROM users 
        WHERE role = 'official'
        ORDER BY full_name
    ''')
    
    officials = cursor.fetchall()
    
    print('🏛️ OFFICIAL ACCOUNTS LIST')
    print('=' * 50)
    
    for i, official in enumerate(officials, 1):
        email, name, role, password = official
        print(f'{i}. 👤 {name}')
        print(f'   📧 Email: {email}')
        print(f'   🔑 Password: {password}')
        print(f'   🏷 Role: {role}')
        print('-' * 30)
    
    print(f'\n📊 Total Officials: {len(officials)}')
    
    conn.close()

if __name__ == "__main__":
    list_official_accounts()
