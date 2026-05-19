#!/usr/bin/env python3
"""
REMOVE ORPHANED VERIFICATION REQUESTS
Script to remove verification requests from non-existent users (showing as N/A in official tab)
"""

import sqlite3
import sys

def remove_orphaned_verification_requests():
    """Remove verification requests from non-existent users"""
    
    print("🗑️ REMOVING ORPHANED VERIFICATION REQUESTS")
    print("=" * 60)
    
    try:
        # Connect to database
        conn = sqlite3.connect('barangay.db')
        cursor = conn.cursor()
        
        # First, show the verification requests that will be deleted
        print('📋 Verification requests to be deleted (user_id = 52):')
        cursor.execute('''
            SELECT id, request_reference, verification_type, status, residential_address, created_at
            FROM verification_requests 
            WHERE user_id = 52
            ORDER BY created_at DESC
        ''')
        
        rows = cursor.fetchall()
        
        if rows:
            print(f'📊 Found {len(rows)} verification requests from non-existent user 52:')
            for row in rows:
                print(f'   🆔 ID: {row[0]}')
                print(f'   📋 Ref: {row[1]}')
                print(f'   📋 Type: {row[2]}')
                print(f'   📊 Status: {row[3]}')
                print(f'   📍 Address: {row[4]}')
                print(f'   📅 Created: {row[5]}')
                print('   ' + '-'*30)
            
            # Confirm deletion
            print(f'\n🗑️ Deleting {len(rows)} orphaned verification requests...')
            
            # Delete the verification requests
            cursor.execute('DELETE FROM verification_requests WHERE user_id = 52')
            deleted_count = cursor.rowcount
            
            print(f'✅ Deleted {deleted_count} verification requests')
            
            # Commit the transaction
            conn.commit()
            print('💾 Changes committed to database')
            
        else:
            print('✅ No verification requests found for user 52')
        
        # Verify deletion
        print('\n🔍 Verifying deletion...')
        cursor.execute('SELECT COUNT(*) FROM verification_requests WHERE user_id = 52')
        remaining_count = cursor.fetchone()[0]
        
        if remaining_count == 0:
            print('✅ SUCCESS: All orphaned verification requests removed')
            print('🎯 RESULT: Official Auth Tab will no longer show N/A entries')
            return True
        else:
            print(f'❌ ERROR: {remaining_count} verification requests still remain')
            return False
        
        conn.close()
        
    except sqlite3.Error as e:
        print(f'❌ Database error: {e}')
        return False
    except Exception as e:
        print(f'❌ Error: {e}')
        return False

def main():
    """Main execution"""
    
    print("🧪 Orphaned Verification Requests Removal")
    print("This script removes verification requests from non-existent users")
    
    # Remove orphaned verification requests
    success = remove_orphaned_verification_requests()
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 OPERATION RESULT")
    print("=" * 60)
    print(f"🎯 RESULT: {'✅ SUCCESS' if success else '❌ FAILED'}")
    
    if success:
        print("\n🎉 Orphaned verification requests successfully removed!")
        print("   ✅ Official Auth Tab will no longer show N/A entries")
        print("   ✅ Database cleaned up properly")
        print("   ✅ All verification requests now have valid users")
    else:
        print("\n🚨 Orphaned verification requests removal failed!")
        print("   ❌ Check database connection and permissions")
        print("   ❌ Verify user permissions")
    
    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
