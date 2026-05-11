import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '76487079151-p7608h6s43n8qsgq9ouq2ghofa6a1boe.apps.googleusercontent.com',
    serverClientId: '76487079151-dfcdf8hos5fqnfm8b3e9irrcqvqqa13d.apps.googleusercontent.com',
    scopes: [
      'email',
      'profile',
    ],
  );

  static GoogleSignInAccount? _currentUser;
  static bool _isInitialized = false;

  // Initialize Google Sign-In
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _googleSignIn.signInSilently();
      _currentUser = _googleSignIn.currentUser;
      _isInitialized = true;
      print('✅ GoogleAuthService initialized');
    } catch (e) {
      print('❌ GoogleAuthService initialization error: $e');
      _isInitialized = true; // Prevent infinite retry
    }
  }

  // Get current user
  static GoogleSignInAccount? get currentUser => _currentUser;

  // Check if user is signed in
  static bool get isSignedIn => _currentUser != null;

  // Sign in with Google
  static Future<Map<String, dynamic>> signIn() async {
    try {
      print('🔍 Starting Google Sign-In...');
      
      // Ensure initialization
      if (!_isInitialized) {
        await initialize();
      }
      
      // Sign in
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account != null) {
        _currentUser = account;
        
        // Get authentication tokens
        final GoogleSignInAuthentication auth = await account.authentication;
        
        // Create user data
        final userData = {
          'id': account.id,
          'email': account.email,
          'displayName': account.displayName ?? '',
          'photoUrl': account.photoUrl ?? '',
          'idToken': auth.idToken,
          'accessToken': auth.accessToken,
        };
        
        print('✅ Google Sign-In successful');
        print('🔍 User: ${account.email}');
        
        return {
          'success': true,
          'user': userData,
        };
      } else {
        return {
          'success': false,
          'message': 'Sign-in cancelled',
        };
      }
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      return {
        'success': false,
        'message': 'Google Sign-In failed: ${e.toString()}',
      };
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      print('🔍 Signing out from Google...');
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect(); // Complete disconnect to clear cache
      _currentUser = null;
      print('✅ Google Sign-Out successful');
    } catch (e) {
      print('❌ Google Sign-Out error: $e');
    }
  }

  // Get authentication headers for API calls
  static Future<Map<String, String>> getAuthHeaders() async {
    if (_currentUser != null) {
      final GoogleSignInAuthentication auth = await _currentUser!.authentication;
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${auth.idToken}',
      };
    }
    return {
      'Content-Type': 'application/json',
    };
  }

  // Verify token with backend using specific endpoint
  static Future<Map<String, dynamic>> verifyTokenWithBackend(String idToken, String endpoint) async {
    try {
      print('🔍 Verifying token with backend using endpoint: $endpoint...');
      
      final response = await http.post(
        Uri.parse('https://barangayreserve.dpdns.org$endpoint'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'idToken': idToken,
          'email': _currentUser?.email,
        }),
      );

      print('🔍 Backend response status: ${response.statusCode}');
      print('🔍 Backend response body: ${response.body}');

      // Parse response for success (200), conflict (409), and not found (404) status codes
      if (response.statusCode == 200 || response.statusCode == 409 || response.statusCode == 404) {
        try {
          final data = json.decode(response.body);
          
          // Check if user is banned BEFORE returning success
          if (data['success'] == true && data['user'] != null) {
            final userEmail = data['user']['email'];
            print('🔍 Checking ban status for user: $userEmail');
            
            // Check server-side ban status
            final banResponse = await http.get(
              Uri.parse('https://barangayreserve.dpdns.org/api/users/status/$userEmail'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
            );
            
            if (banResponse.statusCode == 200) {
              final banStatus = json.decode(banResponse.body);
              if (banStatus['is_banned'] == true) {
                print('🚨 User is banned - blocking login');
                return {
                  'success': false,
                  'error_type': 'user_banned',
                  'message': 'Account is banned. ${banStatus['ban_reason'] ?? 'Cannot login.'}',
                  'ban_reason': banStatus['ban_reason'],
                };
              }
              print('✅ User is not banned - login allowed');
            } else {
              print('⚠️ Could not verify ban status - proceeding with login (fail-safe)');
            }
          }
          
          return data;
        } catch (e) {
          return {
            'success': false,
            'message': 'Invalid response format: ${response.body}',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Backend verification failed with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Backend verification error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Complete sign-in flow with backend verification
  static Future<Map<String, dynamic>> completeSignIn() async {
    return await signInWithGoogle('/api/auth/google-login');
  }

  // Sign-in with specific endpoint (login or register)
  static Future<Map<String, dynamic>> signInWithGoogle(String endpoint) async {
    try {
      // Clear any existing session completely
      try {
        await _googleSignIn.signOut();
        await _googleSignIn.disconnect();
      } catch (e) {
        print('⚠️ Clearing session: $e');
      }
      
      // Wait a moment for cleanup
      await Future.delayed(Duration(milliseconds: 500));
      
      // First, sign in with Google
      final signInResult = await signIn();
      
      if (!signInResult['success']) {
        return signInResult;
      }
      
      final userData = signInResult['user'];
      final idToken = userData['idToken'];

      if (idToken == null) {
        return {
          'success': false,
          'message': 'Failed to get ID token from Google',
        };
      }

      // Verify with backend using specified endpoint
      final backendResult = await verifyTokenWithBackend(idToken, endpoint);
      
      if (backendResult['success'] == true) {
        return {
          'success': true,
          'user': backendResult['user'],
          'token': backendResult['token'],
          'googleUser': userData,
          'is_existing_user': backendResult['is_existing_user'] ?? false,
          'has_complete_profile': backendResult['has_complete_profile'] ?? false,
        };
      } else {
        return {
          'success': false,
          'message': backendResult['message'] ?? 'Backend verification failed',
        };
      }
    } catch (e) {
      print('❌ Google sign-in error: $e');
      return {
        'success': false,
        'message': 'Sign-in process failed: ${e.toString()}',
      };
    }
  }
}
