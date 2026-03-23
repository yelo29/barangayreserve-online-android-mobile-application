#!/usr/bin/env python3
import sqlite3

# Check all database files
db_files = ['reserve.db', 'barangay.db', 'barangay_reservations.db', 'barangay_reserve.db']

for db_file in db_files:
    try:
        conn = sqlite3.connect(db_file)
        cursor = conn.cursor()
        
        cursor.execute('SELECT name FROM sqlite_master WHERE type="table"')
        tables = cursor.fetchall()
        
        print(f'Tables in {db_file}:')
        if tables:
            for table in tables:
                print(f'  - {table[0]}')
        else:
            print('  (No tables)')
        print()
        
        conn.close()
    except Exception as e:
        print(f'Error with {db_file}: {e}\n')
