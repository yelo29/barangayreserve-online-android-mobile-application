import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'base64_image_service.dart';
import '../config/app_config.dart';

class ApiService {
  // Dynamic server URL - works with Python Flask server
  static String get baseUrl => AppConfig.baseUrl;
  
  // Token management (JWT-like tokens from new backend)
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    print('🔍 Saved auth token: $token');
  }
  
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    print('🔍 Retrieved auth token: $token');
    return token;
  }
  
  static Future<void> _removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    print('🔍 Removed auth token');
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
        print('🔍 Adding JWT Bearer token for authentication');
      } else {
        print('🔍 No auth token available for authentication');
      }
    }

    return headers;
  }

  // Authentication
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('🔍 ApiService.login called');
      print('🔍 Using baseUrl: $baseUrl');
      print('🔍 Full login URL: $baseUrl/api/auth/login');
      print('🔍 Login data: email=$email, password=$password');
      
      final requestBody = json.encode({
        'email': email,
        'password': password,
      });
      
      print('🔍 Request body: $requestBody');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: await getHeaders(includeAuth: false),
        body: requestBody,
      );

      print('🔍 Login response status: ${response.statusCode}');
      print('🔍 Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 Parsed response data: $data');
        
        if (data['success'] == true) {
          // Save token and user data
          if (data['token'] != null) {
            await _saveToken(data['token']);
          }
          
          // Save user data to preferences for easy access
          if (data['user'] != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_email', data['user']['email'] ?? '');
            await prefs.setString('user_id', data['user']['id'].toString());
            await prefs.setString('user_name', data['user']['full_name'] ?? '');
            await prefs.setString('user_role', data['user']['role'] ?? 'resident');
            
            // Convert integer booleans to actual booleans
            final verified = data['user']['verified'];
            await prefs.setBool('user_verified', verified == 1 || verified == true);
            
            await prefs.setDouble('user_discount_rate', (data['user']['discount_rate'] ?? 0.0).toDouble());
            await prefs.setString('user_contact_number', data['user']['contact_number'] ?? '');
            await prefs.setString('user_profile_photo_url', data['user']['profile_photo_url'] ?? '');
          }
          
          return data;
        } else {
          return {'success': false, 'message': data['message'] ?? 'Login failed'};
        }
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
      print('❌ ApiService.login exception: $e');
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

      print('🔍 getCurrentUser response status: ${response.statusCode}');
      print('🔍 getCurrentUser response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          return {'success': false, 'error': data['error'] ?? 'Failed to get user data'};
        }
      } else {
        // If server fails, try to get from preferences
        final prefs = await SharedPreferences.getInstance();
        
        // First try to get from JSON data (Gmail auth method)
        final userDataString = prefs.getString('user_data');
        if (userDataString != null) {
          try {
            final userData = jsonDecode(userDataString);
            return {'success': true, 'user': userData};
          } catch (e) {
            print('❌ ApiServiceUpdated: Error parsing user_data JSON: $e');
          }
        }
        
        // Fallback to individual keys (legacy method)
        final userEmail = prefs.getString('user_email');
        
        if (userEmail != null) {
          return {
            'success': true,
            'user': {
              'id': prefs.getString('user_id') ?? '0',
              'email': userEmail,
              'full_name': prefs.getString('user_name') ?? 'User',
              'role': prefs.getString('user_role') ?? 'resident',
              'verified': prefs.getBool('user_verified') ?? false,
              'discount_rate': prefs.getDouble('user_discount_rate') ?? 0.0,
              'contact_number': prefs.getString('user_contact_number') ?? '',
              'profile_photo_url': prefs.getString('user_profile_photo_url') ?? '',
            }
          };
        }
        
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      print('❌ getCurrentUser exception: $e');
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

      print('🔍 getFacilities response status: ${response.statusCode}');
      print('🔍 getFacilities response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle different response formats
        if (data is List) {
          // Direct array response from server
          return {'success': true, 'data': data};
        } else if (data is Map && data['success'] == true) {
          // Wrapped response object - cast to Map<String, dynamic>
          return Map<String, dynamic>.from(data);
        } else {
          return {'success': false, 'error': 'Invalid response format'};
        }
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      print('❌ getFacilities exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get bookings
  static Future<Map<String, dynamic>> getBookings({
    String? facilityId,
    String? date,
    String? status,
    String? userRole,
    String? userEmail,
  }) async {
    try {
      // Build query parameters
      Map<String, String> queryParams = {};
      if (facilityId != null) queryParams['facility_id'] = facilityId;
      if (date != null) queryParams['date'] = date;
      if (status != null) queryParams['status'] = status;
      if (userRole != null) queryParams['user_role'] = userRole;
      if (userEmail != null) queryParams['user_email'] = userEmail;
      
      String queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      String url = '$baseUrl/api/bookings';
      if (queryString.isNotEmpty) {
        url += '?$queryString';
      }
      
      print('🔍 getBookings URL: $url');
      print('🔍 getBookings userRole: $userRole');
      print('🔍 getBookings userEmail: $userEmail');

      final response = await http.get(
        Uri.parse(url),
        headers: await getHeaders(),
      );

      print('🔍 getBookings response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          return {'success': false, 'error': data['error'] ?? 'Failed to get bookings'};
        }
      } else {
        print('🔍 getBookings - failed with status: ${response.statusCode}');
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      print('❌ getBookings exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Create booking
  static Future<Map<String, dynamic>> createBooking(Map<String, dynamic> bookingData) async {
    try {
      print('🔍 createBooking called with data: $bookingData');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/bookings'),
        headers: await getHeaders(),
        body: json.encode(bookingData),
      );

      print('🔍 createBooking response status: ${response.statusCode}');
      print('🔍 createBooking response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          return {'success': false, 'error': data['error'] ?? 'Failed to create booking'};
        }
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      print('❌ createBooking exception: $e');
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

      print('🔍 updateBookingStatus response status: ${response.statusCode}');
      print('🔍 updateBookingStatus response body: ${response.body}');

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
      print('❌ updateBookingStatus exception: $e');
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

      print('🔍 getVerificationRequests response status: ${response.statusCode}');

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
      print('❌ getVerificationRequests exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Update verification status
  static Future<Map<String, dynamic>> updateVerificationStatus(int requestId, String status, {String? notes, String? rejectionReason, String? discountRate}) async {
    try {
      Map<String, dynamic> updateData = {
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      if (notes != null) {
        updateData['approval_notes'] = notes;
      }
      
      if (rejectionReason != null) {
        updateData['rejection_reason'] = rejectionReason;
      }
      
      if (discountRate != null) {
        updateData['discountRate'] = double.parse(discountRate);
      }
      
      final response = await http.put(
        Uri.parse('$baseUrl/api/verification-requests/$requestId'),
        headers: await getHeaders(),
        body: json.encode(updateData),
      );

      print('🔍 updateVerificationStatus response status: ${response.statusCode}');

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
      print('❌ updateVerificationStatus exception: $e');
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

      print('🔍 getTimeSlots response status: ${response.statusCode}');

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
      print('❌ getTimeSlots exception: $e');
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
      print('❌ logout exception: $e');
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
      print('❌ healthCheck exception: $e');
      return {'status': 'unhealthy', 'error': e.toString()};
    }
  }

  // Utility methods
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    print('🔍 Cleared all user data');
  }
}
