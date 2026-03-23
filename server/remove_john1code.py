#!/usr/bin/env python3
"""
Completely remove ALL data for john1code@gmail.com
"""

import sqlite3

def remove_user_completely():
    DB_PATH = "barangay.db"
    email = "john1code@gmail.com"
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        print(f'🔍 Searching for all data related to {email}...')
        
        # Find user ID first
        cursor.execute('SELECT id, email, full_name FROM users WHERE email = ?', (email,))
        user = cursor.fetchone()
        
        if user:
            user_id = user[0]
            print(f'✅ Found user: {user[1]} ({user[2]}) - ID: {user_id}')
            
            # Count and delete from all related tables in proper order
            tables_to_check = [
                ('bookings', 'user_id'),
                ('verification_requests', 'user_id'), 
                ('users', 'id')
            ]
            
            total_deleted = 0
            
            for table, column in tables_to_check:
                cursor.execute(f'SELECT COUNT(*) FROM {table} WHERE {column} = ?', (user_id,))
                count = cursor.fetchone()[0]
                if count > 0:
                    print(f'📋 Found {count} records in {table}')
                    cursor.execute(f'DELETE FROM {table} WHERE {column} = ?', (user_id,))
                    total_deleted += count
                    print(f'🗑️  Deleted {count} records from {table}')
                else:
                    print(f'📋 No records found in {table}')
            
            conn.commit()
            print(f'✅ COMPLETE: Removed {total_deleted} total records for {email}')
            
            # Verify deletion
            cursor.execute('SELECT COUNT(*) FROM users WHERE email = ?', (email,))
            remaining = cursor.fetchone()[0]
            print(f'🔍 Verification: {remaining} user records remaining')
            
            if remaining == 0:
                print(f'🎉 SUCCESS: {email} has been completely removed from the database!')
            else:
                print(f'⚠️  WARNING: {remaining} records still exist')
            
        else:
            print(f'❌ User {email} not found in database')
        
        conn.close()
        
    except Exception as e:
        print(f'❌ Error: {e}')

if __name__ == "__main__":
    remove_user_completely()
