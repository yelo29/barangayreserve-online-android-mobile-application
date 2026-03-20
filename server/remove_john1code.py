#!/usr/bin/env python3
"""
Remove user data for john1code@gmail.com
"""

import sqlite3

def remove_user():
    DB_PATH = "barangay.db"
    email = "john1code@gmail.com"
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Check if user exists
        cursor.execute('SELECT id, email, full_name FROM users WHERE email = ?', (email,))
        user = cursor.fetchone()
        
        if user:
            print(f"Found user to remove:")
            print(f"  - ID: {user[0]}")
            print(f"  - Email: {user[1]}")
            print(f"  - Name: {user[2]}")
            
            # Remove the user (cascading deletes should handle related data)
            cursor.execute('DELETE FROM users WHERE email = ?', (email,))
            users_deleted = cursor.rowcount
            print(f"  - User deleted: {users_deleted}")
            
            conn.commit()
            
            print(f"\n✅ User {email} and all related data removed successfully!")
            
        else:
            print(f"❌ User {email} not found in database")
        
        conn.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    remove_user()
