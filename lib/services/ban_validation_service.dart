import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_service.dart';
import 'auth_api_service.dart';

/// Service for validating user ban status before performing actions
class BanValidationService {
  
  /// Check if user can perform booking action
  static Future<Map<String, dynamic>> validateUserForBooking() async {
    try {
      // Get user email directly from AuthApiService to avoid circular dependency
      final authApiService = AuthApiService.instance;
      await authApiService.ensureUserLoaded();
      final currentUser = authApiService.currentUser;
      
      if (currentUser == null) {
        return {'allowed': false, 'reason': 'User not logged in'};
      }
      
      final userEmail = currentUser['email'];
      print('🔍 BanValidation: Checking booking permission for user: $userEmail');
      
      // Check server-side ban status
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/users/status/$userEmail'),
        headers: await ApiService.getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final userStatus = json.decode(response.body);
        
        if (userStatus['is_banned'] == true) {
          print('🚨 BanValidation: User is banned - blocking booking');
          return {
            'allowed': false,
            'reason': 'Account is banned',
            'ban_reason': userStatus['ban_reason'] ?? 'Account has been banned by administrator.',
            'error_type': 'user_banned'
          };
        }
        
        print('✅ BanValidation: User is not banned - booking allowed');
        return {'allowed': true};
      } else {
        print('❌ BanValidation: Failed to check user status - allowing booking (fail-safe)');
        return {'allowed': true}; // Fail-safe - allow if server check fails
      }
    } catch (e) {
      print('❌ BanValidation: Exception checking ban status - allowing booking (fail-safe): $e');
      return {'allowed': true}; // Fail-safe - allow if check fails
    }
  }
  
  /// Check if user can submit verification request
  static Future<Map<String, dynamic>> validateUserForVerification() async {
    try {
      // Get user email directly from AuthApiService to avoid circular dependency
      final authApiService = AuthApiService.instance;
      await authApiService.ensureUserLoaded();
      final currentUser = authApiService.currentUser;
      
      if (currentUser == null) {
        return {'allowed': false, 'reason': 'User not logged in'};
      }
      
      final userEmail = currentUser['email'];
      print('🔍 BanValidation: Checking verification permission for user: $userEmail');
      
      // Check server-side ban status
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/users/status/$userEmail'),
        headers: await ApiService.getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final userStatus = json.decode(response.body);
        
        if (userStatus['is_banned'] == true) {
          print('🚨 BanValidation: User is banned - blocking verification request');
          return {
            'allowed': false,
            'reason': 'Account is banned',
            'ban_reason': userStatus['ban_reason'] ?? 'Account has been banned by administrator.',
            'error_type': 'user_banned'
          };
        }
        
        print('✅ BanValidation: User is not banned - verification allowed');
        return {'allowed': true};
      } else {
        print('❌ BanValidation: Failed to check user status - allowing verification (fail-safe)');
        return {'allowed': true}; // Fail-safe - allow if server check fails
      }
    } catch (e) {
      print('❌ BanValidation: Exception checking ban status - allowing verification (fail-safe): $e');
      return {'allowed': true}; // Fail-safe - allow if check fails
    }
  }
  
  /// Show ban dialog to user
  static void showBanDialog(BuildContext context, Map<String, dynamic> banInfo) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must acknowledge
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Account Banned'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your account has been banned and cannot perform this action.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            if (banInfo['ban_reason'] != null) ...[
              Text(
                'Reason:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                banInfo['ban_reason'],
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please contact the barangay office for assistance.',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('I Understand'),
          ),
        ],
      ),
    );
  }
}
