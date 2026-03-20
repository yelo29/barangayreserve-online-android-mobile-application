import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import 'auto_refresh_service.dart';

class DataService {
  // Get current user data from SharedPreferences
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // First try to get user data from JSON (Gmail auth method)
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      try {
        final userData = jsonDecode(userDataString);
        print('✅ DataService: Retrieved user data from JSON');
        return userData;
      } catch (e) {
        print('❌ DataService: Error parsing user_data JSON: $e');
      }
    }
    
    // Fallback to individual keys (legacy method)
    final userEmail = prefs.getString('user_email');
    final userRole = prefs.getString('user_role');
    final userId = prefs.getString('user_id');
    final userName = prefs.getString('user_name');
    
    if (userEmail == null) {
      print('❌ DataService: No user email found in storage');
      return null;
    }
    
    print('✅ DataService: Retrieved user data from individual keys');
    return {
      'email': userEmail,
      'role': userRole ?? 'resident',
      'id': userId,
      'name': userName,
    };
  }
  
  // Get authentication headers
  static Future<Map<String, String>> getHeaders() async {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = await _getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }
  
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
  
  // Fetch user profile data
  static Future<Map<String, dynamic>> fetchUserProfile() async {
    try {
      final userData = await getCurrentUserData();
      if (userData == null) {
        return {'success': false, 'error': 'User not logged in'};
      }
      
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/users/profile/${userData['email']}'),
        headers: await getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 DEBUG: DataService.fetchUserProfile response: $data');
        
        if (data['success'] == true && data.containsKey('user')) {
          final userData = data['user'];
          print('🔍 DEBUG: Extracted user data: $userData');
          print('🔍 DEBUG: User data fields: ${userData.keys.toList()}');
          print('🔍 DEBUG: Profile photo URL: ${userData['profile_photo_url']}');
          return {'success': true, 'data': userData};
        } else {
          return {'success': false, 'error': 'Invalid response format'};
        }
      } else {
        return {'success': false, 'error': 'Failed to fetch profile'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Fetch facilities data
  static Future<Map<String, dynamic>> fetchFacilities() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/facilities'),
        headers: await getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle different response formats with proper type casting
        if (data is List) {
          // Direct array response from server - cast to List<Map<String, dynamic>>
          List<Map<String, dynamic>> facilitiesData = [];
          if (data.isNotEmpty) {
            facilitiesData = List<Map<String, dynamic>>.from(data);
          }
          return {'success': true, 'data': facilitiesData};
        } else if (data is Map && data['success'] == true) {
          // Wrapped response object - cast to Map<String, dynamic>
          Map<String, dynamic> responseMap = Map<String, dynamic>.from(data);
          
          // Ensure facilities data is properly typed
          if (responseMap['data'] is List) {
            List<Map<String, dynamic>> facilitiesData = [];
            if (responseMap['data'].isNotEmpty) {
              facilitiesData = List<Map<String, dynamic>>.from(responseMap['data']);
            }
            responseMap['data'] = facilitiesData;
          }
          
          return responseMap;
        } else {
          return {'success': false, 'error': 'Invalid response format'};
        }
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Fetch bookings data with proper authentication
  static Future<Map<String, dynamic>> fetchBookings({
    String? facilityId,
    String? date,
    String? status,
    String? userRole, // Optional override for user_role
    bool? excludeUserRole, // New flag to completely exclude user_role parameter
  }) async {
    try {
      final userData = await getCurrentUserData();
      if (userData == null) {
        return {'success': false, 'error': 'User not logged in'};
      }
      
      // Build query parameters
      Map<String, String> queryParams = {};
      if (facilityId != null) queryParams['facility_id'] = facilityId;
      if (date != null) queryParams['date'] = date;
      if (status != null) queryParams['status'] = status;
      
      // Use provided userRole or default to current user's role
      if (excludeUserRole == true) {
        // Completely exclude user_role parameter and add excludeUserRole flag
        queryParams['excludeUserRole'] = 'true';
      } else if (userRole != null) {
        if (userRole.isNotEmpty) {
          queryParams['user_role'] = userRole;
        }
        // If userRole is empty string, don't add user_role parameter at all
      } else {
        queryParams['user_role'] = userData['role'];
      }
      
      // For residents, include their email (only if not excluding user_role)
      if (userData['role'] == 'resident' && excludeUserRole != true) {
        queryParams['user_email'] = userData['email'];
      }
      
      String queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      print('🔍 DataService.fetchBookings queryParams: $queryParams');
      print('🔍 DataService.fetchBookings queryString: $queryString');
      
      String url = '${AppConfig.baseUrl}/api/bookings';
      if (queryString.isNotEmpty) {
        url += '?$queryString';
      }
      
      print('🔍 DataService.fetchBookings URL: $url');
      print('🔍 DataService.fetchBookings userRole: ${userData['role']}');
      print('🔍 DataService.fetchBookings userEmail: ${userData['email']}');

      final response = await http.get(
        Uri.parse(url),
        headers: await getHeaders(),
      );

      print('🔍 DataService.fetchBookings response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle different response formats with proper type casting
        if (data is List) {
          // Direct array response from server - cast to List<Map<String, dynamic>>
          List<Map<String, dynamic>> bookingsData = [];
          if (data.isNotEmpty) {
            bookingsData = List<Map<String, dynamic>>.from(data);
          }
          return {'success': true, 'data': bookingsData};
        } else if (data is Map && data['success'] == true) {
          // Wrapped response object - cast to Map<String, dynamic>
          Map<String, dynamic> responseMap = Map<String, dynamic>.from(data);
          
          // Ensure bookings data is properly typed
          if (responseMap['data'] is List) {
            List<Map<String, dynamic>> bookingsData = [];
            if (responseMap['data'].isNotEmpty) {
              bookingsData = List<Map<String, dynamic>>.from(responseMap['data']);
            }
            responseMap['data'] = bookingsData;
          }
          
          return responseMap;
        } else {
          // Fallback for any other format
          List<Map<String, dynamic>> bookingsData = [];
          if (data is List && data.isNotEmpty) {
            bookingsData = List<Map<String, dynamic>>.from(data);
          }
          return {'success': true, 'data': bookingsData};
        }
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      print('❌ DataService.fetchBookings exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Fetch time slots for a facility
  static Future<Map<String, dynamic>> fetchTimeSlots({
    required String facilityId,
    required String date,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/available-timeslots?facility_id=$facilityId&date=$date'),
        headers: await getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Fetch verification requests (for officials)
  static Future<Map<String, dynamic>> fetchVerificationRequests() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/verification-requests'),
        headers: await getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data; // Return the API response directly
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Update booking status (for officials)
  static Future<Map<String, dynamic>> updateBookingStatus(
    int bookingId, 
    String status, {
    String? rejectionReason,
    String? rejectionType
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'status': status,
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
        if (rejectionType != null) 'rejection_type': rejectionType,
      };
      
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/bookings/$bookingId/status'),
        headers: await getHeaders(),
        body: json.encode(updateData),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Booking status updated successfully',
          'data': data,
        };
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Create facility (for officials)
  static Future<Map<String, dynamic>> createFacility(Map<String, dynamic> facilityData) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/facilities'),
        headers: await getHeaders(),
        body: json.encode(facilityData),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Facility created successfully',
          'data': data,
        };
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Update facility (for officials)
  static Future<Map<String, dynamic>> updateFacility(
    String facilityId, 
    Map<String, dynamic> facilityData
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/facilities/$facilityId'),
        headers: await getHeaders(),
        body: json.encode(facilityData),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Facility updated successfully',
          'data': data,
        };
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Delete facility (for officials)
  static Future<Map<String, dynamic>> deleteFacility(String facilityId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/api/facilities/$facilityId'),
        headers: await getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Facility deleted successfully',
          'data': data,
        };
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Update verification status (for officials)
  static Future<Map<String, dynamic>> updateVerificationStatus(
    String requestId, 
    String status, {
    String? discountRate
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'status': status,
        if (discountRate != null) 'discount_rate': discountRate,
      };
      
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/verification-requests/$requestId'),
        headers: await getHeaders(),
        body: json.encode(updateData),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Trigger auto-refresh if verification status was updated successfully and refresh_data is provided
        if (data['success'] == true && data.containsKey('refresh_data')) {
          print('🔄 Triggering auto-refresh for verification status update');
          await AutoRefreshService().triggerAutoRefresh(data['refresh_data']);
        }
        
        return {
          'success': true,
          'message': data['message'] ?? 'Verification status updated successfully',
          'data': data,
        };
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Get verification requests (for officials)
  static Future<Map<String, dynamic>> getVerificationRequests() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/verification-requests'),
        headers: await getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Regenerate facility time slots (for officials)
  static Future<Map<String, dynamic>> regenerateFacilityTimeSlots(String facilityId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/facilities/$facilityId/regenerate-timeslots'),
        headers: await getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Time slots regenerated successfully',
          'data': data,
        };
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Update user profile
  static Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      final userData = await getCurrentUserData();
      if (userData == null) {
        return {'success': false, 'error': 'User not logged in'};
      }

      // Add email to profile data for server identification
      profileData['email'] = userData['email'];
      
      print('🔍 DEBUG: Frontend profile update data:');
      print('🔍 DEBUG: Full profileData: $profileData');
      print('🔍 DEBUG: Email: ${profileData['email']}');
      print('🔍 DEBUG: Has profile_photo_url: ${profileData.containsKey('profile_photo_url')}');
      print('🔍 DEBUG: Profile photo URL length: ${profileData['profile_photo_url']?.length ?? 0}');

      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/users/profile'),
        headers: await getHeaders(),
        body: json.encode(profileData),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Trigger auto-refresh if profile was updated successfully and refresh_data is provided
        if (data['success'] == true && data.containsKey('refresh_data')) {
          print('🔄 Triggering auto-refresh for profile update');
          await AutoRefreshService().triggerAutoRefresh(data['refresh_data']);
        }
        
        return {
          'success': true,
          'message': data['message'] ?? 'Profile updated successfully',
          'data': data,
        };
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Fetch officials list
  static Future<Map<String, dynamic>> fetchOfficials() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/officials'),
        headers: await getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle different response formats with proper type casting
        if (data is Map && data['success'] == true) {
          // Wrapped response object - cast to Map<String, dynamic>
          Map<String, dynamic> responseMap = Map<String, dynamic>.from(data);
          
          // Ensure officials data is properly typed
          if (responseMap['data'] is List) {
            List<Map<String, dynamic>> officialsData = [];
            if (responseMap['data'].isNotEmpty) {
              officialsData = List<Map<String, dynamic>>.from(responseMap['data']);
            }
            responseMap['data'] = officialsData;
          }
          
          return responseMap;
        } else {
          return {'success': false, 'error': 'Invalid response format'};
        }
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Check verification status for form locking
  static Future<Map<String, dynamic>> checkVerificationStatus(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/verification-requests/status/$userId'),
        headers: await getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? false,
          'can_submit': data['can_submit'] ?? false,
          'lock_message': data['lock_message'] ?? '',
          'current_status': data['current_status'] ?? '',
          'verified': data['verified'] ?? 0,
          'verification_type': data['verification_type'],
          'user_id': data['user_id'] ?? userId,
          'email': data['email'] ?? '',
        };
      } else {
        return {
          'success': false, 
          'error': 'HTTP ${response.statusCode}',
          'can_submit': false,
          'lock_message': 'Error checking verification status',
        };
      }
    } catch (e) {
      print('❌ Error checking verification status: $e');
      return {
        'success': false, 
        'error': e.toString(),
        'can_submit': false,
        'lock_message': 'Error checking verification status',
      };
    }
  }
}
