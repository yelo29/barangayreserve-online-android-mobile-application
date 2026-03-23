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
            
            print(f'📋 Checking all tables for user data...')
            
            for table, column in tables_to_check:
                cursor.execute(f'SELECT COUNT(*) FROM {table} WHERE {column} = ?', (user_id,))
                count = cursor.fetchone()[0]
                if count > 0:
                    print(f'📋 Found {count} records in {table}')
                    
                    # Show details before deletion for important tables
                    if table == 'bookings':
                        cursor.execute(f'SELECT id, status FROM {table} WHERE {column} = ?', (user_id,))
                        bookings = cursor.fetchall()
                        for booking in bookings:
                            print(f'   📅 Booking {booking[0]} - Status: {booking[1]}')
                    
                    elif table == 'verification_requests':
                        cursor.execute(f'SELECT id, status, verification_type FROM {table} WHERE {column} = ?', (user_id,))
                        verifications = cursor.fetchall()
                        for vr in verifications:
                            print(f'   📋 Verification {vr[0]}: {vr[2]} - {vr[1]}')
                    
                    # Delete the records
                    cursor.execute(f'DELETE FROM {table} WHERE {column} = ?', (user_id,))
                    total_deleted += count
                    print(f'🗑️  Deleted {count} records from {table}')
                else:
                    print(f'📋 No records found in {table}')
            
            print(f'📋 Checking user status before deletion...')
            cursor.execute('SELECT email, full_name, is_banned, ban_reason, fake_booking_violations, verified, verification_type FROM users WHERE id = ?', (user_id,))
            user_status = cursor.fetchone()
            
            if user_status:
                print(f'👤 User Status Before Deletion:')
                print(f'   📧 Email: {user_status[0]}')
                print(f'   👤 Name: {user_status[1]}')
                print(f'   🚫 Banned: {bool(user_status[2])}')
                print(f'   📝 Ban Reason: {user_status[3] or "None"}')
                print(f'   ⚠️  Violations: {user_status[4]}')
                print(f'   ✅ Verified: {bool(user_status[5])}')
                print(f'   📋 Verification Type: {user_status[6] or "None"}')
            
            # Finally delete the user record
            print(f'🗑️  Deleting user record...')
            cursor.execute('DELETE FROM users WHERE id = ?', (user_id,))
            total_deleted += 1
            print(f'🗑️  Deleted user record from users table')
            
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
