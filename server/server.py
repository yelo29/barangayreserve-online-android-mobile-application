#!/usr/bin/env python3
"""
Barangay Reserve Server
Free, self-hosted solution for students
"""

from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import sqlite3
import json
from datetime import datetime, timedelta
import os
import random
import string
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from config import Config
from email_service import email_service
import requests
import jwt
import time
from datetime import datetime, timezone

app = Flask(__name__)
# Dynamic CORS configuration for DuckDNS
CORS(app, origins=Config.get_cors_origins())

# Database setup
def init_db():
    import sqlite3
    conn = sqlite3.connect(Config.DATABASE_PATH)
    cursor = conn.cursor()
    
    # Create tables
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE,
            password TEXT,
            full_name TEXT,
            role TEXT,
            verified BOOLEAN DEFAULT FALSE,
            discount_rate REAL DEFAULT 0.0,
            contact_number TEXT,
            address TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS facilities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            description TEXT,
            price REAL,
            image_url TEXT,
            active BOOLEAN DEFAULT 1,
            amenities TEXT,
            downpayment REAL,
            capacity INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS bookings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            facility_id INTEGER,
            user_email TEXT,
            date TEXT,
            timeslot TEXT,
            purpose TEXT,
            status TEXT DEFAULT 'pending',
            payment_details TEXT,
            receipt_base64 TEXT,
            contact_number TEXT,
            address TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (facility_id) REFERENCES facilities (id)
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS verification_requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            request_reference VARCHAR(20) NOT NULL,
            user_id INTEGER NOT NULL,
            verification_type VARCHAR(20) NOT NULL,
            requested_discount_rate DECIMAL(3,2) NOT NULL,
            user_photo_base64 TEXT,
            user_photo_filename VARCHAR(255),
            valid_id_base64 TEXT,
            valid_id_filename VARCHAR(255),
            proof_of_residency_base64 TEXT,
            proof_of_residency_filename VARCHAR(255),
            additional_documents TEXT,
            residential_address TEXT,
            years_of_residence INTEGER,
            status VARCHAR(30) DEFAULT 'pending',
            reviewed_by INTEGER,
            reviewed_at DATETIME,
            approval_notes TEXT,
            rejection_reason TEXT,
            additional_info_requested TEXT,
            additional_info_provided TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    # Create OTP table for email verification
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS email_otps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL,
            otp_code TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            expires_at DATETIME NOT NULL,
            is_used BOOLEAN DEFAULT FALSE,
            FOREIGN KEY (email) REFERENCES users (email)
        )
    ''')
    
    conn.commit()
    conn.close()

# Email service configuration
EMAIL_CONFIG = {
    'smtp_server': 'smtp.gmail.com',
    'smtp_port': 587,
    'email': 'leo052904@gmail.com',
    'password': 'tqlf yzje rxkc lnkn'
}

def generate_otp():
    """Generate 6-digit OTP code"""
    return ''.join(random.choices(string.digits, k=6))

def send_otp_email(email, otp_code):
    """Send OTP code to user's email"""
    try:
        msg = MIMEMultipart()
        msg['From'] = EMAIL_CONFIG['email']
        msg['To'] = email
        msg['Subject'] = 'Barangay Reserve - Email Verification Code'
        
        body = f'''
        Hello,
        
        Your email verification code for Barangay Reserve is:
        
        {otp_code}
        
        This code will expire in 10 minutes.
        
        If you didn't request this code, please ignore this email.
        
        Thank you,
        Barangay Reserve Team
        '''
        
        msg.attach(MIMEText(body, 'plain'))
        
        server = smtplib.SMTP(EMAIL_CONFIG['smtp_server'], EMAIL_CONFIG['smtp_port'])
        server.starttls()
        server.login(EMAIL_CONFIG['email'], EMAIL_CONFIG['password'])
        text = msg.as_string()
        server.sendmail(EMAIL_CONFIG['email'], email, text)
        server.quit()
        
        print(f"✅ OTP email sent to {email}")
        return True
    except Exception as e:
        print(f"❌ Failed to send OTP email: {e}")
        return False

# Initialize database on startup
init_db()

# Helper function to get database connection
def get_db_connection():
    print(f"🔍 DEBUG: Connecting to database at: {Config.DATABASE_PATH}")
    conn = sqlite3.connect(Config.DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    return conn

# Alias for backward compatibility
def get_db():
    return get_db_connection()

# Add missing columns to existing database
def migrate_database():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Add missing columns to facilities table if they don't exist
    try:
        cursor.execute('ALTER TABLE facilities ADD COLUMN active BOOLEAN DEFAULT 1')
    except:
        pass  # Column might already exist
    
    try:
        cursor.execute('ALTER TABLE facilities ADD COLUMN amenities TEXT')
    except:
        pass  # Column might already exist
    
    try:
        cursor.execute('ALTER TABLE facilities ADD COLUMN downpayment REAL')
    except:
        pass  # Column might already exist
    
    try:
        cursor.execute('ALTER TABLE facilities ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP')
    except:
        pass  # Column might already exist
    
    conn.commit()
    conn.close()
    print("Database migration completed")

# Run migration
migrate_database()

# API Routes

@app.route('/api/status')
def server_status():
    return jsonify({
        'message': 'Barangay Reserve Server Running!',
        'status': 'online',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/me', methods=['GET'])
def get_current_user():
    # This is a simplified version - in production, you'd validate the JWT token
    # For now, we'll return a mock user or require email parameter
    email = request.args.get('email')
    if not email:
        return jsonify({'success': False, 'error': 'Email parameter required'})
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Use the same query as Gmail auth for consistency
    cursor.execute('SELECT * FROM users WHERE email = ?', (email,))
    user = cursor.fetchone()
    
    conn.close()
    
    if user:
        return jsonify({
            'success': True,
            'user': {
                'id': user[0],
                'email': user[1],
                'full_name': user[3],  # Fixed: full_name is at index 3
                'role': user[4],        # Fixed: role is at index 4
                'verified': bool(user[5]),  # Fixed: verified is at index 5, convert to bool
                'verification_type': user[6],  # Fixed: verification_type is at index 6
                'discount_rate': user[7],    # Fixed: discount_rate is at index 7
                'contact_number': user[8],    # Fixed: contact_number is at index 8
                'address': user[9],          # Fixed: address is at index 9
                'profile_photo_url': user[10],  # Fixed: profile_photo_url is at index 10
                'is_active': bool(user[12]),  # Fixed: is_active is at index 12
                'email_verified': bool(user[13]),  # Fixed: email_verified is at index 13
                'last_login': user[14],       # Fixed: last_login is at index 14
                'created_at': user[15],       # Fixed: created_at is at index 15
                'updated_at': user[16],       # Fixed: updated_at is at index 16
            }
        })
    else:
        return jsonify({'success': False, 'error': 'User not found'})

@app.route('/api/facilities', methods=['GET'])
def get_facilities():
    try:
        conn = get_db()
        facilities = conn.execute('SELECT * FROM facilities').fetchall()
        conn.close()
        
        facilities_list = [dict(facility) for facility in facilities]
        
        return jsonify({
            'success': True,
            'data': facilities_list
        })
    except Exception as e:
        print(f"❌ Facilities endpoint error: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/bookings', methods=['GET'])
def get_bookings():
    print("🔍 BOOKINGS ENDPOINT CALLED!")  # Simple debug test
    user_email = request.args.get('user_email')
    user_role = request.args.get('user_role', 'resident')  # Default to resident for privacy
    facility_id = request.args.get('facility_id')  # NEW: Facility filtering
    date = request.args.get('date')  # NEW: Date filtering
    exclude_user_role = request.args.get('excludeUserRole', '').lower() == 'true'  # New parameter to exclude user role filtering
    
    print(f"🔍 DEBUG: Parameters - facility_id={facility_id}, date={date}, user_role={user_role}, user_email={user_email}")
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        if exclude_user_role:
            # Return ALL bookings without any user role filtering (for official use)
            print("🔍 Returning ALL bookings (excludeUserRole=true)")
            
            # Build query with optional facility and date filtering
            query = '''
                SELECT b.id, b.booking_reference, b.user_id, b.facility_id, b.time_slot_id, 
                       b.booking_date, b.start_time, b.end_time, b.duration_hours,
                       b.purpose, b.expected_attendees, b.special_requirements,
                       b.contact_number, b.contact_address, b.base_rate, b.discount_rate,
                       b.discount_amount, b.downpayment_amount, b.total_amount,
                       b.receipt_base64, b.receipt_filename, b.receipt_uploaded_at,
                       b.status, b.priority_level, b.approved_by, b.approved_at,
                       b.rejection_reason, b.is_competitive, b.competing_booking_ids,
                       b.competition_resolved, b.created_at, b.updated_at,
                       f.name as facility_name, u.full_name, u.email as user_email, u.verified, u.discount_rate, u.role as user_role, u.profile_photo_url
                FROM bookings b
                LEFT JOIN facilities f ON b.facility_id = f.id
                LEFT JOIN users u ON b.user_id = u.id
            '''
            
            params = []
            conditions = []
            
            if facility_id:
                conditions.append('b.facility_id = ?')
                params.append(facility_id)
            
            if date:
                conditions.append('b.booking_date = ?')
                params.append(date)
            
            if conditions:
                query += ' WHERE ' + ' AND '.join(conditions)
            
            query += ' ORDER BY b.booking_date DESC, b.start_time ASC'
            
            print(f"🔍 DEBUG: Query: {query}")
            print(f"🔍 DEBUG: Params: {params}")
            
            bookings = cursor.execute(query, params).fetchall()
            
            # Create dictionary manually with proper column names
            result = []
            column_names = [
                'id', 'booking_reference', 'user_id', 'facility_id', 'time_slot_id',
                'booking_date', 'start_time', 'end_time', 'duration_hours',
                'purpose', 'expected_attendees', 'special_requirements',
                'contact_number', 'contact_address', 'base_rate', 'discount_rate',
                'discount_amount', 'downpayment_amount', 'total_amount',
                'receipt_base64', 'receipt_filename', 'receipt_uploaded_at',
                'status', 'priority_level', 'approved_by', 'approved_at',
                'rejection_reason', 'is_competitive', 'competing_booking_ids',
                'competition_resolved', 'created_at', 'updated_at',
                'facility_name', 'full_name', 'user_email', 'verified', 'discount_rate', 'user_role', 'profile_photo_url'
            ]
            
            for booking in bookings:
                booking_dict = {}
                for i, col_name in enumerate(column_names):
                    if i < len(booking):
                        booking_dict[col_name] = booking[i]
                result.append(booking_dict)
        elif user_role == 'resident' and user_email:
            # Residents can see filtered bookings for calendar (but without sensitive details)
            print("🔍 Returning filtered bookings for resident")
            
            # Build query with optional facility and date filtering
            query = '''
                SELECT b.*, f.name as facility_name, u.full_name, u.email as user_email, u.verified, u.discount_rate, u.role as user_role, u.profile_photo_url
                FROM bookings b
                LEFT JOIN facilities f ON b.facility_id = f.id
                LEFT JOIN users u ON b.user_id = u.id
            '''
            
            params = []
            conditions = []
            
            if facility_id:
                conditions.append('b.facility_id = ?')
                params.append(facility_id)
            
            if date:
                conditions.append('b.booking_date = ?')
                params.append(date)
            
            if conditions:
                query += ' WHERE ' + ' AND '.join(conditions)
            
            query += ' ORDER BY b.booking_date DESC, b.start_time ASC'
            
            print(f"🔍 DEBUG: Resident Query: {query}")
            print(f"🔍 DEBUG: Resident Params: {params}")
            
            bookings = cursor.execute(query, params).fetchall()
            
            # For residents, return only essential booking info (privacy protection)
            result = []
            for booking in bookings:
                booking_dict = dict(booking)
                
                # Debug logging for privacy check
                # Only apply privacy masking for non-official users
                if user_role != 'official':
                    # Get user_id for current user
                    current_user_id = None
                    if user_email:
                        cursor.execute('SELECT id FROM users WHERE email = ?', (user_email,))
                        user_result = cursor.fetchone()
                        if user_result:
                            current_user_id = user_result[0]  # Fixed: Access tuple by index, not dict key
                    
                    is_own_booking = (current_user_id and booking_dict['user_id'] == current_user_id and 
                                    booking_dict['user_email'] and user_email and 
                                    booking_dict['user_email'].lower().strip() == user_email.lower().strip())
                    
                    if not is_own_booking:
                        # Apply privacy masking for other residents' bookings
                        if booking_dict['user_email'] and user_email and booking_dict['user_email'].lower().strip() != user_email.lower().strip():
                            original_email = booking_dict['user_email']
                            
                            # Remove sensitive details but keep essential info
                            booking_dict['full_name'] = 'Private' if booking_dict['full_name'] in ['None', '', 'N/A', 'Unknown'] else booking_dict['full_name']
                            booking_dict['contact_number'] = 'Private' if booking_dict['contact_number'] in ['None', '', 'N/A', 'Unknown'] else booking_dict['contact_number']
                            booking_dict['contact_address'] = 'Private' if booking_dict['contact_address'] in ['None', '', 'N/A', 'Unknown'] else booking_dict['contact_address']
                            
                            # Only mask receipt if it exists
                            if booking_dict.get('receipt_base64'):
                                booking_dict['receipt_base64'] = '[RECEIPT HIDDEN FOR PRIVACY]'
                            
                            # Mask purpose only if it contains sensitive info
                            if booking_dict.get('purpose') and any(word in booking_dict.get('purpose', '').lower() for word in ['private', 'confidential', 'secret']):
                                booking_dict['purpose'] = 'Private Purpose'
                            else:
                                booking_dict['purpose'] = booking_dict.get('purpose', '')
                            
                            # Store original email for official detection
                            booking_dict['original_email'] = booking_dict['user_email']
                            
                            # Add flag for official detection
                            booking_dict['is_official_booking'] = (
                                'official' in original_email or 
                                'barangay' in original_email or 
                                'admin' in original_email
                            )
                            print(f"🔍 PRIVACY APPLIED: Masked booking for user {original_email}")
                        else:
                            print(f"🔍 PRIVACY NOT APPLIED: User can see full booking details")
                    else:
                        print(f"🔍 PRIVACY NOT APPLIED: User can see full booking details")
                else:
                    print(f"🔍 PRIVACY NOT APPLIED: User can see full booking details")
                
                result.append(booking_dict)
                
        elif user_role == 'official':
            # Officials can see filtered bookings
            print("🔍 Returning filtered bookings for official")
            
            # Build query with optional facility and date filtering
            query = '''
                SELECT b.*, f.name as facility_name, u.full_name, u.email as user_email, u.verified, u.discount_rate, u.role as user_role, u.profile_photo_url
                FROM bookings b
                LEFT JOIN facilities f ON b.facility_id = f.id
                LEFT JOIN users u ON b.user_id = u.id
            '''
            
            params = []
            conditions = []
            
            if facility_id:
                conditions.append('b.facility_id = ?')
                params.append(facility_id)
            
            if date:
                conditions.append('b.booking_date = ?')
                params.append(date)
            
            if conditions:
                query += ' WHERE ' + ' AND '.join(conditions)
            
            query += ' ORDER BY b.booking_date DESC, b.start_time ASC'
            
            print(f"🔍 DEBUG: Official Query: {query}")
            print(f"🔍 DEBUG: Official Params: {params}")
            
            bookings = cursor.execute(query, params).fetchall()
            result = [dict(booking) for booking in bookings]
        else:
            result = []
            
        return jsonify({
            'success': True,
            'data': result
        })
            
    except Exception as e:
        print(f"❌ Error in bookings endpoint: {e}")
        return jsonify({'success': False, 'message': 'Error fetching bookings'}), 500
    finally:
        conn.close()

@app.route('/api/bookings/<int:booking_id>/status', methods=['PUT'])
def update_booking_status(booking_id):
    try:
        data = request.get_json()
        new_status = data.get('status')
        rejection_reason = data.get('rejection_reason')
        rejection_type = data.get('rejection_type')  # NEW: 'incorrect_downpayment' or 'fake_receipt'
        
        if new_status not in ['pending', 'approved', 'rejected']:
            return jsonify({'success': False, 'message': 'Invalid status'}), 400
        
        conn = get_db()
        cursor = conn.cursor()
        
        # Get the booking details before updating
        cursor.execute('''
            SELECT facility_id, booking_date, start_time, user_id, status 
            FROM bookings WHERE id = ?
        ''', (booking_id,))
        
        booking = cursor.fetchone()
        if not booking:
            conn.close()
            return jsonify({'success': False, 'message': 'Booking not found'}), 404
        
        facility_id, date, timeslot, user_id, current_status = booking
        
        print(f"🔍 DEBUG: Updating booking {booking_id} from {current_status} to {new_status}")
        if rejection_reason:
            print(f"🔍 DEBUG: Rejection reason: {rejection_reason}")
        if rejection_type:
            print(f"🔍 DEBUG: Rejection type: {rejection_type}")
        else:
            print(f"🔍 DEBUG: Rejection type is NULL or missing")
        
        # NEW: Handle violation tracking for fake receipt rejections
        if new_status == 'rejected' and rejection_type == 'fake_receipt':
            print(f"🚨 VIOLATION DETECTED: Fake receipt rejection for user {user_id}")
            
            # Get current violation count
            cursor.execute('SELECT fake_booking_violations, is_banned FROM users WHERE id = ?', (user_id,))
            user_violations = cursor.fetchone()
            
            if user_violations:
                current_violations, is_banned = user_violations
                
                if is_banned:
                    conn.close()
                    return jsonify({'success': False, 'message': 'User is already banned'}), 400
                
                new_violations = current_violations + 1
                print(f"🔢 VIOLATION COUNT: {current_violations} -> {new_violations}")
                
                # Check if this is the 3rd violation (permanent ban)
                if new_violations >= 3:
                    print(f"🚫 PERMANENT BAN: User {user_id} reached 3 violations")
                    
                    # Update user to banned status
                    cursor.execute('''
                        UPDATE users 
                        SET fake_booking_violations = ?, 
                            is_banned = TRUE, 
                            banned_at = CURRENT_TIMESTAMP,
                            ban_reason = 'Permanent ban after 3 fake receipt violations'
                        WHERE id = ?
                    ''', (new_violations, user_id))
                    
                    ban_reason = "Your payment receipt is fake or shown no payment in our payment history/records, ⚠️ know that this violation will be recorded and you will only have three chances before getting your account banned! This is your 3rd violation - your account has been permanently banned."
                    
                else:
                    print(f"⚠️ WARNING: User {user_id} now has {new_violations}/3 violations")
                    
                    # Update violation count
                    cursor.execute('''
                        UPDATE users 
                        SET fake_booking_violations = ?
                        WHERE id = ?
                    ''', (new_violations, user_id))
                    
                    remaining_chances = 3 - new_violations
                    ban_reason = f"Your payment receipt is fake or shown no payment in our payment history/records, ⚠️ know that this violation will be recorded and you will only have {remaining_chances} chance{'s' if remaining_chances > 1 else ''} remaining before getting your account banned!"
                
                # Update rejection reason with violation warning
                rejection_reason = ban_reason
                
                print(f"📝 Updated rejection reason with violation warning")
        else:
            print(f"🔍 DEBUG: Skipping violation tracking - status: {new_status}, type: {rejection_type}")
        
        # Update the booking status and rejection reason
        if rejection_reason and new_status == 'rejected':
            cursor.execute('''
                UPDATE bookings 
                SET status = ?, rejection_reason = ?, rejection_type = ?
                WHERE id = ?
            ''', (new_status, rejection_reason, rejection_type, booking_id))
            print(f"🔍 DEBUG: Updated booking {booking_id} with rejection reason and type")
        else:
            cursor.execute('''
                UPDATE bookings 
                SET status = ?, rejection_type = ?
                WHERE id = ?
            ''', (new_status, rejection_type, booking_id))
            print(f"🔍 DEBUG: Updated booking {booking_id} status and type")
        
        # 📧 Send email notifications for status changes
        try:
            # Get user and booking details for email
            cursor.execute('''
                SELECT u.email, u.full_name, f.name as facility_name, b.booking_date, b.start_time, b.booking_reference
                FROM bookings b
                JOIN users u ON b.user_id = u.id
                JOIN facilities f ON b.facility_id = f.id
                WHERE b.id = ?
            ''', (booking_id,))
            
            booking_details = cursor.fetchone()
            if booking_details:
                user_email, user_name, facility_name, booking_date, start_time, booking_reference = booking_details
                
                booking_info = {
                    'facility_name': facility_name,
                    'booking_date': booking_date,
                    'timeslot': start_time,  # Use start_time as timeslot
                    'booking_reference': booking_reference
                }
                
                if new_status == 'rejected':
                    # Send rejection email
                    email_service.send_booking_rejection_email(
                        recipient_email=user_email,
                        recipient_name=user_name,
                        booking_details=booking_info,
                        rejection_reason=rejection_reason or "Booking rejected by administrator",
                        rejection_type=rejection_type
                    )
                    print(f"📧 Rejection email sent to {user_email}")
                    
                elif new_status == 'approved':
                    # Send approval email
                    email_service.send_booking_approval_email(
                        recipient_email=user_email,
                        recipient_name=user_name,
                        booking_details=booking_info
                    )
                    print(f"📧 Approval email sent to {user_email}")
                    
        except Exception as email_error:
            print(f"❌ Error sending email notification: {email_error}")
            # Don't fail the booking update if email fails
        
        # If approving, automatically reject other pending bookings for the same time slot
        if new_status == 'approved' and current_status == 'pending':
            print(f"🏆 Approving booking {booking_id} and rejecting competitors for {facility_id} {date} {timeslot}")
            
            # Get details of competing bookings for email notifications
            cursor.execute('''
                SELECT b.id, u.email, u.full_name, f.name as facility_name, b.booking_date, b.start_time, b.booking_reference
                FROM bookings b
                JOIN users u ON b.user_id = u.id
                JOIN facilities f ON b.facility_id = f.id
                WHERE b.facility_id = ? AND b.booking_date = ? AND b.start_time = ? 
                AND b.user_id != ? AND b.status = 'pending'
            ''', (facility_id, date, timeslot, user_id))
            
            competing_bookings = cursor.fetchall()
            
            cursor.execute('''
                UPDATE bookings 
                SET status = 'rejected'
                WHERE facility_id = ? AND booking_date = ? AND start_time = ? 
                AND user_id != ? AND status = 'pending'
            ''', (facility_id, date, timeslot, user_id))
            
            rejected_count = cursor.rowcount
            print(f"🚫 Auto-rejected {rejected_count} competing bookings")
            
            # 📧 Send rejection emails to competing bookings
            for competing_booking in competing_bookings:
                try:
                    comp_booking_id, comp_email, comp_name, comp_facility, comp_date, comp_start_time, comp_reference = competing_booking
                    
                    comp_booking_info = {
                        'facility_name': comp_facility,
                        'booking_date': comp_date,
                        'timeslot': comp_start_time,  # Use start_time as timeslot
                        'booking_reference': comp_reference
                    }
                    
                    email_service.send_booking_rejection_email(
                        recipient_email=comp_email,
                        recipient_name=comp_name,
                        booking_details=comp_booking_info,
                        rejection_reason="Your booking was automatically rejected because another booking was approved for the same time slot.",
                        rejection_type="auto_rejection"
                    )
                    print(f"📧 Auto-rejection email sent to {comp_email}")
                    
                except Exception as email_error:
                    print(f"❌ Error sending auto-rejection email: {email_error}")
                    # Don't fail the booking update if email fails
        
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'message': f'Booking {new_status} successfully'})
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/bookings/check-conflict', methods=['POST'])
def check_booking_conflict():
    """Check if there's a booking conflict for the given facility, date, and time"""
    try:
        data = request.get_json()
        print(f"🔍 DEBUG: Checking booking conflict for: {data}")
        
        # Validate required fields
        required_fields = ['facility_id', 'date', 'timeslot', 'user_email']
        for field in required_fields:
            if field not in data:
                return jsonify({'success': False, 'message': f'Missing required field: {field}'}), 400
        
        conn = get_db()
        cursor = conn.cursor()
        
        # Get user_id from email
        cursor.execute('SELECT id FROM users WHERE email = ?', (data['user_email'],))
        user_result = cursor.fetchone()
        
        if not user_result:
            return jsonify({'success': False, 'message': 'User not found'}), 404
        
        user_id = user_result[0]
        
        # Check for existing bookings at the same time (excluding user's own bookings)
        cursor.execute('''
            SELECT id, user_email, created_at, status
            FROM bookings 
            WHERE facility_id = ? 
            AND date = ? 
            AND timeslot = ?
            AND user_email != ?
            AND status IN ('pending', 'approved')
            ORDER BY created_at DESC
        ''', (data['facility_id'], data['date'], data['timeslot'], data['user_email']))
        
        existing_bookings = cursor.fetchall()
        print(f"🔍 DEBUG: Found {len(existing_bookings)} existing bookings for this time slot")
        
        conn.close()
        
        if existing_bookings:
            # Return conflict information
            latest_booking = existing_bookings[0]
            return jsonify({
                'success': True,
                'has_conflict': True,
                'conflict_info': {
                    'booking_id': latest_booking[0],
                    'user_email': latest_booking[1],
                    'created_at': latest_booking[2],
                    'status': latest_booking[3],
                    'message': 'We are very sorry but someone already booked that certain Time. Please pick a different time instead'
                }
            })
        else:
            return jsonify({
                'success': True,
                'has_conflict': False,
                'message': 'Time slot is available'
            })
            
    except Exception as e:
        print(f"❌ Error checking booking conflict: {e}")
        return jsonify({'success': False, 'message': f'Error checking conflict: {str(e)}'}), 500

@app.route('/api/bookings', methods=['POST'])
def create_booking():
    data = request.json
    print(f"🔍 DEBUG: create_booking called with data: {data}")
    print(f"🔍 DEBUG: receipt_base64 in data: {'receipt_base64' in data}")
    if 'receipt_base64' in data:
        print(f"🔍 DEBUG: receipt_base64 length: {len(str(data['receipt_base64']))}")
        print(f"🔍 DEBUG: receipt_base64 starts with data:image: {str(data['receipt_base64']).startswith('data:image')}")
    
    # Validate required fields
    required_fields = ['facility_id', 'user_email', 'date', 'timeslot']
    for field in required_fields:
        if field not in data:
            return jsonify({'success': False, 'message': f'Missing required field: {field}'}), 400
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        print(f"🔍 DEBUG: Database path: {Config.DATABASE_PATH}")
        
        # Get user_id from email
        cursor.execute('SELECT id, role, is_banned, ban_reason FROM users WHERE email = ?', (data['user_email'],))
        user_result = cursor.fetchone()
        
        if not user_result:
            return jsonify({'success': False, 'message': 'User not found'}), 404
        
        user_id = user_result[0]
        user_role = user_result[1]
        is_banned = user_result[2]
        ban_reason = user_result[3]
        
        # 🔒 BAN VALIDATION: Check if user is banned
        if is_banned:
            print(f"🚨 BANNED USER ATTEMPTED BOOKING: {data['user_email']} - Reason: {ban_reason}")
            return jsonify({
                'success': False, 
                'message': 'Account is banned. Cannot create bookings.',
                'error_type': 'user_banned',
                'ban_reason': ban_reason or 'Account has been banned by administrator.'
            }), 403
        
        print(f"🔍 DEBUG: Found user_id: {user_id}, role: {user_role}, banned: {is_banned} for email: {data['user_email']}")
        
        # Check if this is an official booking
        is_official_booking = user_role == 'official'
        print(f"🔍 DEBUG: Is official booking: {is_official_booking}")
        print(f"🔍 DEBUG: User role: {user_role}")
        print(f"🔍 DEBUG: User email: {data['user_email']}")
        print(f"🔍 DEBUG: Timeslot: {data['timeslot']}")
        
        # Check if USER already has this exact time slot (prevent duplicate user bookings)
        cursor.execute('''
            SELECT id, user_id, status FROM bookings 
            WHERE facility_id = ? AND booking_date = ? AND start_time = ? AND user_id = ?
        ''', (data['facility_id'], data['date'], data['timeslot'], user_id))
        
        user_existing_booking = cursor.fetchone()
        
        # If user already has this exact time slot, block it
        if user_existing_booking:
            return jsonify({
                'success': False, 
                'message': 'You already have a booking for this time slot. Please choose a different time.',
                'error_type': 'duplicate_user_booking'
            }), 409
        
        # AUTO-REJECTION LOGIC FOR OFFICIAL BOOKINGS
        rejected_resident_bookings = []
        if is_official_booking:
            print(f"🏆 OFFICIAL BOOKING DETECTED - Checking for resident bookings (pending + approved) for time slot {data['timeslot']}...")
            print(f"🔍 DEBUG: Auto-rejection logic triggered for timeslot: {data['timeslot']}")
            
            # Find resident bookings (pending AND approved) that overlap with this time slot
            print(f"🔍 DEBUG: Timeslot value: '{data['timeslot']}' (type: {type(data['timeslot'])})")
            print(f"🔍 DEBUG: Timeslot == 'ALL DAY': {data['timeslot'] == 'ALL DAY'}")
            
            # Check if this is an ALL DAY booking (handle potential string concatenation issues)
            is_all_day = data['timeslot'] == 'ALL DAY' or data['timeslot'].startswith('ALL DAY')
            print(f"🔍 DEBUG: is_all_day: {is_all_day}")
            
            if is_all_day:
                # For ALL DAY bookings, find ALL resident bookings on this date
                print(f"🔍 DEBUG: ALL DAY query - facility_id: {data['facility_id']}, date: {data['date']}, user_id: {user_id}")
                cursor.execute('''
                    SELECT b.id, b.user_id, b.start_time, b.end_time, b.status, b.purpose, b.booking_reference,
                           u.email as user_email, u.full_name
                    FROM bookings b
                    LEFT JOIN users u ON b.user_id = u.id
                    WHERE b.facility_id = ? 
                    AND b.booking_date = ? 
                    AND (b.status = 'pending' OR b.status = 'approved')
                    AND (u.role = 'resident' OR u.role = '0' OR u.role IS NULL OR u.role LIKE '0.%')
                    AND b.user_id != ?
                ''', (data['facility_id'], data['date'], user_id))
            else:
                # For specific time slots, find exact matches
                cursor.execute('''
                    SELECT b.id, b.user_id, b.start_time, b.end_time, b.status, b.purpose, b.booking_reference,
                           u.email as user_email, u.full_name
                    FROM bookings b
                    LEFT JOIN users u ON b.user_id = u.id
                    WHERE b.facility_id = ? 
                    AND b.booking_date = ? 
                    AND b.start_time = ?
                    AND (b.status = 'pending' OR b.status = 'approved')
                    AND (u.role = 'resident' OR u.role = '0' OR u.role IS NULL OR u.role LIKE '0.%')
                    AND b.user_id != ?
                ''', (data['facility_id'], data['date'], data['timeslot'], user_id))
            
            overlapping_bookings = cursor.fetchall()
            print(f"🔍 DEBUG: Found {len(overlapping_bookings)} overlapping resident bookings")
            
            # Get facility name for emails
            cursor.execute('SELECT name FROM facilities WHERE id = ?', (data['facility_id'],))
            facility_result = cursor.fetchone()
            facility_name = facility_result[0] if facility_result else 'Unknown Facility'
            
            # Get official user details for emails
            cursor.execute('SELECT full_name, contact_number FROM users WHERE id = ?', (user_id,))
            official_result = cursor.fetchone()
            official_name = official_result[0] if official_result else 'Barangay Official'
            official_contact = official_result[1] if official_result and len(official_result) > 1 else '0912-345-6789'
            
            # Auto-reject overlapping resident bookings with proper email service
            for booking in overlapping_bookings:
                # Extract resident booking info
                booking_id = booking[0]
                resident_user_id = booking[1]
                resident_start_time = booking[2]
                resident_end_time = booking[3]
                resident_status = booking[4]  # Get original status (pending/approved)
                resident_purpose = booking[5] if len(booking) > 5 and booking[5] else 'Resident booking'
                booking_reference = booking[6] if len(booking) > 6 and booking[6] else f'BR{booking_id}'
                resident_email = booking[7] if len(booking) > 7 and booking[7] else 'unknown@email.com'
                resident_name = booking[8] if len(booking) > 8 and booking[8] else 'Unknown Resident'
                
                print(f"🚫 AUTO-REJECTING {resident_status.upper()} booking {booking_id} - Time: {resident_start_time}")
                
                # Validate data before sending email
                if not resident_email or resident_email == 'unknown@email.com':
                    print(f"⚠️ WARNING: Invalid email for resident {resident_user_id}: {resident_email}")
                    continue
                
                if not resident_name or resident_name == 'Unknown Resident':
                    print(f"⚠️ WARNING: Invalid name for resident {resident_user_id}: {resident_name}")
                    continue
                    
                # Prepare booking details for overlap email
                overlap_booking_details = {
                    'facility_name': facility_name,
                    'booking_date': data['date'],
                    'timeslot': f"{resident_start_time} - {resident_end_time}",
                    'start_time': resident_start_time,
                    'end_time': resident_end_time,
                    'purpose': resident_purpose,  # Use actual purpose from database
                    'status': 'rejected',
                    'booking_reference': booking_reference,
                    'submitted_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                }
                
                # Prepare official booking details for email
                official_booking_details = {
                    'facility_name': facility_name,
                    'booking_date': data['date'],
                    'timeslot': 'ALL DAY',
                    'start_time': 'ALL DAY',
                    'end_time': 'ALL DAY',
                    'purpose': data.get('purpose', 'Official barangay business'),
                    'status': 'approved',
                    'booking_reference': f'BR{datetime.now().strftime("%Y%m%d%H%M%S")}{user_id}',
                    'official_name': official_name,
                    'official_contact': official_contact,
                    'submitted_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                }
                
                # Send overlap email to resident
                try:
                    overlap_sent = email_service.send_booking_overlap_email(
                        resident_email=resident_email,
                        resident_name=resident_name,
                        original_booking=overlap_booking_details,
                        official_booking=official_booking_details
                    )
                    
                    print(f"📧 Overlap email sent to {resident_email}: {overlap_sent}")
                    
                except Exception as email_error:
                    print(f"❌ Error sending overlap email to {resident_email}: {email_error}")
                
                # Update resident booking to rejected with proper reason
                cursor.execute('''
                    UPDATE bookings 
                    SET status = 'rejected', 
                        rejection_reason = 'OFFICIAL_OVERLAP',
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                ''', (booking_id,))
                
                rejected_resident_bookings.append({
                    'booking_id': booking_id,
                    'booking_reference': booking_reference,
                    'resident_name': resident_name,
                    'resident_email': resident_email,
                    'original_timeslot': resident_start_time,
                    'original_end_time': resident_end_time.split(' - ')[-1] if ' - ' in resident_end_time else resident_end_time,
                    'original_status': 'rejected',
                    'facility_name': facility_name,
                    'overlap_reason': 'Official booking for entire day'
                })
            
            if rejected_resident_bookings:
                print(f"✅ Auto-rejected {len(rejected_resident_bookings)} resident bookings")
        
        # Check if user has too many pending bookings (optional limit)
        cursor.execute('''
            SELECT COUNT(*) FROM bookings 
            WHERE user_id = ? AND status = 'pending'
        ''', (user_id,))
        
        pending_count = cursor.fetchone()[0]
        if pending_count >= 5:  # Limit to 5 pending bookings per user
            return jsonify({
                'success': False, 
                'message': 'You have too many pending bookings. Please wait for approval or cancel some bookings.',
                'error_type': 'too_many_pending'
            }), 429
        
        # ALLOW multiple users to book same time slot (competitive booking)
        # No need to check if other users have this slot - that's the point!
        
        # Create booking
        booking_status = 'approved' if is_official_booking else data.get('status', 'pending')
        print(f"🔍 DEBUG: Setting booking status to: {booking_status}")
        
        cursor.execute('''
            INSERT INTO bookings (facility_id, user_id, booking_date, start_time, end_time, status, purpose, total_amount, contact_number, contact_address, booking_reference, time_slot_id, duration_hours, base_rate, downpayment_amount, receipt_base64)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            data['facility_id'],
            user_id,
            data['date'],
            data['timeslot'],  # start_time
            data['timeslot'],  # end_time (same as start for all-day)
            booking_status,
            data.get('purpose', ''),
            data.get('total_amount', 0),
            data.get('contact_number', ''),
            data.get('address', ''),
            f'BR{datetime.now().strftime("%Y%m%d%H%M%S")}{user_id}',  # Generate booking reference
            0,  # Default time_slot_id for all-day bookings
            24.0,  # Duration hours for all-day booking
            0.0,  # Base rate (free for officials)
            0.0,   # Downpayment amount (free for officials)
            data.get('receipt_base64', None)  # Add receipt_base64 field
        ))
        
        booking_id = cursor.lastrowid
        conn.commit()
        
        # Send email notification to officials about new booking request (only for residents)
        if not is_official_booking:
            try:
                # Get user details for email
                cursor.execute('SELECT full_name, email, contact_number FROM users WHERE id = ?', (user_id,))
                user_details = cursor.fetchone()
                
                if user_details:
                    resident_name = user_details[0] if user_details[0] else 'Unknown Resident'
                    resident_email = user_details[1] if user_details[1] else 'unknown@email.com'
                    resident_contact = user_details[2] if len(user_details) > 2 and user_details[2] else 'Not provided'
                    
                    # Get facility name
                    cursor.execute('SELECT name FROM facilities WHERE id = ?', (data['facility_id'],))
                    facility_result = cursor.fetchone()
                    facility_name = facility_result[0] if facility_result else 'Unknown Facility'
                    
                    # Prepare resident details for email
                    resident_details = {
                        'full_name': resident_name,
                        'email': resident_email,
                        'contact_number': resident_contact,
                        'verification_status': 'Pending Booking Approval'
                    }
                    
                    # Prepare booking details for email
                    booking_details_for_email = {
                        'facility_name': facility_name,
                        'booking_date': data['date'],
                        'start_time': data['timeslot'],
                        'end_time': data['timeslot'],
                        'purpose': data.get('purpose', 'Not specified'),
                        'submitted_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                        'booking_reference': f'BR{datetime.now().strftime("%Y%m%d%H%M%S")}{user_id}',
                        'status': 'pending'
                    }
                    
                    # Send notification email to officials
                    notification_sent = email_service.send_official_notification_email(
                        request_type="booking",
                        resident_details=resident_details,
                        request_details=booking_details_for_email
                    )
                    
                    print(f"📧 Booking notification email sent to officials: {notification_sent}")
                    
            except Exception as email_error:
                print(f"❌ Error sending booking notification email to officials: {email_error}")
                # Don't fail the booking creation if email fails
        
        # Debug: Check if receipt was saved
        if data.get('receipt_base64'):
            print(f"✅ RECEIPT SAVED: receipt_base64 length = {len(str(data['receipt_base64']))} for booking {booking_id}")
        else:
            print(f"⚠️ NO RECEIPT: receipt_base64 is null for booking {booking_id}")
        
        # Prepare response message
        response_message = 'Booking submitted successfully!' if not is_official_booking else 'Official booking created successfully!'
        
        if is_official_booking and rejected_resident_bookings:
            response_message += f' Auto-rejected {len(rejected_resident_bookings)} resident booking(s).'
        
        # Add auto-refresh metadata for frontend
        refresh_data = {
            'trigger': 'booking_created',
            'booking_id': booking_id,
            'facility_id': data['facility_id'],
            'booking_date': data['date'],
            'timeslot': data['timeslot'],
            'user_email': data['user_email'],
            'status': booking_status,
            'timestamp': datetime.now().isoformat(),
            'requires_refresh': [
                'calendar_view',      # Refresh facility calendar
                'bookings_list',      # Refresh user bookings
                'booking_form',       # Refresh booking forms for this facility/date
                'time_slots',         # Refresh available time slots
                'conflict_check'      # Trigger conflict checking for other users
            ],
            'conflict_notification': {
                'facility_id': data['facility_id'],
                'date': data['date'],
                'timeslot': data['timeslot'],
                'message': 'Time slot is no longer available',
                'exclude_user': data['user_email']  # Don't notify the user who just booked
            }
        }
        
        # If official booking rejected resident bookings, add those to refresh data
        if rejected_resident_bookings:
            refresh_data['rejected_bookings'] = rejected_resident_bookings
            refresh_data['requires_refresh'].append('resident_notifications')
        
        return jsonify({
            'success': True, 
            'message': response_message,
            'booking_id': booking_id,
            'status': booking_status,
            'rejected_resident_bookings': rejected_resident_bookings,
            'note': 'Multiple users may book the same time slot. First approved booking wins!' if not is_official_booking else 'Official bookings take priority over resident bookings.',
            'refresh_data': refresh_data  # Auto-refresh instructions
        })
        
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500
    finally:
        conn.close()

@app.route('/api/available-timeslots', methods=['GET'])
def get_available_timeslots():
    """Get available time slots for a specific facility and date (competitive booking)"""
    facility_id = request.args.get('facility_id')
    date = request.args.get('date')
    user_email = request.args.get('user_email')  # Optional: for user-specific availability
    
    print(f"🔍 DEBUG: Available timeslots request - facility_id: {facility_id}, date: {date}, user_email: {user_email}")
    
    if not facility_id or not date:
        return jsonify({'success': False, 'message': 'facility_id and date are required'}), 400
    
    conn = get_db()
    
    try:
        # Get all time slots from database for this facility
        cursor = conn.cursor()
        cursor.execute('''
            SELECT start_time, end_time FROM time_slots 
            WHERE facility_id = ? 
            ORDER BY sort_order
        ''', (facility_id,))
        
        time_slots_db = cursor.fetchall()
        
        # Convert to format expected by frontend
        all_timeslots = []
        for start_time, end_time in time_slots_db:
            # Just use the format "6:00 AM - 8:00 AM" as is
            timeslot_str = f"{start_time} - {end_time}"
            all_timeslots.append(timeslot_str)
        
        print(f"🔍 DEBUG: Found {len(all_timeslots)} time slots for facility {facility_id}")
        
        # Get all bookings for this facility and date (excluding rejected)
        cursor.execute('''
            SELECT start_time, user_id, status FROM bookings 
            WHERE facility_id = ? AND booking_date = ? AND status != 'rejected'
        ''', (facility_id, date))
        
        all_bookings = cursor.fetchall()
        print(f"🔍 DEBUG: Found {len(all_bookings)} bookings for this facility/date")
        for booking in all_bookings:
            print(f"🔍 DEBUG: Booking - timeslot: {booking[0]}, user: {booking[1]}, status: {booking[2]}")
        
        # Categorize time slots for competitive booking
        available_slots = []
        user_booked_slots = []
        competitive_slots = []  # Slots with multiple bookings
        approved_slots = []      # Slots that are already taken (approved)
        
        for timeslot in all_timeslots:
            bookings_for_slot = [b for b in all_bookings if b[0] == timeslot]
            
            if not bookings_for_slot:
                # No bookings for this slot
                available_slots.append(timeslot)
                print(f"🔍 DEBUG: {timeslot} -> available (no bookings)")
            else:
                # NEW LOGIC: Check if ANY resident has booking (pending or approved)
                has_any_booking = any(b[2] in ['approved', 'pending'] for b in bookings_for_slot)
                
                if has_any_booking:
                    # Lock timeslot if any resident has booking (prevents competitive booking)
                    user_booked_slots.append(timeslot)
                    print(f"🔍 DEBUG: {timeslot} -> locked (resident has booking)")
                elif len(bookings_for_slot) > 1:
                    # Multiple pending bookings - competitive!
                    competitive_slots.append(timeslot)
                    print(f"🔍 DEBUG: {timeslot} -> competitive (multiple pending)")
                else:
                    # Single booking - put in user_booked_slots regardless of user (prevents competitive booking)
                    user_booked_slots.append(timeslot)
                    print(f"🔍 DEBUG: {timeslot} -> user booked (any resident)")
                    
                    # Optional: Still track if it's current user for UI purposes
                    if user_email and bookings_for_slot[0][1] == user_email:
                        print(f"🔍 DEBUG: {timeslot} -> current user's booking")
                    else:
                        print(f"🔍 DEBUG: {timeslot} -> other resident's booking")
        
        print(f"🔍 DEBUG: Final counts - available: {len(available_slots)}, user_booked: {len(user_booked_slots)}, competitive: {len(competitive_slots)}, approved: {len(approved_slots)}")
        
        return jsonify({
            'success': True,
            'default_timeslots': all_timeslots,  # Changed from available_timeslots to default_timeslots
            'available_timeslots': available_slots,
            'user_booked_timeslots': user_booked_slots,
            'competitive_timeslots': competitive_slots,  # Slots with any resident booking
            'approved_timeslots': approved_slots,        # Already taken slots
            'total_available': len(available_slots),
            'competitive_count': len(competitive_slots),
            'date': date,
            'facility_id': facility_id,
            'note': 'Time slots are locked when any resident has a booking. First resident to book gets the slot!'
        })
        
    except Exception as e:
        print(f"❌ Error in get_available_timeslots: {e}")
        return jsonify({'success': False, 'message': str(e)}), 500
    finally:
        conn.close()

@app.route('/api/auth/logout', methods=['POST'])
def logout():
    try:
        # In a real app, you would invalidate the session/token here
        # For now, just return success
        return jsonify({
            'success': True,
            'message': 'Logged out successfully'
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/auth/login', methods=['POST'])
def login():
    data = request.json
    
    try:
        print(f"🔍 DEBUG: Login attempt for email: {data.get('email')}")
        conn = get_db()
        print(f"🔍 DEBUG: Database connection established")
        
        query = 'SELECT id, email, password, full_name, role, verified, discount_rate, contact_number, address, created_at, verification_type, is_banned, ban_reason FROM users WHERE email = ?'
        print(f"🔍 DEBUG: Executing query: {query}")
        
        user = conn.execute(query, (data['email'],)).fetchone()
        print(f"🔍 DEBUG: Query result: {user}")
        
        if user:
            # NEW: Check if user is banned before proceeding
            print(f"🔍 DEBUG: User raw data: {user}")
            print(f"🔍 DEBUG: User[10] (verification_type): {user[10]}")
            print(f"🔍 DEBUG: User[11] (is_banned): {user[11]}")
            
            user_dict = {
                'id': user[0],
                'email': user[1],
                'password': user[2],
                'full_name': user[3],
                'role': user[4],
                'verified': bool(user[5]),
                'discount_rate': user[6],
                'contact_number': user[7],
                'address': user[8],
                'created_at': user[9],
                'verification_type': user[10],  # Include actual verification_type from database
                'is_banned': bool(user[11]),  # CRITICAL: Include actual is_banned from database
                'ban_reason': user[12],  # Include actual ban_reason from database
                'profile_photo_url': None,
                'is_active': True,
                'email_verified': True,
                'last_login': None,
                'updated_at': None,
                'fake_booking_violations': 0,
                'banned_at': None,
            }
            
            print(f"🔍 DEBUG: user_dict['verification_type']: {user_dict['verification_type']}")
            
            if user_dict['is_banned']:
                conn.close()
                return jsonify({
                    'success': False,
                    'message': 'This email has been banned permanently'
                }), 403
            
            # Hash the provided password and compare with stored hash
            import hashlib
            password_hash = hashlib.sha256(data['password'].encode()).hexdigest()
            
            if user_dict['password'] == password_hash:
                # Generate a simple session token (in production, use JWT)
                import uuid
                session_token = str(uuid.uuid4())
                
                conn.close()
                
                return jsonify({
                    'success': True,
                    'user': {
                        'id': user_dict['id'],
                        'email': user_dict['email'],
                        'full_name': user_dict['full_name'],
                        'role': user_dict['role'],
                        'verified': user_dict['verified'],
                        'verification_type': user_dict['verification_type'],  # CRITICAL: Include verification_type in response
                        'discount_rate': user_dict['discount_rate'],
                        'contact_number': user_dict['contact_number'],
                        'address': user_dict['address'],
                        'created_at': user_dict['created_at'],
                        'is_authenticated': True
                    },
                    'token': session_token
                })
            else:
                conn.close()
                return jsonify({
                    'success': False,
                    'message': 'Invalid credentials'
                }), 401
        else:
            conn.close()
            return jsonify({
                'success': False,
                'message': 'User not found'
            }), 404
            
    except Exception as e:
        print(f"❌ Login error: {e}")
        return jsonify({
            'success': False,
            'message': f'Login failed: {str(e)}'
        }), 500

@app.route('/api/auth/register', methods=['POST'])
def register():
    data = request.json
    
    # DEBUG: Log incoming registration data
    print(f"🔍 DEBUG: Registration data received: {data}")
    print(f"🔍 DEBUG: Name field: '{data.get('name')}'")
    print(f"🔍 DEBUG: Email field: '{data.get('email')}'")
    print(f"🔍 DEBUG: Contact field: '{data.get('contact_number')}'")
    print(f"🔍 DEBUG: Address field: '{data.get('address')}'")
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        # NEW: Check if email is banned before allowing registration
        # Skip ban check since columns don't exist yet
        # cursor.execute('SELECT is_banned, ban_reason FROM users WHERE email = ?', (data['email'],))
        # banned_user = cursor.fetchone()
        # 
        # if banned_user and banned_user[0]:  # is_banned is True
        #     conn.close()
        #     return jsonify({
        #         'success': False,
        #         'message': 'This email has been banned permanently'
        #     }), 403
        
        # Check if user already exists
        cursor.execute('SELECT id FROM users WHERE email = ?', (data['email'],))
        existing_user = cursor.fetchone()
        
        if existing_user:
            conn.close()
            return jsonify({
                'success': False,
                'message': 'User with this email already exists'
            }), 400
        
        # Hash the password
        import hashlib
        password_hash = hashlib.sha256(data['password'].encode()).hexdigest()
        
        # DEBUG: Log what will be inserted
        print(f"🔍 DEBUG: About to insert into database:")
        print(f"🔍 DEBUG: Email: '{data['email']}'")
        print(f"🔍 DEBUG: Name: '{data['name']}'")
        print(f"🔍 DEBUG: Role: '{data['role']}'")
        print(f"🔍 DEBUG: Contact: '{data.get('contact_number')}'")
        print(f"🔍 DEBUG: Address: '{data.get('address')}'")
        
        cursor.execute('''
            INSERT INTO users (email, password, full_name, role, contact_number, address, email_verified)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (data['email'], password_hash, data['name'], data['role'], 
              data.get('contact_number'), data.get('address'), False))
        
        print("🔍 DEBUG: Database insertion completed")
        
        # Get the newly created user
        cursor.execute('SELECT * FROM users WHERE email = ?', (data['email'],))
        user = cursor.fetchone()
        
        print(f"🔍 DEBUG: Retrieved user from database: {user}")
        print(f"🔍 DEBUG: Full name from database: '{user[3] if user else 'Not found'}'")
        
        conn.commit()
        conn.close()
        
        # Generate OTP for email verification
        otp_code = generate_otp()
        expires_at = datetime.now() + timedelta(minutes=10)
        
        # Store OTP in database
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO email_otps (email, otp_code, expires_at)
            VALUES (?, ?, ?)
        ''', (data['email'], otp_code, expires_at.isoformat()))
        conn.commit()
        conn.close()
        
        # Send OTP email
        email_sent = send_otp_email(data['email'], otp_code)
        
        return jsonify({
            'success': True, 
            'message': 'User registered successfully. Please check your email for verification code.',
            'requires_email_verification': True,
            'email': data['email'],
            'email_sent': email_sent
        })
    except Exception as e:
        print(f"❌ Registration error: {e}")
        conn.close()
        return jsonify({
            'success': False,
            'message': f'Registration failed: {str(e)}'
        }), 500
    except sqlite3.IntegrityError:
        conn.close()
        return jsonify({
            'success': False,
            'message': 'Email already exists'
        }), 400

@app.route('/api/auth/verify-email-otp', methods=['POST'])
def verify_email_otp():
    data = request.json
    
    if not data.get('email') or not data.get('otp_code'):
        return jsonify({
            'success': False,
            'message': 'Email and OTP code are required'
        }), 400
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        # Find valid OTP for this email
        cursor.execute('''
            SELECT otp_code, expires_at, is_used FROM email_otps 
            WHERE email = ? AND otp_code = ? AND is_used = FALSE
            ORDER BY created_at DESC LIMIT 1
        ''', (data['email'], data['otp_code']))
        
        otp_record = cursor.fetchone()
        
        if not otp_record:
            conn.close()
            return jsonify({
                'success': False,
                'message': 'Invalid or expired OTP code'
            }), 400
        
        # Check if OTP is expired
        expires_at = datetime.fromisoformat(otp_record[1])
        if datetime.now() > expires_at:
            conn.close()
            return jsonify({
                'success': False,
                'message': 'OTP code has expired'
            }), 400
        
        # Mark OTP as used
        cursor.execute('''
            UPDATE email_otps SET is_used = TRUE 
            WHERE email = ? AND otp_code = ?
        ''', (data['email'], data['otp_code']))
        
        # Update user email_verified status
        cursor.execute('''
            UPDATE users SET email_verified = TRUE 
            WHERE email = ?
        ''', (data['email'],))
        
        conn.commit()
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'Email verified successfully. You can now log in.',
            'redirect_to_login': True
        })
        
    except Exception as e:
        print(f"❌ OTP verification error: {e}")
        conn.close()
        return jsonify({
            'success': False,
            'message': f'Verification failed: {str(e)}'
        }), 500

@app.route('/api/auth/resend-otp', methods=['POST'])
def resend_otp():
    data = request.json
    
    if not data.get('email'):
        return jsonify({
            'success': False,
            'message': 'Email is required'
        }), 400
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        # Check if user exists
        cursor.execute('SELECT id FROM users WHERE email = ?', (data['email'],))
        user = cursor.fetchone()
        
        if not user:
            conn.close()
            return jsonify({
                'success': False,
                'message': 'User not found'
            }), 404
        
        # Generate new OTP
        otp_code = generate_otp()
        expires_at = datetime.now() + timedelta(minutes=10)
        
        # Store new OTP
        cursor.execute('''
            INSERT INTO email_otps (email, otp_code, expires_at)
            VALUES (?, ?, ?)
        ''', (data['email'], otp_code, expires_at.isoformat()))
        
        conn.commit()
        conn.close()
        
        # Send OTP email
        email_sent = send_otp_email(data['email'], otp_code)
        
        return jsonify({
            'success': True,
            'message': 'New OTP code sent to your email',
            'email_sent': email_sent
        })
        
    except Exception as e:
        print(f"❌ Resend OTP error: {e}")
        conn.close()
        return jsonify({
            'success': False,
            'message': f'Failed to resend OTP: {str(e)}'
        }), 500

# Add sample data
@app.route('/api/setup-sample-data', methods=['POST'])
def setup_sample_data():
    conn = get_db()
    cursor = conn.cursor()
    
    # Add sample facilities
    facilities = [
        ('Community Hall', 'Spacious hall for events and meetings', 1000.0, '', 0.5, 100, 'Tables, chairs, sound system', '8:00 AM - 10:00 PM'),
        ('Basketball Court', 'Full-size basketball court with lighting', 500.0, '', 0.3, 50, 'Basketball hoops, lighting, scoreboard', '6:00 AM - 10:00 PM'),
        ('Swimming Pool', 'Olympic-size swimming pool with facilities', 1500.0, '', 0.4, 200, 'Showers, lockers, lifeguard on duty', '6:00 AM - 9:00 PM'),
        ('Shooting Range', 'Indoor shooting range with safety equipment', 2000.0, '', 0.5, 30, 'Safety gear, targets, instructor available', '8:00 AM - 6:00 PM')
    ]
    
    cursor.executemany('''
        INSERT OR IGNORE INTO facilities (name, description, hourly_rate, main_photo_url, downpayment_rate, max_capacity, amenities, operating_hours)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', facilities)
    
    # Add sample users
    import hashlib
    users = [
        ('resident@barangay.com', hashlib.sha256('password123'.encode()).hexdigest(), 'Juan Dela Cruz', 'resident'),
        ('official@barangay.com', hashlib.sha256('password123'.encode()).hexdigest(), 'Maria Santos', 'official')
    ]
    
    cursor.executemany('''
        INSERT OR IGNORE INTO users (email, password, full_name, role)
        VALUES (?, ?, ?, ?)
    ''', users)
    
    # Add time slots for each facility
    time_slots = []
    
    # Community Hall (Facility ID 1)
    for hour in range(8, 22):  # 8 AM to 9 PM
        start_time = f"{hour % 12 or 12}:00 {'AM' if hour < 12 else 'PM'}"
        end_time = f"{(hour + 1) % 12 or 12}:00 {'AM' if hour + 1 < 12 else 'PM'}"
        time_slots.append((1, start_time, end_time))
    
    # Basketball Court (Facility ID 2)
    for hour in range(6, 22):  # 6 AM to 9 PM
        start_time = f"{hour % 12 or 12}:00 {'AM' if hour < 12 else 'PM'}"
        end_time = f"{(hour + 1) % 12 or 12}:00 {'AM' if hour + 1 < 12 else 'PM'}"
        time_slots.append((2, start_time, end_time))
    
    # Swimming Pool (Facility ID 3)
    for hour in range(6, 21):  # 6 AM to 8 PM
        start_time = f"{hour % 12 or 12}:00 {'AM' if hour < 12 else 'PM'}"
        end_time = f"{(hour + 1) % 12 or 12}:00 {'AM' if hour + 1 < 12 else 'PM'}"
        time_slots.append((3, start_time, end_time))
    
    # Shooting Range (Facility ID 4)
    for hour in range(8, 18):  # 8 AM to 5 PM
        start_time = f"{hour % 12 or 12}:00 {'AM' if hour < 12 else 'PM'}"
        end_time = f"{(hour + 1) % 12 or 12}:00 {'AM' if hour + 1 < 12 else 'PM'}"
        time_slots.append((4, start_time, end_time))
    
    cursor.executemany('''
        INSERT OR IGNORE INTO time_slots (facility_id, start_time, end_time)
        VALUES (?, ?, ?)
    ''', time_slots)
    
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'message': 'Sample data added'})

# Facility Management endpoints
@app.route('/api/facilities', methods=['POST'])
def create_facility():
    try:
        data = request.get_json()
        
        # Validate required fields
        if not data.get('name') or not data.get('price'):
            return jsonify({'success': False, 'message': 'Name and hourly rate are required'})
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Insert new facility
        cursor.execute('''
            INSERT INTO facilities (name, description, hourly_rate, main_photo_url, active, amenities, downpayment_rate, max_capacity)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            data['name'],
            data.get('description', ''),
            float(data['price']),  # Map price to hourly_rate
            data.get('image_url', ''),  # Map image_url to main_photo_url
            data.get('active', True),
            data.get('amenities', ''),
            float(data.get('downpayment', 0)),  # Map downpayment to downpayment_rate
            int(data.get('capacity', 0))  # Map capacity to max_capacity
        ))
        
        facility_id = cursor.lastrowid
        print(f"🔍 Created facility {facility_id}: {data['name']}")
        
        # Generate default time slots for the new facility
        # Default operating hours: 8:00 AM to 9:00 PM (can be customized per facility type)
        operating_hours = data.get('operating_hours', '8:00 AM - 9:00 PM')
        
        # Parse operating hours or use defaults
        start_hour = 8  # Default 8 AM
        end_hour = 21   # Default 9 PM (last slot starts at 8 PM)
        
        # Adjust hours based on facility type if specified
        facility_name = data['name'].lower()
        if 'basketball' in facility_name or 'court' in facility_name:
            start_hour, end_hour = 6, 22  # 6 AM to 9 PM
        elif 'swimming' in facility_name or 'pool' in facility_name:
            start_hour, end_hour = 6, 21  # 6 AM to 8 PM
        elif 'shooting' in facility_name or 'range' in facility_name:
            start_hour, end_hour = 8, 18  # 8 AM to 5 PM
        
        print(f"🔍 Generating time slots for facility {facility_id}: {start_hour}:00 to {end_hour}:00")
        
        # Generate time slots (2-hour slots for better management)
        time_slots = []
        for i, hour in enumerate(range(start_hour, end_hour, 2)):  # Increment by 2 hours
            start_time = f"{hour % 12 or 12}:00 {'AM' if hour < 12 else 'PM'}"
            end_time = f"{(hour + 2) % 12 or 12}:00 {'AM' if hour + 2 < 12 else 'PM'}"
            duration_minutes = 120  # 2 hour slots
            sort_order = i + 1  # Chronological order
            time_slots.append((facility_id, start_time, end_time, duration_minutes, sort_order))
        
        # Insert time slots
        cursor.executemany('''
            INSERT INTO time_slots (facility_id, start_time, end_time, duration_minutes, sort_order)
            VALUES (?, ?, ?, ?, ?)
        ''', time_slots)
        
        print(f"🔍 Created {len(time_slots)} time slots for facility {facility_id}")
        
        conn.commit()
        conn.close()
        
        return jsonify({
            'success': True, 
            'message': 'Facility created successfully with time slots',
            'facility_id': facility_id,
            'time_slots_created': len(time_slots)
        })
        
    except Exception as e:
        print(f"❌ create_facility error: {e}")
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/facilities/<int:facility_id>/regenerate-timeslots', methods=['POST'])
def regenerate_facility_timeslots(facility_id):
    """Regenerate time slots for an existing facility"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get facility info
        cursor.execute('SELECT name FROM facilities WHERE id = ?', (facility_id,))
        facility = cursor.fetchone()
        
        if not facility:
            return jsonify({'success': False, 'message': 'Facility not found'}), 404
        
        facility_name = facility[0]
        print(f"🔍 Regenerating time slots for facility {facility_id}: {facility_name}")
        
        # Delete existing time slots for this facility
        cursor.execute('DELETE FROM time_slots WHERE facility_id = ?', (facility_id,))
        deleted_count = cursor.rowcount
        print(f"🔍 Deleted {deleted_count} existing time slots")
        
        # Determine operating hours based on facility type
        facility_name_lower = facility_name.lower()
        if 'basketball' in facility_name_lower or 'court' in facility_name_lower:
            start_hour, end_hour = 6, 22  # 6 AM to 9 PM
        elif 'swimming' in facility_name_lower or 'pool' in facility_name_lower:
            start_hour, end_hour = 6, 21  # 6 AM to 8 PM
        elif 'shooting' in facility_name_lower or 'range' in facility_name_lower:
            start_hour, end_hour = 8, 18  # 8 AM to 5 PM
        else:
            start_hour, end_hour = 6, 21  # Default 6 AM to 8 PM
        
        # Generate new time slots (2-hour slots for better management)
        time_slots = []
        for i, hour in enumerate(range(start_hour, end_hour, 2)):  # Increment by 2 hours
            start_time = f"{hour % 12 or 12}:00 {'AM' if hour < 12 else 'PM'}"
            end_time = f"{(hour + 2) % 12 or 12}:00 {'AM' if hour + 2 < 12 else 'PM'}"
            duration_minutes = 120  # 2 hour slots
            sort_order = i + 1  # Chronological order
            time_slots.append((facility_id, start_time, end_time, duration_minutes, sort_order))
        
        # Insert new time slots
        cursor.executemany('''
            INSERT INTO time_slots (facility_id, start_time, end_time, duration_minutes, sort_order)
            VALUES (?, ?, ?, ?, ?)
        ''', time_slots)
        
        print(f"🔍 Created {len(time_slots)} new time slots for facility {facility_id}")
        
        conn.commit()
        conn.close()
        
        return jsonify({
            'success': True,
            'message': f'Time slots regenerated for {facility_name}',
            'time_slots_created': len(time_slots),
            'deleted_slots': deleted_count
        })
        
    except Exception as e:
        print(f"❌ regenerate_timeslots error: {e}")
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/facilities/<int:facility_id>', methods=['PUT'])
def update_facility(facility_id):
    try:
        data = request.get_json()
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Update facility
        cursor.execute('''
            UPDATE facilities 
            SET name = ?, description = ?, hourly_rate = ?, main_photo_url = ?, active = ?, amenities = ?, downpayment_rate = ?, max_capacity = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
        ''', (
            data.get('name'),
            data.get('description', ''),
            float(data.get('price', 0)),  # Map price to hourly_rate
            data.get('image_url', ''),  # Map image_url to main_photo_url
            data.get('active', True),
            data.get('amenities', ''),
            float(data.get('downpayment', 0)),  # Map downpayment to downpayment_rate
            int(data.get('capacity', 0)),  # Map capacity to max_capacity
            facility_id
        ))
        
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'message': 'Facility updated successfully'})
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/facilities/<int:facility_id>', methods=['DELETE'])
def delete_facility(facility_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Delete facility
        cursor.execute('DELETE FROM facilities WHERE id = ?', (facility_id,))
        
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'message': 'Facility deleted successfully'})
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

# User Profile Management
@app.route('/api/users/<int:user_id>', methods=['GET'])
def get_user_by_id(user_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
        user = cursor.fetchone()
        
        if user:
            return jsonify({
                'success': True,
                'user': {
                    'id': user[0],
                    'email': user[1],
                    'password': user[2],
                    'full_name': user[3],
                    'role': user[4],
                    'created_at': user[5],
                    'contact_number': user[6],
                    'verified': user[7],
                    'discount_rate': user[8],
                    'address': user[9],
                    'profile_photo_url': user[10],
                    'is_authenticated': True
                }
            })
        else:
            return jsonify({'success': False, 'message': 'User not found'}), 404
            
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500
    finally:
        conn.close()

@app.route('/api/users/profile', methods=['PUT'])
def update_user_profile():
    try:
        data = request.get_json()
        print(f"🔍 DEBUG: Profile update request data: {data}")
        
        if not data:
            return jsonify({'success': False, 'message': 'No data provided'}), 400
        
        if 'email' not in data:
            return jsonify({'success': False, 'message': 'Email is required'}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Build dynamic update query to only update provided fields
        update_fields = []
        update_values = []
        
        if 'full_name' in data and data['full_name'] is not None:
            update_fields.append('full_name = ?')
            update_values.append(data['full_name'])
        
        if 'contact_number' in data and data['contact_number'] is not None:
            update_fields.append('contact_number = ?')
            update_values.append(data['contact_number'])
        
        if 'address' in data and data['address'] is not None:
            update_fields.append('address = ?')
            update_values.append(data['address'])
        
        # Always add updated_at timestamp
        update_fields.append('updated_at = CURRENT_TIMESTAMP')
        
        if update_fields:
            # Add email as the last parameter for WHERE clause
            update_values.append(data['email'])
            
            cursor.execute(f'''
                UPDATE users 
                SET {', '.join(update_fields)}
                WHERE email = ?
            ''', update_values)
            
            print(f"✅ Updated profile for user: {data['email']}")
            print(f"🔍 Updated fields: {', '.join([field.split(' = ')[0] for field in update_fields[:-1]])}")
        else:
            print(f"🔍 No basic fields to update for user: {data['email']}")
        
        # Update profile photo if provided
        if 'profile_photo_url' in data and data['profile_photo_url']:
            print(f"🔍 Updating profile photo for user: {data['email']}")
            cursor.execute('''
                UPDATE users 
                SET profile_photo_url = ?
                WHERE email = ?
            ''', (data['profile_photo_url'], data['email']))
            print(f"✅ Updated profile photo for user: {data['email']}")
        else:
            print(f"🔍 No profile photo provided for user: {data['email']}")
        
        conn.commit()
        conn.close()
        
        # Add auto-refresh metadata for frontend
        refresh_data = {
            'trigger': 'profile_updated',
            'user_email': data['email'],
            'timestamp': datetime.now().isoformat(),
            'updated_fields': [],  # Track which fields were updated
            'requires_refresh': [
                'user_profile',            # Refresh user profile data
                'profile_photo',           # Refresh profile photo display
                'account_settings',        # Refresh account settings
                'resident_dashboard',      # Refresh resident dashboard
                'official_profile'         # Refresh official profile
            ]
        }
        
        # Track which fields were updated for targeted refresh
        if 'full_name' in data and data['full_name'] is not None:
            refresh_data['updated_fields'].append('full_name')
        if 'contact_number' in data and data['contact_number'] is not None:
            refresh_data['updated_fields'].append('contact_number')
        if 'address' in data and data['address'] is not None:
            refresh_data['updated_fields'].append('address')
        if 'profile_photo_url' in data and data['profile_photo_url']:
            refresh_data['updated_fields'].append('profile_photo_url')
            refresh_data['requires_refresh'].append('profile_photo_display')
        
        print(f"✅ Updated profile for user: {data['email']}")
        print(f"🔍 Updated fields: {', '.join(refresh_data['updated_fields'])}")
        
        return jsonify({
            'success': True, 
            'message': 'Profile updated successfully',
            'refresh_data': refresh_data  # Auto-refresh instructions
        })
    except KeyError as e:
        print(f"❌ KeyError in profile update: {e}")
        return jsonify({'success': False, 'message': f'Missing required field: {str(e)}'}), 400
    except Exception as e:
        print(f"❌ Exception in profile update: {e}")
        print(f"❌ Exception type: {type(e).__name__}")
        return jsonify({'success': False, 'message': f'Error updating profile: {str(e)}'}), 500

@app.route('/api/users/profile/<email>', methods=['GET'])
def get_user_profile(email):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Use the same query as Gmail auth for consistency
        cursor.execute('SELECT * FROM users WHERE email = ?', (email,))
        
        user = cursor.fetchone()
        conn.close()
        
        if user:
            return jsonify({
                'success': True,
                'user': {
                    'id': user[0],
                    'email': user[1],
                    'full_name': user[3],  # Fixed: full_name is at index 3
                    'role': user[4],        # Fixed: role is at index 4
                    'verified': bool(user[5]),  # Fixed: verified is at index 5, convert to bool
                    'verification_type': user[6],  # Fixed: verification_type is at index 6
                    'discount_rate': user[7],    # Fixed: discount_rate is at index 7
                    'contact_number': user[8],    # Fixed: contact_number is at index 8
                    'address': user[9],          # Fixed: address is at index 9
                    'profile_photo_url': user[10],  # Fixed: profile_photo_url is at index 10
                    'is_active': bool(user[12]),  # Fixed: is_active is at index 12
                    'email_verified': bool(user[13]),  # Fixed: email_verified is at index 13
                    'last_login': user[14],       # Fixed: last_login is at index 14
                    'created_at': user[15],       # Fixed: created_at is at index 15
                    'updated_at': user[16],       # Fixed: updated_at is at index 16
                    'fake_booking_violations': user[18] if len(user) > 18 else 0,  # Fixed: index 18
                    'is_banned': bool(user[19]) if len(user) > 19 else False,      # Fixed: index 19
                    'banned_at': user[20] if len(user) > 20 else None,              # Fixed: index 20
                    'ban_reason': user[21] if len(user) > 21 else None             # Fixed: index 21
                }
            })
        else:
            return jsonify({'success': False, 'message': 'User not found'}), 404
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# Get officials for customer service
@app.route('/api/officials', methods=['GET'])
def get_officials():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT id, full_name, contact_number, role, email
            FROM users 
            WHERE role = 'official' AND full_name IS NOT NULL AND full_name != ''
            ORDER BY role, full_name
        ''')
        
        officials = cursor.fetchall()
        conn.close()
        
        officials_list = []
        for official in officials:
            # Convert personal names to positions based on email for consistency
            # But preserve custom names that don't match default patterns
            display_name = official[1]  # full_name
            email_lower = official[4].lower()
            original_name = official[1]  # Keep original for comparison
            
            # Only convert to position titles if it's a default name pattern
            is_default_name = (
                'punong barangay' in original_name.lower() or
                'barangay captain' in original_name.lower() or
                'barangay secretary' in original_name.lower() or
                'barangay administrator' in original_name.lower() or
                'barangay councilor' in original_name.lower() or
                'barangay planning officer' in original_name.lower() or
                'barangay utility worker' in original_name.lower()
            )
            
            # Check email for position mapping (more reliable than name checking)
            if 'captain@barangay.gov' in email_lower and is_default_name:
                display_name = 'Barangay Captain'
            elif 'secretary@barangay.gov' in email_lower and is_default_name:
                display_name = 'Barangay Secretary'
            elif 'administrator@barangay.gov' in email_lower and is_default_name:
                display_name = 'Barangay Administrator'
            elif 'kagawad1@barangay.gov' in email_lower and is_default_name:
                display_name = 'Barangay Councilor'
            elif 'planning@barangay.gov' in email_lower and is_default_name:
                display_name = 'Barangay Planning Officer'
            elif 'utility@barangay.gov' in email_lower and is_default_name:
                display_name = 'Barangay Utility Worker'
            # If it's not a default name, keep the custom name
            elif not is_default_name:
                display_name = original_name
            
            officials_list.append({
                'id': official[0],
                'full_name': display_name,
                'contact_number': official[2],
                'role': official[3],
                'email': official[4]
            })
        
        # Remove duplicates based on position, preferring .gov emails and then contact numbers
        seen_positions = {}
        unique_officials = []
        for official in officials_list:
            position = official['full_name']
            current_contact = official['contact_number']
            current_email = official['email']
            
            # If we haven't seen this position yet
            if position not in seen_positions:
                seen_positions[position] = official
            else:
                existing = seen_positions[position]
                existing_email = existing['email']
                existing_contact = existing['contact_number']
                
                # Prefer .gov emails over .com emails
                if '.gov' in current_email and '.com' in existing_email:
                    seen_positions[position] = official
                # If both have same email domain, prefer one with contact number
                elif (current_contact is not None and current_contact != '' and 
                      (existing_contact is None or existing_contact == '')):
                    seen_positions[position] = official
        
        # Convert back to list
        unique_officials = list(seen_positions.values())
        
        return jsonify({
            'success': True,
            'data': unique_officials
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/users/status/<string:email>', methods=['GET'])
def get_user_status(email):
    """Get user status including ban information"""
    try:
        conn = get_db()
        cursor = conn.cursor()
        
        cursor.execute('SELECT id, email, is_banned, ban_reason FROM users WHERE email = ?', (email,))
        user_result = cursor.fetchone()
        
        if not user_result:
            return jsonify({'success': False, 'message': 'User not found'}), 404
        
        user_id, user_email, is_banned, ban_reason = user_result
        
        return jsonify({
            'success': True,
            'id': user_id,
            'email': user_email,
            'is_banned': bool(is_banned),
            'ban_reason': ban_reason
        })
        
    except Exception as e:
        print(f"❌ Error getting user status: {e}")
        return jsonify({'success': False, 'message': str(e)}), 500
    finally:
        if 'conn' in locals():
            conn.close()

# Verification Status Check - New endpoint for form locking
@app.route('/api/verification-requests/status/<int:user_id>', methods=['GET'])
def get_verification_status(user_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get user data with correct field names
        cursor.execute('''
            SELECT id, verified, verification_type, email 
            FROM users WHERE id = ?
        ''', (user_id,))
        user = cursor.fetchone()
        
        if not user:
            conn.close()
            return jsonify({'success': False, 'message': 'User not found'}), 404
        
        # Check pending requests with correct field names
        cursor.execute('''
            SELECT COUNT(*) as pending_count 
            FROM verification_requests 
            WHERE user_id = ? AND status = 'pending'
        ''', (user_id,))
        pending_result = cursor.fetchone()
        has_pending = pending_result['pending_count'] > 0
        
        # Determine if can submit using correct field mapping
        can_submit = True
        lock_message = ""
        current_status = "none"
        
        # FIRST PRIORITY: Check if user has pending request - LOCKS EVERYONE
        if has_pending:
            can_submit = False  
            lock_message = "You already submitted a Verification Request! wait for officials to either Reject or Approve your request"
            current_status = "pending_request"
        elif user['verified'] == 1 and user['verification_type'] == 'resident':  # Verified resident
            can_submit = False
            lock_message = "You are already verified as a Resident with full benefits"
            current_status = "verified_resident"
        elif user['verified'] == 1 and user['verification_type'] == 'non-resident':  # Verified non-resident
            can_submit = True  # ALLOWED: Can submit to upgrade to resident status
            lock_message = "You can submit a verification request to upgrade to Resident status"
            current_status = "verified_non_resident"
        else:  # Unverified resident (verified: 0 or 2)
            can_submit = True
            if user['verified'] == 2:
                lock_message = "You can submit an upgrade request to Resident status"
                current_status = "verified_non_resident"
            else:
                lock_message = "You can submit a verification request"
                current_status = "unverified"
        
        conn.close()
        
        # Return with correct field mapping
        return jsonify({
            'success': True,
            'can_submit': can_submit,
            'lock_message': lock_message,
            'current_status': current_status,
            'verified': user['verified'],
            'verification_type': user['verification_type'],  # CRITICAL: Return actual verification_type
            'user_id': user['id'],
            'email': user['email']
        })
        
    except Exception as e:
        print(f"❌ Error checking verification status: {e}")
        return jsonify({'success': False, 'message': str(e)}), 500

# Verification Requests
@app.route('/api/verification-requests', methods=['GET', 'POST'])
def verification_requests():
    if request.method == 'GET':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Get all verification requests (not just pending) for filtering
            cursor.execute('''
                SELECT vr.id, vr.user_id, vr.verification_type, vr.requested_discount_rate, 
                       vr.user_photo_base64, vr.valid_id_base64, vr.status, 
                       vr.residential_address, vr.created_at, vr.updated_at, u.email, u.full_name, u.contact_number
                FROM verification_requests vr
                LEFT JOIN users u ON vr.user_id = u.id
                ORDER BY vr.created_at DESC
            ''')
            
            requests = cursor.fetchall()
            conn.close()
            
            requests_list = []
            for req in requests:
                requests_list.append({
                    'id': req[0],
                    'residentId': req[1],  # user_id from database - frontend expects this
                    'verificationType': req[2],
                    'discountRate': req[3],
                    'userPhotoUrl': req[4],  # user_photo_base64 - frontend expects this
                    'validIdUrl': req[5],    # valid_id_base64 - frontend expects this
                    'status': req[6],
                    'address': req[7],      # residential_address - frontend expects this
                    'submittedAt': req[8],  # created_at - frontend expects this
                    'updatedAt': req[9],     # updated_at
                    'email': req[10],
                    'fullName': req[11],    # from users table
                    'contactNumber': req[12] # from users table
                })
            
            return jsonify({
                'success': True,
                'data': requests_list
            })
            
        except Exception as e:
            print(f"❌ Error fetching verification requests: {e}")
            # Ensure database connection is closed on error
            if 'conn' in locals():
                try:
                    conn.close()
                except:
                    pass
            return jsonify({'success': False, 'message': str(e)}), 500
    
    elif request.method == 'POST':
        conn = None
        try:
            data = request.get_json()
            print(f"🔍 Received verification request data: {data}")
            
            # Validate required fields
            if not data.get('residentId') or not data.get('verificationType'):
                print("❌ Validation failed: Missing residentId or verificationType")
                return jsonify({'success': False, 'message': 'User ID and verification type are required'})
            
            print(f"🔍 DEBUG: About to connect to database...")
            conn = get_db_connection()
            cursor = conn.cursor()
            print(f"🔍 DEBUG: Database connection established")
            
            # 🔒 VERIFICATION STATUS VALIDATION: Check if user can submit new request
            print(f"🔍 DEBUG: About to check user verification status...")
            cursor.execute('SELECT verified FROM users WHERE id = ?', (data.get('residentId'),))
            user_verification = cursor.fetchone()
            print(f"🔍 DEBUG: User verification query completed")
            
            if not user_verification:
                return jsonify({'success': False, 'message': 'User not found'}), 404
            
            # Check for existing pending requests
            print(f"🔍 DEBUG: About to check pending requests...")
            cursor.execute('''
                SELECT COUNT(*) as pending_count 
                FROM verification_requests 
                WHERE user_id = ? AND status = 'pending'
            ''', (data.get('residentId'),))
            pending_result = cursor.fetchone()
            has_pending = pending_result['pending_count'] > 0
            print(f"🔍 DEBUG: Pending requests check completed")
            
            # Validate submission permission
            if user_verification[0] == 1:  # Already verified resident
                return jsonify({
                    'success': False, 
                    'message': 'You are already verified as a Resident with full benefits'
                }), 400
            
            if has_pending:
                return jsonify({
                    'success': False,
                    'message': 'You already submitted a Verification Request! wait for officials to either Reject or Approve your request'
                }), 400
            
            # User can submit (unverified or non-resident wanting upgrade)
            print(f"✅ User {data.get('residentId')} can submit verification request (verified: {user_verification[0]}, has_pending: {has_pending})")
            
            # 🔒 BAN VALIDATION: Check if user is banned before allowing verification request
            print(f"🔍 DEBUG: About to check user ban status...")
            cursor.execute('SELECT email, is_banned, ban_reason FROM users WHERE id = ?', (data.get('residentId'),))
            user_result = cursor.fetchone()
            print(f"🔍 DEBUG: User ban status check completed")
            
            if not user_result:
                return jsonify({'success': False, 'message': 'User not found'}), 404
            
            user_email = user_result[0]
            is_banned = user_result[1]
            ban_reason = user_result[2]
            
            if is_banned:
                print(f"🚨 BANNED USER ATTEMPTED VERIFICATION REQUEST: {user_email} - Reason: {ban_reason}")
                return jsonify({
                    'success': False, 
                    'message': 'Account is banned. Cannot submit verification requests.',
                    'error_type': 'user_banned',
                    'ban_reason': ban_reason or 'Account has been banned by administrator.'
                }), 403
            
            print(f"🔍 DEBUG: Verification request for user: {user_email}, banned: {is_banned}")
            
            # Insert new verification request
            cursor.execute('''
                INSERT INTO verification_requests 
                (request_reference, user_id, verification_type, requested_discount_rate, user_photo_base64, valid_id_base64, 
                 residential_address, status, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                f"VR-{data.get('residentId')}-{datetime.now().strftime('%Y%m%d%H%M%S')}",  # Generate unique request reference
                data.get('residentId'),  # frontend sends residentId, map to user_id
                data.get('verificationType', ''),
                0.1 if data.get('verificationType') == 'resident' else 0.05,  # Set discount rate based on type
                data.get('userPhotoUrl', ''),  # frontend sends userPhotoUrl, map to user_photo_base64
                data.get('validIdUrl', ''),    # frontend sends validIdUrl, map to valid_id_base64
                data.get('address', ''),       # frontend sends address, map to residential_address
                data.get('status', 'pending'),
                data.get('submittedAt')        # frontend sends submittedAt, map to created_at
            ))
            
            # Also update user's contact number if provided
            if data.get('contactNumber'):
                cursor.execute('''
                    UPDATE users 
                    SET contact_number = ?
                    WHERE id = ?
                ''', (data.get('contactNumber'), data.get('residentId')))
            
            conn.commit()
            conn.close()
            
            # Send email notification to officials about the authentication request
            try:
                # Prepare resident details for email
                resident_details = {
                    'full_name': data.get('fullName', ''),
                    'email': user_email,
                    'contact_number': data.get('contactNumber', ''),
                    'verification_status': 'Pending Verification'
                }
                
                # Prepare request details for email
                request_details = {
                    'submitted_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                    'reference_number': f"VR-{data.get('residentId')}-{datetime.now().strftime('%Y%m%d%H%M%S')}",
                    'verification_type': data.get('verificationType', ''),
                    'discount_rate': '10%' if data.get('verificationType') == 'resident' else '5%',
                    'address': data.get('address', '')
                }
                
                # Send notification email to officials
                notification_sent = email_service.send_official_notification_email(
                    request_type="authentication",
                    resident_details=resident_details,
                    request_details=request_details
                )
                
                if notification_sent:
                    print(f"📧 Authentication request notification sent to officials")
                else:
                    print(f"❌ Failed to send authentication request notification")
                    
            except Exception as email_error:
                print(f"❌ Error sending authentication request notification: {email_error}")
            
            print("✅ Verification request created successfully")
            return jsonify({'success': True, 'message': 'Verification request submitted successfully'})
            
        except Exception as e:
            print(f"❌ Error creating verification request: {e}")
            # Ensure database connection is closed on error
            if conn:
                try:
                    conn.close()
                except:
                    pass
            return jsonify({'success': False, 'message': str(e)})

@app.route('/api/verification-requests/<int:request_id>', methods=['PUT'])
def update_verification_request(request_id):
    try:
        data = request.get_json()
        print(f"🔍 Received verification update data: {data}")
        
        if not data.get('status'):
            return jsonify({'success': False, 'message': 'Status is required'})
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Update verification request
        cursor.execute('''
            UPDATE verification_requests 
            SET status = ?, updated_at = ?
            WHERE id = ?
        ''', (
            data.get('status'),
            data.get('updatedAt', datetime.now().isoformat()),
            request_id
        ))
        
        # Also update the user's verification status and discount rate
        if data.get('status') in ['approved', 'rejected']:
            # Get verification request details to determine verification type and photos
            cursor.execute('''
                SELECT verification_type, user_photo_base64 FROM verification_requests WHERE id = ?
            ''', (request_id,))
            verification_request = cursor.fetchone()
            verification_type = verification_request[0] if verification_request else 'resident'
            user_photo_base64 = verification_request[1] if len(verification_request) > 1 else None
            
            # Use provided discount rate or determine from verification type
            if data.get('discountRate') is not None:
                discount_rate = float(data.get('discountRate'))
            else:
                discount_rate = 0.1 if verification_type == 'resident' else 0.05
            
            # Set verified status based on approval and verification type
            if data.get('status') == 'approved':
                # For residents: verified = 1, For non-residents: verified = 2
                is_verified = 1 if verification_type == 'resident' else 2
            elif data.get('status') == 'rejected':
                # 🎯 CRITICAL FIX: Preserve Non-Resident status when upgrade request is rejected
                # Get current user verification status before making changes
                cursor.execute('''
                    SELECT verified FROM users 
                    WHERE id = (SELECT user_id FROM verification_requests WHERE id = ?)
                ''', (request_id,))
                current_verified = cursor.fetchone()[0]
                
                # If user is currently verified as Non-Resident (verified = 2), keep that status
                # Only set to unverified (0) if they were truly unverified
                if current_verified == 2:  # Non-Resident
                    is_verified = 2  # Keep Non-Resident status
                    discount_rate = 0.05  # Keep Non-Resident discount
                    print(f"🎯 Preserving Non-Resident status for user after rejection")
                else:
                    is_verified = 0  # Only unverified users become unverified
                    discount_rate = 0.0
                    print(f"🔄 Setting user to unverified after rejection")
            else:
                is_verified = 0  # rejected (fallback)
                discount_rate = 0.0
            
            # Update user verification and discount
            cursor.execute('''
                UPDATE users 
                SET verified = ?, discount_rate = ?, verification_type = ?, updated_at = ?
                WHERE id = (SELECT user_id FROM verification_requests WHERE id = ?)
            ''', (is_verified, discount_rate, verification_type, datetime.now(), request_id))
            
            # Update user profile photo if approved and photo provided
            if data.get('status') == 'approved' and (data.get('profilePhotoUrl') or user_photo_base64):
                profile_photo = data.get('profilePhotoUrl') or user_photo_base64
                cursor.execute('''
                    UPDATE users 
                    SET profile_photo_url = ?
                    WHERE id = (SELECT user_id FROM verification_requests WHERE id = ?)
                ''', (profile_photo, request_id))
                print(f"✅ Updated profile photo for user with verification request ID: {request_id}")
            
            # 📧 Send email notifications for verification status updates
            try:
                # Get user details for email
                cursor.execute('''
                    SELECT u.email, u.full_name
                    FROM users u
                    WHERE u.id = (SELECT user_id FROM verification_requests WHERE id = ?)
                ''', (request_id,))
                
                user_details = cursor.fetchone()
                if user_details:
                    user_email, user_name = user_details
                    
                    if data.get('status') == 'approved':
                        # Send approval email
                        email_service.send_verification_approval_email(
                            recipient_email=user_email,
                            recipient_name=user_name,
                            verification_type=verification_type,
                            discount_rate=discount_rate
                        )
                        print(f"📧 Verification approval email sent to {user_email}")
                        
                    elif data.get('status') == 'rejected':
                        # Send rejection email
                        rejection_reason = data.get('rejectionReason', 'Verification request did not meet requirements')
                        email_service.send_verification_rejection_email(
                            recipient_email=user_email,
                            recipient_name=user_name,
                            verification_type=verification_type,
                            rejection_reason=rejection_reason
                        )
                        print(f"📧 Verification rejection email sent to {user_email}")
                        
            except Exception as email_error:
                print(f"❌ Error sending verification email notification: {email_error}")
                # Don't fail the verification update if email fails
        
        conn.commit()
        conn.close()
        
        print(f"✅ Verification request {request_id} updated successfully")
        
        # Add auto-refresh metadata for frontend
        refresh_data = {
            'trigger': 'verification_status_updated',
            'request_id': request_id,
            'status': data.get('status'),
            'timestamp': datetime.now().isoformat(),
            'requires_refresh': [
                'verification_requests',    # Refresh verification requests list
                'user_profile',            # Refresh user profile data
                'verification_status',      # Refresh verification status
                'account_settings'         # Refresh account settings
            ]
        }
        
        # If approved, add additional refresh requirements
        if data.get('status') == 'approved':
            refresh_data['requires_refresh'].addAll([
                'user_discount_rate',      # Refresh discount rates
                'profile_photo',           # Refresh profile photos
                'resident_dashboard'       # Refresh dashboard
            ])
        
        return jsonify({
            'success': True, 
            'message': 'Verification request updated successfully',
            'refresh_data': refresh_data  # Auto-refresh instructions
        })
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/auth/google-login', methods=['POST'])
def google_login():
    try:
        data = request.get_json()
        id_token = data.get('idToken')
        email = data.get('email')
        
        if not id_token or not email:
            return jsonify({
                'success': False,
                'message': 'Missing idToken or email'
            }), 400
        
        # Verify Google ID token
        google_response = requests.get(
            f'https://oauth2.googleapis.com/tokeninfo?id_token={id_token}'
        )
        
        if google_response.status_code != 200:
            return jsonify({
                'success': False,
                'message': 'Invalid Google token'
            }), 401
        
        token_data = google_response.json()
        
        # Verify the email matches
        if token_data.get('email') != email:
            return jsonify({
                'success': False,
                'message': 'Email mismatch'
            }), 401
        
        # Check if user exists in database
        conn = sqlite3.connect(Config.DATABASE_PATH)
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM users WHERE email = ?', (email,))
        user = cursor.fetchone()
        
        if user:
            # Existing user - return user data with correct column mapping
            user_data = {
                'id': user[0],
                'email': user[1],
                'full_name': user[3],  # full_name is at index 3
                'role': user[4],        # role is at index 4
                'verified': bool(user[5]),  # verified is at index 5
                'verification_type': user[6],  # verification_type is at index 6
                'discount_rate': user[7],    # discount_rate is at index 7
                'contact_number': user[8],    # contact_number is at index 8
                'address': user[9],          # address is at index 9
                'created_at': user[15]       # created_at is at index 15
            }
            
            # Check if user has complete profile (configured vs unconfigured)
            has_complete_profile = (
                user_data['contact_number'] and 
                user_data['contact_number'].strip() != '' and
                user_data['address'] and 
                user_data['address'].strip() != ''
            )
            
            # Generate JWT token for session
            token_payload = {
                'user_id': user[0],
                'email': email,
                'exp': datetime.now(timezone.utc) + timedelta(days=7)
            }
            
            jwt_token = jwt.encode(token_payload, 'barangay-reserve-secret-key-32-chars-long', algorithm='HS256')
            
            conn.close()
            
            return jsonify({
                'success': True,
                'user': user_data,
                'token': jwt_token,
                'message': 'Login successful',
                'is_existing_user': True,
                'has_complete_profile': has_complete_profile  # New flag for profile completeness
            })
        else:
            # User doesn't exist - return error for login attempt
            conn.close()
            return jsonify({
                'success': False,
                'message': 'Email not registered. Please register first.',
                'is_existing_user': False
            }), 404
            
    except Exception as e:
        print(f"❌ Google login error: {e}")
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/auth/google-register', methods=['POST'])
def google_register():
    try:
        data = request.get_json()
        id_token = data.get('idToken')
        email = data.get('email')
        
        if not id_token or not email:
            return jsonify({
                'success': False,
                'message': 'Missing idToken or email'
            }), 400
        
        # Verify Google ID token
        google_response = requests.get(
            f'https://oauth2.googleapis.com/tokeninfo?id_token={id_token}'
        )
        
        if google_response.status_code != 200:
            return jsonify({
                'success': False,
                'message': 'Invalid Google token or email may not be correctly spelled'
            }), 401
        
        token_data = google_response.json()
        
        # Verify the email matches
        if token_data.get('email') != email:
            return jsonify({
                'success': False,
                'message': 'Email mismatch'
            }), 401
        
        # Check if user already exists in database
        conn = sqlite3.connect(Config.DATABASE_PATH)
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM users WHERE email = ?', (email,))
        user = cursor.fetchone()
        
        if user:
            # User already exists - cannot register
            conn.close()
            return jsonify({
                'success': False,
                'message': 'Account already exists. Please login instead.',
                'is_existing_user': True
            }), 409  # Conflict status
        
        # New user - create account as UNVERIFIED resident
        cursor.execute('''
            INSERT INTO users (email, password, full_name, role, verified, verification_type, discount_rate, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            email,
            'gmail-auth-no-password',  # placeholder password
            token_data.get('name', ''),
            'resident',
            False,  # Gmail auth = NOT automatically verified - must go through verification process
            'unverified',  # New Gmail users start as unverified
            0.0,  # No discount until verified
            datetime.utcnow()
        ))
        
        user_id = cursor.lastrowid
        
        # Get the created user
        cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
        new_user = cursor.fetchone()
        
        user_data = {
            'id': new_user[0],
            'email': new_user[1],
            'full_name': new_user[3],  # full_name is at index 3
            'role': new_user[4],        # role is at index 4
            'verified': bool(new_user[5]),  # verified is at index 5
            'verification_type': new_user[6],  # verification_type is at index 6
            'discount_rate': new_user[7],    # discount_rate is at index 7
            'contact_number': new_user[8],    # contact_number is at index 8
            'address': new_user[9],          # address is at index 9
            'created_at': new_user[15]       # created_at is at index 15
        }
        
        # Generate JWT token for session
        token_payload = {
            'user_id': user_id,
            'email': email,
            'exp': datetime.now(timezone.utc) + timedelta(days=7)
        }
        
        jwt_token = jwt.encode(token_payload, 'barangay-reserve-secret-key-32-chars-long', algorithm='HS256')
        
        conn.commit()
        conn.close()
        
        return jsonify({
            'success': True,
            'user': user_data,
            'token': jwt_token,
            'message': 'Registration successful',
            'is_existing_user': False
        })
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/')
def serve_homepage():
    return send_from_directory('.', 'index.html')

@app.route('/index.html')
def serve_index():
    return send_from_directory('.', 'index.html')

@app.route('/privacy.html')
def serve_privacy():
    return send_from_directory('.', 'privacy.html')

@app.route('/google86d0cfd16d914651.html')
def serve_google_verification():
    return send_from_directory('.', 'google86d0cfd16d914651.html')

@app.route('/terms.html')
def serve_terms():
    return send_from_directory('.', 'terms.html')

if __name__ == '__main__':
    print("🚀 Starting Barangay Reserve Server...")
    print(f"📱 Server will be available at: http://localhost:{Config.PORT}")
    print("🌐 API endpoints:")
    print("   GET    /api/facilities")
    print("   POST   /api/facilities")
    print("   PUT    /api/facilities/<id>")
    print("   DELETE /api/facilities/<id>")
    print("   GET    /api/bookings")
    print("   POST   /api/bookings")
    print("   GET    /api/verification-requests")
    print("   POST   /api/verification-requests")
    print("   GET    /api/verification-requests/status/<user_id>")
    print("   PUT    /api/verification-requests/<id>")
    print("   POST   /api/login")
    print("   POST   /api/register")
    print("   POST   /api/auth/google-login")
    print("   PUT    /api/users/profile")
    print("   GET    /api/users/profile/<email>")
    print("   POST   /api/setup-sample-data")
    
    app.run(host=Config.HOST, port=Config.PORT, debug=Config.DEBUG)
