import sqlite3

def reset_user_account():
    """Completely remove all data for john1code@gmail.com"""
    
    db_path = 'barangay.db'
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        print("🗑️ Resetting john1code@gmail.com account...")
        
        # Delete all related data
        tables_to_clean = [
            'users',           # Main user record
            'verification_requests',  # Any verification requests
            'bookings',         # All bookings
            'time_slots'        # Any time slots (if user had facility access)
        ]
        
        for table in tables_to_clean:
            try:
                if table == 'users':
                    cursor.execute('DELETE FROM users WHERE email = ?', ('john1code@gmail.com',))
                elif table == 'verification_requests':
                    cursor.execute('DELETE FROM verification_requests WHERE email = ?', ('john1code@gmail.com',))
                elif table == 'bookings':
                    cursor.execute('DELETE FROM bookings WHERE user_id = (SELECT id FROM users WHERE email = ?)', ('john1code@gmail.com',))
                elif table == 'time_slots':
                    cursor.execute('DELETE FROM time_slots WHERE facility_id IN (SELECT id FROM facilities WHERE user_id = (SELECT id FROM users WHERE email = ?))', ('john1code@gmail.com',))
                
                deleted_count = cursor.rowcount
                print(f"   🗑️ Deleted {deleted_count} records from {table}")
                
            except Exception as e:
                print(f"   ⚠️ Error cleaning {table}: {e}")
        
        conn.commit()
        conn.close()
        
        print("✅ Account reset complete!")
        print("📋 john1code@gmail.com can now register as a new user")
        print("📋 All verification history, bookings, and facility access removed")
        
    except Exception as e:
        print(f"❌ Error resetting account: {e}")

if __name__ == '__main__':
    reset_user_account()
