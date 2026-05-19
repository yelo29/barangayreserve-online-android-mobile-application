#!/usr/bin/env python3

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from email_service import EmailService

def test_overlap_email_exact():
    """Test with exact data from server logs"""
    
    print("🔍 TESTING OVERLAP EMAIL WITH EXACT SERVER DATA")
    print("=" * 60)
    
    # Exact data from server logs
    resident_email = "jl052904@gmail.com"
    resident_name = "Jose Luis"
    
    # Original booking data (from overlapping resident booking)
    original_booking = {
        'facility_name': 'Basketball Court',
        'booking_date': '2026-03-31',
        'start_time': '6:00 PM',
        'end_time': '8:00 PM',
        'purpose': 'Basketball Game',
        'status': 'rejected',
        'booking_reference': 'BR198',
        'submitted_at': '2026-03-07 19:17:12'
    }
    
    # Official booking details (from server)
    official_booking = {
        'facility_name': 'Basketball Court',
        'booking_date': '2026-03-31',
        'timeslot': 'ALL DAY',
        'start_time': 'ALL DAY',
        'end_time': 'ALL DAY',
        'purpose': 'Official barangay business',
        'status': 'approved',
        'booking_reference': 'BR202603071917121',
        'official_name': 'Barangay Official',
        'official_contact': '09123456789',
        'submitted_at': '2026-03-07 19:17:12'
    }
    
    try:
        email_service = EmailService()
        
        print(f"📧 Sending overlap email to: {resident_email}")
        print(f"👤 Resident Name: {resident_name}")
        print(f"🏢 Facility: {original_booking['facility_name']}")
        print(f"📅 Date: {original_booking['booking_date']}")
        print(f"⏰ Time: {original_booking['start_time']} - {original_booking['end_time']}")
        print(f"📝 Purpose: {original_booking['purpose']}")
        print(f"👔 Official: {official_booking['official_name']}")
        print(f"🏢 Official Purpose: {official_booking['purpose']}")
        print()
        
        result = email_service.send_booking_overlap_email(
            resident_email=resident_email,
            resident_name=resident_name,
            original_booking=original_booking,
            official_booking=official_booking
        )
        
        print(f"📧 Result: {result}")
        
        if result:
            print("✅ OVERLAP EMAIL SENT SUCCESSFULLY!")
        else:
            print("❌ OVERLAP EMAIL FAILED!")
            
    except Exception as e:
        print(f"❌ ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_overlap_email_exact()
