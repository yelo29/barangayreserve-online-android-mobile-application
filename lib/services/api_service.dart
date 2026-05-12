import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'base64_image_service.dart';
import '../config/app_config.dart';
import 'ban_detection_service.dart';
import 'auto_refresh_service.dart';
import '../utils/debug_logger.dart';

class ApiService {
  // Dynamic server URL - works with Python Flask server
  static String get baseUrl => AppConfig.baseUrl;
  
  // Token management (JWT-like tokens from new backend)
  static Future<void> _saveToken(String token) async {
    try {
      DebugLogger.api('Saving token: type=${token.runtimeType}, length=${token.length}');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      
      DebugLogger.success('Token saved successfully');
    } catch (e) {
      DebugLogger.error('_saveToken failed', error: e);
      throw e;
    }
  }
  
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    DebugLogger.api('Token retrieved: ${token != null ? 'present' : 'null'}');
    return token;
  }
  
  static Future<void> _removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    DebugLogger.api('Token removed');
  }

  // Headers (JWT Bearer token authentication)
  static Future<Map<String, String>> getHeaders({bool includeAuth = true}) async {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _getToken();
      
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        DebugLogger.api('JWT Bearer token added to headers');
      } else {
        DebugLogger.warning('No auth token available for authentication');
      }
    }

    return headers;
  }

  // Authentication
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      DebugLogger.api('Login attempt for email: $email');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: await getHeaders(includeAuth: false),
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      DebugLogger.api('Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          DebugLogger.success('Login successful, processing data');
          
          // Save token and user data
          if (data['token'] != null) {
            await _saveToken(data['token']);
          } else {
            DebugLogger.warning('No token in login response');
          }
          
          // Save user data to preferences for easy access
          if (data['user'] != null) {
            final prefs = await SharedPreferences.getInstance();
            try {
              await prefs.setString('user_email', data['user']['email']?.toString() ?? '');
              await prefs.setString('user_id', data['user']['id']?.toString() ?? '0');
              await prefs.setString('user_name', data['user']['full_name']?.toString() ?? '');
              await prefs.setString('user_role', data['user']['role']?.toString() ?? 'resident');
              
              // Convert integer booleans to actual booleans with null safety
              final verified = data['user']['verified'];
              final emailVerified = data['user']['email_verified'];
              final isActive = data['user']['is_active'];
              
              await prefs.setBool('user_verified', (verified == 1 || verified == true) ?? false);
              await prefs.setDouble('user_discount_rate', (data['user']['discount_rate'] ?? 0.0).toDouble());
              await prefs.setString('user_contact_number', data['user']['contact_number']?.toString() ?? '');
              await prefs.setString('user_profile_photo_url', data['user']['profile_photo_url']?.toString() ?? '');
              DebugLogger.success('User data saved successfully');
            } catch (e) {
              DebugLogger.error('SharedPreferences error during login', error: e);
              throw e;
            }
          } else {
            DebugLogger.warning('No user data in login response');
          }
          
          return data;
        } else {
          DebugLogger.warning('Login failed: ${data['message']}');
          return {'success': false, 'message': data['message'] ?? 'Login failed'};
        }
      } else {
        DebugLogger.error('HTTP error during login: ${response.statusCode}');
        // For non-200 status codes, try to parse error message from response body
        try {
          final errorData = json.decode(response.body);
          return {'success': false, 'message': errorData['message'] ?? 'Login failed'};
        } catch (e) {
          return {'success': false, 'message': 'Login failed'};
        }
      }
    } catch (e) {
      DebugLogger.error('Login exception', error: e);
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get current user
  static Future<Map<String, dynamic>> getCurrentUser({String? email}) async {
    try {
      String url = '$baseUrl/api/me';
      if (email != null) {
        url += '?email=$email';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: await getHeaders(),
      );

      DebugLogger.api('getCurrentUser response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      DebugLogger.error('getCurrentUser exception', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get facilities
  static Future<Map<String, dynamic>> getFacilities() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/facilities'),
        headers: await getHeaders(),
      );

      DebugLogger.api('getFacilities response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return await _handleApiResponse(data, 'getFacilities');
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      DebugLogger.error('getFacilities exception', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get bookings
  static Future<Map<String, dynamic>> getBookings({
    String? facilityId,
    String? date,
    String? status,
    String? userRole,
  }) async {
    try {
      // Build query parameters
      Map<String, String> queryParams = {};
      if (facilityId != null) queryParams['facility_id'] = facilityId;
      if (date != null) queryParams['date'] = date;
      if (status != null) queryParams['status'] = status;
      
      String queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      String url = '$baseUrl/api/bookings';
      if (queryString.isNotEmpty) {
        url += '?$queryString';
      }
      
      DebugLogger.api('getBookings URL: $url, userRole: $userRole');

      final response = await http.get(
        Uri.parse(url),
        headers: await getHeaders(),
      );

      DebugLogger.api('getBookings response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          return {'success': false, 'error': data['error'] ?? 'Failed to get bookings'};
        }
      } else {
        DebugLogger.warning('getBookings failed with status: ${response.statusCode}');
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      DebugLogger.error('getBookings exception', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }

  // Create booking
  static Future<Map<String, dynamic>> createBooking(Map<String, dynamic> bookingData) async {
    try {
      DebugLogger.api('createBooking called');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/bookings'),
        headers: await getHeaders(),
        body: json.encode(bookingData),
      );

      DebugLogger.api('createBooking response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Trigger auto-refresh if booking was successful and refresh_data is provided
        if (data['success'] == true && data.containsKey('refresh_data')) {
          DebugLogger.api('Triggering auto-refresh for booking creation');
          await AutoRefreshService().triggerAutoRefresh(data['refresh_data']);
        }
        
        // Handle response and check for ban status
        return await _handleApiResponse(data, 'createBooking');
      } else {
        // Try to parse error response for detailed error information
        try {
          final errorData = json.decode(response.body);
          return {
            'success': false, 
            'error': errorData['message'] ?? 'HTTP ${response.statusCode}',
            'error_type': errorData['error_type'],
            'ban_reason': errorData['ban_reason']
          };
        } catch (e) {
          return {'success': false, 'error': 'HTTP ${response.statusCode}'};
        }
      }
    } catch (e) {
      DebugLogger.error('createBooking exception', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }

  // Check booking conflict
  static Future<Map<String, dynamic>> checkBookingConflict(Map<String, dynamic> bookingData) async {
    try {
      DebugLogger.api('checkBookingConflict called');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/bookings/check-conflict'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bookingData),
      );

      DebugLogger.api('checkBookingConflict response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          return {'success': false, 'error': data['message'] ?? 'Failed to check conflict'};
        }
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      DebugLogger.error('checkBookingConflict exception', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }

  // Update booking status
  static Future<Map<String, dynamic>> updateBookingStatus(int bookingId, String status, {String? rejectionReason, String? rejectionType}) async {
    try {
      Map<String, dynamic> updateData = {
        'status': status,
      };
      
      if (rejectionReason != null) {
        updateData['rejection_reason'] = rejectionReason;
      }
      
      if (rejectionType != null) {
        updateData['rejection_type'] = rejectionType;
      }
      
      final response = await http.put(
        Uri.parse('$baseUrl/api/bookings/$bookingId/status'),
        headers: await getHeaders(),
        body: json.encode(updateData),
      );

      DebugLogger.api('updateBookingStatus response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          return {'success': false, 'error': data['error'] ?? 'Failed to update booking'};
        }
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      DebugLogger.error('updateBookingStatus exception', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get verification requests
  static Future<Map<String, dynamic>> getVerificationRequests() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/verification-requests'),
        headers: await getHeaders(),
      );

      DebugLogger.api('getVerificationRequests response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          return {'success': false, 'error': data['error'] ?? 'Failed to get verification requests'};
        }
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      DebugLogger.error('getVerificationRequests exception', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }

  // Update verification status
  static Future<Map<String, dynamic>> updateVerificationStatus(int requestId, String status, {String? notes, String? rejectionReason, String? profilePhotoUrl, double? discountRate}) async {
    try {
      Map<String, dynamic> updateData = {
        'status': status,
      };
      
      if (notes != null) {
        updateData['approval_notes'] = notes;
      }
      
      if (rejectionReason != null) {
        updateData['rejection_reason'] = rejectionReason;
      }
      
      // Add profile photo URL if provided (for approved requests)
      if (profilePhotoUrl != null && status == 'approved') {
        updateData['profilePhotoUrl'] = profilePhotoUrl;
      }
      
      // Add discount rate for approved requests
      if (discountRate != null && status == 'approved') {
        updateData['discountRate'] = discountRate;
      }
      
      // Add current timestamp
      updateData['updatedAt'] = DateTime.now().toIso8601String();
      
      final response = await http.put(
        Uri.parse('$baseUrl/api/verification-requests/$requestId'), // Fixed endpoint
        headers: await getHeaders(),
        body: json.encode(updateData),
      );

      DebugLogger.api('updateVerificationStatus response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          return {'success': false, 'error': data['error'] ?? 'Failed to update verification status'};
        }
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      DebugLogger.error('updateVerificationStatus exception', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get time slots for a facility and date
  static Future<Map<String, dynamic>> getTimeSlots(int facilityId, String date) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/facilities/$facilityId/timeslots?date=$date'),
        headers: await getHeaders(),
      );

      DebugLogger.api('getTimeSlots response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          return {'success': false, 'error': data['error'] ?? 'Failed to get time slots'};
        }
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      DebugLogger.error('getTimeSlots exception', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }

  // Logout
  static Future<Map<String, dynamic>> logout() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/logout'),
        headers: await getHeaders(),
      );

      // Clear local token regardless of server response
      await _removeToken();
      
      // Clear user preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('user_role');
      await prefs.remove('user_verified');
      await prefs.remove('user_discount_rate');
      await prefs.remove('user_contact_number');
      await prefs.remove('user_profile_photo_url');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {'success': true, 'message': 'Logged out successfully'};
      }
    } catch (e) {
      DebugLogger.error('logout exception', error: e);
      // Still clear local data even if network fails
      await _removeToken();
      return {'success': true, 'message': 'Logged out successfully'};
    }
  }

  // Health check
  static Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: await getHeaders(includeAuth: false),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'unhealthy', 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      DebugLogger.api('healthCheck exception', error: e);
      return {'status': 'unhealthy', 'error': e.toString()};
    }
  }

  // Utility methods
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    DebugLogger.api('Cleared all user data');
  }

  // Additional methods for compatibility
  static Future<Map<String, dynamic>> register(
    String name, 
    String email, 
    String password, 
    {String role = 'resident'}
  ) async {
    try {
      DebugLogger.api('Register called for email: $email, role: $role');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: await getHeaders(includeAuth: false),
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'role': role,
        }),
      );

      DebugLogger.api('Registration response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        DebugLogger.api('Registration response parsed');
        return data;
      } else {
        // For non-200 status codes, try to parse error message from response body
        try {
          final errorData = json.decode(response.body);
          return {'success': false, 'message': errorData['message'] ?? 'Server error: ${response.statusCode}'};
        } catch (e) {
          return {'success': false, 'message': 'Server error: ${response.statusCode}'};
        }
      }
    } catch (e) {
      DebugLogger.error('Registration exception', error: e);
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<List<Map<String, dynamic>>> getOfficials() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users?role=official'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
      }
      return [];
    } catch (e) {
      DebugLogger.error('getOfficials error', error: e);
      return [];
    }
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/users/profile'),
        headers: await getHeaders(),
        body: json.encode(profileData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        DebugLogger.warning('updateProfile failed with status: ${response.statusCode}');
        return {'success': false, 'message': 'Update failed'};
      }
    } catch (e) {
      DebugLogger.error('updateProfile error', error: e);
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getUserProfile(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/profile?email=$email'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {'success': false, 'error': 'Profile not found'};
      }
    } catch (e) {
      DebugLogger.error('getUserProfile error', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> profileData) async {
    return await updateProfile(profileData);
  }

  // Update profile with explicit token
  static Future<Map<String, dynamic>> updateUserProfileWithToken(String token, Map<String, dynamic> profileData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(profileData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        DebugLogger.warning('updateUserProfileWithToken failed with status: ${response.statusCode}');
        return {'success': false, 'message': 'Update failed'};
      }
    } catch (e) {
      DebugLogger.error('updateUserProfileWithToken error', error: e);
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createVerificationRequest(Map<String, dynamic> verificationData) async {
    try {
      DebugLogger.api('createVerificationRequest called');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/verification-requests'),
        headers: await getHeaders(),
        body: json.encode(verificationData),
      );

      DebugLogger.api('createVerificationRequest response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 403) {
        // Handle ban errors specifically
        final data = json.decode(response.body);
        return data; // Return the ban error structure directly
      } else {
        return {'success': false, 'message': 'Failed to create verification request - HTTP ${response.statusCode}'};
      }
    } catch (e) {
      DebugLogger.error('createVerificationRequest error', error: e);
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createFacility(Map<String, dynamic> facilityData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/facilities'),
        headers: await getHeaders(),
        body: json.encode(facilityData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {'success': false, 'message': 'Failed to create facility'};
      }
    } catch (e) {
      DebugLogger.error('createFacility error', error: e);
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateFacility(String facilityId, Map<String, dynamic> facilityData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/facilities/$facilityId'),
        headers: await getHeaders(),
        body: json.encode(facilityData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {'success': false, 'message': 'Failed to update facility'};
      }
    } catch (e) {
      DebugLogger.error('updateFacility error', error: e);
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteFacility(String facilityId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/facilities/$facilityId'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {'success': false, 'message': 'Failed to delete facility'};
      }
    } catch (e) {
      DebugLogger.error('deleteFacility error', error: e);
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> regenerateFacilityTimeSlots(String facilityId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/facilities/$facilityId/regenerate-timeslots'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {'success': false, 'message': 'Failed to regenerate time slots'};
      }
    } catch (e) {
      DebugLogger.error('regenerateFacilityTimeSlots error', error: e);
      return {'success': false, 'message': e.toString()};
    }
  }

  // Email OTP Verification Methods
  static Future<Map<String, dynamic>> verifyEmailOTP(String email, String otpCode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/verify-email-otp'),
        headers: await getHeaders(includeAuth: false),
        body: json.encode({
          'email': email,
          'otp_code': otpCode,
        }),
      );

      final data = json.decode(response.body);
      DebugLogger.api('Email OTP verification response: success=${data['success']}');
      
      if (response.statusCode == 200) {
        return data;
      } else {
        return {'success': false, 'message': 'Failed to verify OTP'};
      }
    } catch (e) {
      DebugLogger.error('verifyEmailOTP error', error: e);
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> resendOTP(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/resend-otp'),
        headers: await getHeaders(includeAuth: false),
        body: json.encode({
          'email': email,
        }),
      );

      final data = json.decode(response.body);
      DebugLogger.api('Resend OTP response: success=${data['success']}');
      
      if (response.statusCode == 200) {
        return data;
      } else {
        return {'success': false, 'message': 'Failed to resend OTP'};
      }
    } catch (e) {
      DebugLogger.error('resendOTP error', error: e);
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Handle API response and check for ban status
  static Future<Map<String, dynamic>> _handleApiResponse(
    Map<String, dynamic> response, 
    String operation
  ) async {
    // Check if response indicates user is banned
    if (response['success'] == false) {
      final message = response['message']?.toString().toLowerCase() ?? '';
      
      if (message.contains('banned') || message.contains('permanently banned')) {
        print('🚨 ApiService: User banned detected in $operation response');
        print('🚨 Ban message: ${response['message']}');
        
        // Trigger automatic logout for banned user
        await BanDetectionService.checkAndHandleBanStatus();
        
        return {
          ...response,
          'user_banned': true,
          'auto_logout_triggered': true
        };
      }
    }
    
    return response;
  }
}
