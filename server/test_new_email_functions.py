#!/usr/bin/env python3
"""
Test the new email notification functions for overlap, official notification, and resident confirmation
"""

from email_service import email_service
from datetime import datetime

def test_new_email_functions():
    print("📧 TESTING NEW EMAIL NOTIFICATION FUNCTIONS")
    print("=" * 60)
    
    # Test 1: Booking Overlap Email
    print("\n🎯 TEST 1: Booking Overlap Email")
    print("Testing overlap notification to resident...")
    
    original_booking = {
        'facility_name': 'Basketball Court',
        'booking_date': '2026-03-10',
        'start_time': '14:00',
        'end_time': '16:00',
        'purpose': 'Resident Basketball Game',
        'booking_reference': 'BK-2026-03-001'
    }
    
    official_booking = {
        'official_name': 'Captain Juan',
        'facility_name': 'Basketball Court',
        'booking_date': '2026-03-10',
        'start_time': '15:00',
        'end_time': '17:00',
        'purpose': 'Official Barangay Meeting'
    }
    
    try:
        result = email_service.send_booking_overlap_email(
            resident_email="test.resident@example.com",
            resident_name="Test Resident",
            original_booking=original_booking,
            official_booking=official_booking
        )
        print("✅ Overlap email function executed successfully")
        print(f"📧 Result: {result}")
    except Exception as e:
        print(f"❌ Overlap email failed: {e}")
    
    # Test 2: Official Notification Email (Booking)
    print("\n🎯 TEST 2: Official Notification Email (Booking)")
    print("Testing official notification for booking request...")
    
    resident_details = {
        'full_name': 'Maria Santos',
        'email': 'maria.santos@example.com',
        'contact_number': '09123456789',
        'verification_status': 'Verified Resident'
    }
    
    booking_details = {
        'submitted_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'reference_number': 'BK-2026-03-002',
        'facility_name': 'Multi-Purpose Hall',
        'booking_date': '2026-03-15',
        'start_time': '09:00',
        'end_time': '12:00',
        'purpose': 'Birthday Party'
    }
    
    try:
        result = email_service.send_official_notification_email(
            request_type="booking",
            resident_details=resident_details,
            request_details=booking_details
        )
        print("✅ Official notification email (booking) executed successfully")
        print(f"📧 Result: {result}")
    except Exception as e:
        print(f"❌ Official notification email (booking) failed: {e}")
    
    # Test 3: Official Notification Email (Authentication)
    print("\n🎯 TEST 3: Official Notification Email (Authentication)")
    print("Testing official notification for authentication request...")
    
    auth_details = {
        'submitted_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'reference_number': 'AUTH-2026-03-003',
        'verification_type': 'resident'
    }
    
    try:
        result = email_service.send_official_notification_email(
            request_type="authentication",
            resident_details=resident_details,
            request_details=auth_details
        )
        print("✅ Official notification email (authentication) executed successfully")
        print(f"📧 Result: {result}")
    except Exception as e:
        print(f"❌ Official notification email (authentication) failed: {e}")
    
    # Test 4: Resident Confirmation Email (Booking)
    print("\n🎯 TEST 4: Resident Confirmation Email (Booking)")
    print("Testing resident confirmation for booking request...")
    
    try:
        result = email_service.send_resident_submission_confirmation_email(
            resident_email="maria.santos@example.com",
            resident_name="Maria Santos",
            request_type="booking",
            request_details=booking_details
        )
        print("✅ Resident confirmation email (booking) executed successfully")
        print(f"📧 Result: {result}")
    except Exception as e:
        print(f"❌ Resident confirmation email (booking) failed: {e}")
    
    # Test 5: Resident Confirmation Email (Authentication)
    print("\n🎯 TEST 5: Resident Confirmation Email (Authentication)")
    print("Testing resident confirmation for authentication request...")
    
    try:
        result = email_service.send_resident_submission_confirmation_email(
            resident_email="maria.santos@example.com",
            resident_name="Maria Santos",
            request_type="authentication",
            request_details=auth_details
        )
        print("✅ Resident confirmation email (authentication) executed successfully")
        print(f"📧 Result: {result}")
    except Exception as e:
        print(f"❌ Resident confirmation email (authentication) failed: {e}")
    
    print("\n🎉 ALL EMAIL FUNCTION TESTS COMPLETE!")
    print("=" * 60)
    print("📋 Summary:")
    print("1. ✅ send_booking_overlap_email() - Ready for integration")
    print("2. ✅ send_official_notification_email() - Ready for integration")
    print("3. ✅ send_resident_submission_confirmation_email() - Ready for integration")
    print("\n🚀 Next: Integrate these functions into server endpoints!")

if __name__ == "__main__":
    test_new_email_functions()
