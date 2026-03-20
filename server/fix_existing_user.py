#!/usr/bin/env python3
"""
Fix existing Gmail user verification status
"""

import sqlite3

def fix_existing_user():
    DB_PATH = "barangay.db"
    email = "john2codepie@gmail.com"
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Check current user status
        cursor.execute('SELECT verified, verification_type, discount_rate FROM users WHERE email = ?', (email,))
        user = cursor.fetchone()
        
        if user:
            print(f"Current status for {email}:")
            print(f"  - Verified: {user[0]}")
            print(f"  - Verification Type: {user[1]}")
            print(f"  - Discount Rate: {user[2]}")
            
            # Fix the user
            cursor.execute('''
                UPDATE users 
                SET verified = FALSE, 
                    verification_type = 'unverified', 
                    discount_rate = 0.0 
                WHERE email = ?
            ''', (email,))
            
            conn.commit()
            
            # Verify the fix
            cursor.execute('SELECT verified, verification_type, discount_rate FROM users WHERE email = ?', (email,))
            updated_user = cursor.fetchone()
            
            print(f"\nUpdated status for {email}:")
            print(f"  - Verified: {updated_user[0]}")
            print(f"  - Verification Type: {updated_user[1]}")
            print(f"  - Discount Rate: {updated_user[2]}")
            
            print("\n✅ User fixed successfully!")
            
        else:
            print(f"❌ User {email} not found")
        
        conn.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    fix_existing_user()
