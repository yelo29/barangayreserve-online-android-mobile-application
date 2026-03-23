import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class PersistentAuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _deviceIdKey = 'device_id';
  static const String _loginTimeKey = 'last_login_time';
  static const String _isLoggedInKey = 'is_logged_in';
  
  // Save login state with device binding
  static Future<void> saveLoginState(Map<String, dynamic> userData, String token) async {
    try {
      print('🔐 PersistentAuth: Saving login state...');
      
      final prefs = await SharedPreferences.getInstance();
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      
      // Save authentication data
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(userData));
      await prefs.setString(_deviceIdKey, deviceInfo.id ?? '');
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_loginTimeKey, DateTime.now().toIso8601String());
      
      print('✅ PersistentAuth: Login state saved for device: ${deviceInfo.id}');
      print('✅ PersistentAuth: User: ${userData['email']}');
    } catch (e) {
      print('❌ PersistentAuth: Error saving login state: $e');
    }
  }
  
  // Check if user is logged in on this device
  static Future<bool> isUserLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      
      if (isLoggedIn) {
        final deviceInfo = await DeviceInfoPlugin().androidInfo;
        final savedDeviceId = prefs.getString(_deviceIdKey);
        
        // Verify this is the same device
        if (savedDeviceId == deviceInfo.id) {
          print('✅ PersistentAuth: User is logged in on same device');
          return true;
        } else {
          print('⚠️ PersistentAuth: Different device detected, requiring re-login');
          await clearLoginState();
          return false;
        }
      }
      
      print('🔍 PersistentAuth: User not logged in');
      return false;
    } catch (e) {
      print('❌ PersistentAuth: Error checking login state: $e');
      return false;
    }
  }
  
  // Get current user data if logged in on same device
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      
      if (!isLoggedIn) {
        print('🔍 PersistentAuth: No user logged in');
        return null;
      }
      
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final savedDeviceId = prefs.getString(_deviceIdKey);
      
      // Verify this is the same device
      if (savedDeviceId != deviceInfo.id) {
        print('⚠️ PersistentAuth: Different device, clearing data');
        await clearLoginState();
        return null;
      }
      
      final userDataString = prefs.getString(_userKey);
      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        
        // Check ban status before returning user data
        try {
          final userEmail = userData['email'];
          if (userEmail != null) {
            // Direct ban status check to avoid circular dependency
            final response = await http.get(
              Uri.parse('${AppConfig.baseUrl}/api/users/status/$userEmail'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${prefs.getString(_tokenKey) ?? ''}',
              },
            );
            
            if (response.statusCode == 200) {
              final userStatus = json.decode(response.body);
              if (userStatus['is_banned'] == true) {
                print('🚨 PersistentAuth: User is banned - clearing login state');
                print('🚨 Ban reason: ${userStatus['ban_reason']}');
                await clearLoginState();
                return null;
              }
            }
          }
        } catch (e) {
          print('⚠️ PersistentAuth: Error checking ban status: $e');
          // Continue with login but log the error
        }
        
        print('✅ PersistentAuth: Retrieved user data for device: ${deviceInfo.id}');
        return userData;
      }
      
      print('🔍 PersistentAuth: No user data found');
      return null;
    } catch (e) {
      print('❌ PersistentAuth: Error getting current user: $e');
      return null;
    }
  }
  
  // Get authentication token
  static Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      print('❌ PersistentAuth: Error getting auth token: $e');
      return null;
    }
  }
  
  // Clear login state (logout)
  static Future<void> clearLoginState() async {
    try {
      print('🔐 PersistentAuth: Clearing login state...');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all authentication-related keys
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      await prefs.remove(_deviceIdKey);
      await prefs.remove(_loginTimeKey);
      await prefs.setBool(_isLoggedInKey, false);
      
      // Additional verification - ensure keys are actually cleared
      final tokenCheck = prefs.getString(_tokenKey);
      final userCheck = prefs.getString(_userKey);
      final loginCheck = prefs.getBool(_isLoggedInKey);
      
      if (tokenCheck == null && userCheck == null && loginCheck == false) {
        print('✅ PersistentAuth: Login state cleared successfully');
      } else {
        print('⚠️ PersistentAuth: Some data may not have been cleared properly');
        // Force clear again
        await prefs.clear();
        print('🔄 PersistentAuth: Forced complete clear');
      }
    } catch (e) {
      print('❌ PersistentAuth: Error clearing login state: $e');
    }
  }
  
  // Get device information
  static Future<String?> getDeviceId() async {
    try {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      return deviceInfo.id;
    } catch (e) {
      print('❌ PersistentAuth: Error getting device ID: $e');
      return null;
    }
  }
  
  // Get last login time
  static Future<String?> getLastLoginTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_loginTimeKey);
    } catch (e) {
      print('❌ PersistentAuth: Error getting last login time: $e');
      return null;
    }
  }
  
  // Validate session freshness (optional - for security)
  static Future<bool> isSessionFresh() async {
    try {
      final lastLoginTime = await getLastLoginTime();
      if (lastLoginTime != null) {
        final lastLogin = DateTime.parse(lastLoginTime);
        final now = DateTime.now();
        final difference = now.difference(lastLogin);
        
        // Consider session stale after 7 days
        if (difference.inDays > 7) {
          print('⚠️ PersistentAuth: Session is stale (${difference.inDays} days)');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      print('❌ PersistentAuth: Error validating session: $e');
      return false;
    }
  }
}
