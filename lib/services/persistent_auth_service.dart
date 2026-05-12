import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/debug_logger.dart';
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
      DebugLogger.api('Saving login state...');
      
      final prefs = await SharedPreferences.getInstance();
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      
      // Save authentication data
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(userData));
      await prefs.setString(_deviceIdKey, deviceInfo.id ?? '');
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_loginTimeKey, DateTime.now().toIso8601String());
      
      DebugLogger.success('Login state saved for device: ${deviceInfo.id}');
      DebugLogger.success('User logged in: ${userData['email']}');
    } catch (e) {
      DebugLogger.error('Error saving login state', error: e);
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
          DebugLogger.success('User is logged in on same device');
          return true;
        } else {
          DebugLogger.warning('Different device detected, requiring re-login', tag: 'PersistentAuth');
          await clearLoginState();
          return false;
        }
      }
      
      DebugLogger.api('User not logged in');
      return false;
    } catch (e) {
      DebugLogger.error('Error checking login state', error: e);
      return false;
    }
  }
  
  // Get current user data if logged in on same device
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      
      if (!isLoggedIn) {
        DebugLogger.api('No user logged in');
        return null;
      }
      
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final savedDeviceId = prefs.getString(_deviceIdKey);
      
      // Verify this is the same device
      if (savedDeviceId != deviceInfo.id) {
        DebugLogger.log('Different device, clearing data', tag: 'PersistentAuth');
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
                DebugLogger.log('User is banned - clearing login state', tag: 'PersistentAuth');
                DebugLogger.log('Ban reason: ${userStatus['ban_reason']}', tag: 'PersistentAuth');
                await clearLoginState();
                return null;
              }
            }
          }
        } catch (e) {
          DebugLogger.log('Error checking ban status', tag: 'PersistentAuth');
          // Continue with login but log the error
        }
        
        DebugLogger.success('Retrieved user data for device: ${deviceInfo.id}');
        return userData;
      }
      
      DebugLogger.api('No user data found');
      return null;
    } catch (e) {
      DebugLogger.error('Error getting current user', error: e);
      return null;
    }
  }
  
  // Get authentication token
  static Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      DebugLogger.error('Error getting auth token', error: e);
      return null;
    }
  }
  
  // Clear login state (logout)
  static Future<void> clearLoginState() async {
    try {
      DebugLogger.api('Clearing login state...');
      
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
        DebugLogger.success('Login state cleared successfully');
      } else {
        DebugLogger.log('Some data may not have been cleared properly', tag: 'PersistentAuth');
        // Force clear again
        await prefs.clear();
        DebugLogger.api('Forced complete clear');
      }
    } catch (e) {
      DebugLogger.error('Error clearing login state', error: e);
    }
  }
  
  // Get device information
  static Future<String?> getDeviceId() async {
    try {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      return deviceInfo.id;
    } catch (e) {
      DebugLogger.error('Error getting device ID', error: e);
      return null;
    }
  }
  
  // Get last login time
  static Future<String?> getLastLoginTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_loginTimeKey);
    } catch (e) {
      DebugLogger.error('Error getting last login time', error: e);
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
          DebugLogger.log('Session is stale (${difference.inDays} days)', tag: 'PersistentAuth');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      DebugLogger.error('Error validating session', error: e);
      return false;
    }
  }
}
