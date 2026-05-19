# 📧 Email Notification System Setup Guide

## Overview
The Barangay Reserve System now includes automatic email notifications for all booking and verification status changes.

## 🔄 Email Triggers

### Booking Status Changes:
- ✅ **Booking Approval** - Sent when booking is approved
- 🚫 **Booking Rejection** - Sent when booking is rejected (any type)
- 🔄 **Auto-Rejection** - Sent when official booking auto-rejects resident bookings

### Verification Status Changes:
- ✅ **Verification Approval** - Sent when verification request is approved
- 🚫 **Verification Rejection** - Sent when verification request is rejected

## ⚙️ Setup Instructions

### 1. Configure Gmail App Password

1. **Enable 2-Step Verification** on your Gmail account
2. **Generate App Password**:
   - Go to: Google Account → Security → 2-Step Verification → App Passwords
   - Select: Mail → Custom name (e.g., "Barangay System")
   - Copy the generated 16-character password

### 2. Update Email Configuration

Edit `server/email_config.py`:

```python
# Gmail SMTP Configuration
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587

# Sender Email (your barangay email)
SENDER_EMAIL = "yourbarangay@gmail.com"

# App Password (from step 1)
APP_PASSWORD = "xxxx-xxxx-xxxx-xxxx"

# Email Settings
EMAIL_ENABLED = True   # Set to False to disable emails
DEBUG_EMAIL = True     # Set to False to send actual emails
```

### 3. Testing

1. **Debug Mode** (Default):
   - Set `DEBUG_EMAIL = True`
   - Emails will be printed to console instead of sent
   - Safe for testing without sending real emails

2. **Live Mode**:
   - Set `DEBUG_EMAIL = False`
   - Set `EMAIL_ENABLED = True`
   - Emails will be actually sent

## 📨 Email Templates

### Booking Rejection Email Includes:
- 📋 Booking details (facility, date, time, reference)
- 🚫 Rejection reason and type
- ⚠️ Violation warning (for fake receipt rejections)
- 📞 Contact information

### Booking Approval Email Includes:
- 🎉 Confirmation message
- 📋 Booking details with status
- ✅ Check-in instructions
- 📞 Contact information

### Verification Approval Email Includes:
- 🎉 Congratulations message
- 📋 Verification status and type
- 💰 Discount rate information
- 📅 Effective date

### Verification Rejection Email Includes:
- 🚫 Rejection reason
- 📋 Next steps for resubmission
- 📞 Contact information

## 🔧 Advanced Configuration

### Custom Email Templates:
Edit `server/email_service.py` to customize:
- Email styling and colors
- Message content
- Additional information fields

### Alternative SMTP Providers:
Update `server/email_config.py` for other providers:

```python
# Outlook/Hotmail
SMTP_SERVER = "smtp-mail.outlook.com"
SMTP_PORT = 587

# Yahoo
SMTP_SERVER = "smtp.mail.yahoo.com"
SMTP_PORT = 587
```

## 🚨 Error Handling

- **Email failures won't break** the booking/verification process
- **Errors are logged** to console with detailed information
- **Graceful fallback** - system continues to work even if email fails

## 📊 Logging

Email operations are logged with these prefixes:
- `📧` - Email operations
- `✅` - Successful email sent
- `❌` - Email errors
- `📧 DEBUG EMAIL` - Debug mode output

## 🔒 Security Notes

- **Never commit** actual email credentials to version control
- **Use environment variables** for production deployment
- **App passwords** are more secure than regular passwords
- **Enable 2-Step Verification** on email accounts

## 📱 Mobile Compatibility

All email templates are:
- ✅ Mobile-responsive
- ✅ HTML formatted with inline CSS
- ✅ Compatible with major email clients
- ✅ Accessible design with semantic HTML

## 🎯 Usage Examples

### Manual Email Sending:
```python
from email_service import email_service

# Send booking rejection
email_service.send_booking_rejection_email(
    recipient_email="user@example.com",
    recipient_name="John Doe",
    booking_details={
        'facility_name': 'Community Hall',
        'booking_date': '2024-03-15',
        'timeslot': 'ALL DAY',
        'booking_reference': 'BR20240315001'
    },
    rejection_reason="Facility maintenance scheduled",
    rejection_type="maintenance"
)
```

## 🔄 Integration Status

✅ **Fully Integrated**:
- Booking status updates (`/api/bookings/<id>/status`)
- Verification request updates (`/api/verification-requests/<id>`)
- Auto-rejection scenarios
- Error handling and logging

## 📞 Support

For email issues:
1. Check console logs for error messages
2. Verify SMTP credentials
3. Test with `DEBUG_EMAIL = True` first
4. Ensure app password is correctly generated

---

**The email notification system is now ready for use!** 🎉
