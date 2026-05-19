#!/usr/bin/env python3

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from email_service import EmailService

def test_authentication_request_email():
    """Test authentication request email to officials"""
    
    print("🔍 TESTING AUTHENTICATION REQUEST EMAIL TO OFFICIALS")
    print("=" * 60)
    
    try:
        email_service = EmailService()
        
        # Sample resident details
        resident_details = {
            'full_name': 'Juan Dela Cruz',
            'email': 'juan.delacruz@example.com',
            'contact_number': '09123456789',
            'verification_status': 'Pending Verification'
        }
        
        # Sample request details
        request_details = {
            'submitted_at': '2026-03-07 20:35:00',
            'reference_number': 'VR-52-20260307203500',
            'verification_type': 'resident',
            'discount_rate': '10%',
            'address': '123 Barangay St, Brgy. Masigla, City'
        }
        
        print(f"📧 Sending authentication request notification to officials")
        print(f"👤 Resident: {resident_details['full_name']} ({resident_details['email']})")
        print(f"📋 Verification Type: {request_details['verification_type']}")
        print(f"🎯 Discount Rate: {request_details['discount_rate']}")
        print(f"📅 Submitted: {request_details['submitted_at']}")
        print(f"🔖 Reference: {request_details['reference_number']}")
        print()
        
        result = email_service.send_official_notification_email(
            request_type="authentication",
            resident_details=resident_details,
            request_details=request_details
        )
        
        print(f"📧 Result: {result}")
        
        if result:
            print("✅ AUTHENTICATION REQUEST EMAIL SENT TO OFFICIALS SUCCESSFULLY!")
        else:
            print("❌ AUTHENTICATION REQUEST EMAIL FAILED!")
            
    except Exception as e:
        print(f"❌ ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_authentication_request_email()
