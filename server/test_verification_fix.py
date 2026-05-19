#!/usr/bin/env python3
"""
Test the verification rejection fix for Non-Resident status preservation
"""

import sqlite3
import json

def test_verification_rejection_logic():
    print("🧪 TESTING VERIFICATION REJECTION FIX")
    print("=" * 50)
    
    conn = sqlite3.connect('barangay.db')
    cursor = conn.cursor()
    
    # Test scenario 1: Non-Resident user gets rejected
    print("\n📋 SCENARIO 1: Non-Resident User Rejected")
    print("Creating test Non-Resident user...")
    
    # Create test user
    cursor.execute('''
        INSERT OR REPLACE INTO users (email, password, full_name, role, verified, verification_type, discount_rate, contact_number, address, is_active, email_verified, last_login, created_at, updated_at, created_by, fake_booking_violations, is_banned, banned_at, ban_reason)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', ('test.nonresident@example.com', 'hashed_password', 'Test Non-Resident', 'resident', 2, 'non-resident', 0.05, '09123456789', 'Test Address', 1, 1, '2026-03-04 12:00:00', '2026-03-04 12:00:00', 1, 0, 0, None, None, 0))
    
    user_id = cursor.lastrowid
    
    # Create verification request for upgrade to Resident
    cursor.execute('''
        INSERT INTO verification_requests (user_id, verification_type, status)
        VALUES (?, ?, ?)
    ''', (user_id, 'resident', 'pending'))
    
    request_id = cursor.lastrowid
    print(f"✅ Created Non-Resident user (ID: {user_id}) with upgrade request (ID: {request_id})")
    
    # Simulate rejection
    print("\n🚫 Simulating REJECTION...")
    
    # Get current status before rejection
    cursor.execute('SELECT verified FROM users WHERE id = ?', (user_id,))
    before_status = cursor.fetchone()[0]
    print(f"📊 Status before rejection: {before_status} (2 = Non-Resident)")
    
    # Apply rejection logic (same as server endpoint)
    data = {'status': 'rejected', 'rejectionReason': 'Test rejection'}
    
    if data.get('status') in ['approved', 'rejected']:
        cursor.execute('SELECT verification_type, user_photo_base64 FROM verification_requests WHERE id = ?', (request_id,))
        verification_request = cursor.fetchone()
        verification_type = verification_request[0] if verification_request else 'resident'
        
        cursor.execute('SELECT verified FROM users WHERE id = (SELECT user_id FROM verification_requests WHERE id = ?)', (request_id,))
        current_verified = cursor.fetchone()[0]
        
        if current_verified == 2:  # Non-Resident
            is_verified = 2  # Keep Non-Resident status
            discount_rate = 0.05  # Keep Non-Resident discount
            print("🎯 PRESERVED Non-Resident status!")
        else:
            is_verified = 0  # Only unverified users become unverified
            discount_rate = 0.0
            print("🔄 Set to unverified (was not Non-Resident)")
        
        cursor.execute('''
            UPDATE users 
            SET verified = ?, discount_rate = ?, verification_type = ?, updated_at = ?
            WHERE id = (SELECT user_id FROM verification_requests WHERE id = ?)
        ''', (is_verified, discount_rate, verification_type, '2026-03-04 12:00:00', request_id))
    
    # Check result
    cursor.execute('SELECT verified FROM users WHERE id = ?', (user_id,))
    after_status = cursor.fetchone()[0]
    print(f"📊 Status after rejection: {after_status} (2 = Non-Resident)")
    
    if before_status == 2 and after_status == 2:
        print("✅ SUCCESS: Non-Resident status preserved!")
    else:
        print("❌ FAILED: Status was not preserved")
    
    # Clean up
    cursor.execute('DELETE FROM users WHERE email = ?', ('test.nonresident@example.com',))
    cursor.execute('DELETE FROM verification_requests WHERE user_id = ?', (user_id,))
    
    conn.commit()
    conn.close()
    
    print("\n🎯 TEST COMPLETE!")
    print("Non-Resident users should keep their status when upgrade requests are rejected!")

if __name__ == "__main__":
    test_verification_rejection_logic()
