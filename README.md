# Barangay Reserve

A mobile-based facility reservation and management system for barangay operations in the Philippines.

## Overview

Barangay Reserve is a comprehensive facility management system that allows residents to book barangay facilities, manage reservations, and apply authentication-based discounts through a secure platform. The system includes a Flutter mobile application and a Python Flask backend.

## Features

### Core Functionality
- **Gmail Authentication**: Secure Google Sign-In with separate login/register flows
- **Resident Verification System**: Three-tier verification with discount eligibility
  - Unverified (0% discount)
  - Verified Non-Resident (5% discount)
  - Verified Resident (10% discount)
- **Advanced Booking Management**: Facility scheduling with overlap checking
- **Booking Rejection System**: Fake payment and insufficient payment detection
- **3-Strike Ban System**: Automatic penalties for booking violations
- **Official Capabilities**: Quick booking, facility management, and oversight tools
- **Auto-Fill Integration**: Seamless data synchronization across forms
- **Profile Management**: Photo management and personal information editing

## Technology Stack

### Frontend
- **Flutter**: Cross-platform mobile application framework
- **Dart**: Programming language for Flutter app
- **Google Sign-In**: Authentication integration

### Backend
- **Python Flask**: Web framework for REST API
- **SQLite**: Database management
- **JWT**: Token-based authentication

## Project Structure

```
barangayreserve/
├── lib/                      # Flutter application source code
│   ├── screens/             # Application screens
│   ├── dashboard/           # Dashboard components
│   └── services/            # API services and utilities
├── server/                   # Backend server
│   ├── server.py           # Flask application
│   ├── config.py           # Server configuration
│   └── barangay.db         # SQLite database
└── web/                     # Web interface
    └── index.html          # Landing page
```

## Setup Instructions

### Prerequisites
- Flutter SDK (3.0 or higher)
- Python 3.8 or higher
- Android Studio / VS Code
- Google Cloud Console account (for Google Sign-In)

### Backend Setup

1. Navigate to the server directory:
```bash
cd server
```

2. Install Python dependencies:
```bash
pip install flask flask-cors flask-jwt-extended
```

3. Configure the environment:
- Update `config.py` with your database settings
- Set up Google OAuth credentials

4. Run the server:
```bash
python server.py
```

### Frontend Setup

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Configure Google Sign-In:
- Add your Google OAuth credentials to `android/app/build.gradle`
- Update the OAuth client ID in the Flutter code

3. Run the application:
```bash
flutter run
```

## Official Accounts

The system includes pre-configured official accounts for testing:

| Role | Email |
|------|-------|
| Punong Barangay | captain@barangay.gov |
| Secretary | secretary@barangay.gov |
| Administrator | administrator@barangay.gov |
| Councilor | kagawad1@barangay.gov |
| Planning Officer | planning@barangay.gov |
| Utility Worker | utility@barangay.gov |

*Note: Default passwords are configured in the database. Change these for production use.*

## Database Schema

The SQLite database includes the following main tables:
- `users` - User accounts and authentication
- `facilities` - Available barangay facilities
- `bookings` - Facility reservations
- `verification_requests` - Resident verification applications
- `user_sessions` - Active user sessions

## API Endpoints

### Authentication
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `POST /api/auth/google` - Google authentication

### User Management
- `GET /api/user/profile` - Get user profile
- `PUT /api/user/profile` - Update user profile
- `POST /api/user/photo` - Upload profile photo

### Booking System
- `GET /api/bookings` - Get user bookings
- `POST /api/bookings` - Create booking
- `PUT /api/bookings/:id` - Update booking
- `DELETE /api/bookings/:id` - Cancel booking

### Verification
- `GET /api/verification` - Get verification status
- `POST /api/verification` - Submit verification request

### Official Functions
- `GET /api/official/bookings` - Get all bookings
- `PUT /api/official/bookings/:id/approve` - Approve booking
- `PUT /api/official/bookings/:id/reject` - Reject booking
- `GET /api/official/verification` - Get verification requests

## Security Features

- JWT token-based authentication
- Password hashing using SHA-256
- Session management with automatic logout
- 3-strike ban system for violations
- Input validation and sanitization
- CORS protection

## Development

### Running Tests
```bash
flutter test
```

### Building for Production
```bash
flutter build apk --release
```

## Contributing

This is a capstone project for academic purposes. For questions or suggestions, please refer to the project documentation.

## License

This project is developed for educational purposes. Please obtain proper permissions before using in production environments.

## Acknowledgments

- Barangay Tatala, Rizal, Philippines
- Flutter and Python communities
- Open source contributors

## Version History

- **v1.0** - Initial release with core features
- **v1.1** - Added verification system and discount tiers
- **v1.2** - Implemented booking rejection and ban system
- **v1.3** - Enhanced auto-fill functionality and profile management

## Support

For technical support or inquiries, please refer to the project documentation or contact the development team through the official channels.
