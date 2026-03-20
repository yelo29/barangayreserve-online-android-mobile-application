import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/google_auth_service.dart';
import '../services/persistent_auth_service.dart';
import '../services/auth_api_service.dart';
import '../dashboard/resident_dashboard.dart';
import '../utils/debug_logger.dart';
import 'selection_screen.dart';

class ResidentAuthScreen extends StatefulWidget {
  const ResidentAuthScreen({super.key});

  @override
  State<ResidentAuthScreen> createState() => _ResidentAuthScreenState();
}

class _ResidentAuthScreenState extends State<ResidentAuthScreen> {
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _initializeGoogleAuth();
  }

  Future<void> _initializeGoogleAuth() async {
    try {
      await GoogleAuthService.initialize();
    } catch (e) {
      DebugLogger.log('Google Auth initialization error: $e');
    }
  }

  Future<void> _handleGmailAuth(bool isRegistration) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      DebugLogger.log('Starting Gmail authentication...');
      
      // Complete sign-in with backend verification
      final result = await GoogleAuthService.completeSignIn();
      
      if (result['success'] == true) {
        final userData = result['user'];
        final token = result['token'];
        final googleUser = result['googleUser'];
        final isExistingUser = result['is_existing_user'] ?? false;
        
        DebugLogger.log('Gmail auth successful');
        DebugLogger.log('User: ${userData['email']}');
        DebugLogger.log('Verified: ${userData['verified']}');
        DebugLogger.log('Is existing user: $isExistingUser');
        DebugLogger.log('Full result keys: ${result.keys.toList()}');
        
        // Show different message for existing vs new users
        if (isExistingUser) {
          DebugLogger.log('BLOCKING: User already exists - showing error message');
          setState(() {
            _errorMessage = 'Your account is already created. Please login instead.';
          });
          // Don't proceed - let user know they should use login
          DebugLogger.log('BLOCKING: Navigation prevented, user should see error message');
          return;
        }
        
        DebugLogger.log('ALLOWING: New user - proceeding with registration');
        
        // Save login state
        await PersistentAuthService.saveLoginState(userData, token);
        
        // Navigate to resident dashboard
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => ResidentDashboard(
                onLogout: _logout,
                userData: userData,
              ),
            ),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Authentication failed';
        });
      }
    } catch (e) {
      DebugLogger.log('Gmail auth error: $e');
      setState(() {
        _errorMessage = 'Authentication error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Logout function with BuildContext parameter
  void _logout(BuildContext context) async {
    // Prevent multiple simultaneous logout attempts
    if (_isLoggingOut) {
      print('🔥 LOGOUT: Already logging out - ignoring duplicate request');
      return;
    }
    
    _isLoggingOut = true;
    
    try {
      print('🔥 LOGOUT: Starting complete logout process...');
      
      // Sign out from all services
      await GoogleAuthService.signOut();
      print('🔥 LOGOUT: Google sign-out completed');
      
      await PersistentAuthService.clearLoginState();
      print('🔥 LOGOUT: Persistent auth state cleared');
      
      await AuthApiService.instance.signOut();
      print('🔥 LOGOUT: Auth API service signed out');
      
      // Clear all SharedPreferences to prevent stale data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('🔥 LOGOUT: All SharedPreferences cleared');
      
      print('🔥 LOGOUT: Widget mounted check: $mounted');
      
      if (mounted) {
        print('🔥 LOGOUT: Navigating to SelectionScreen...');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const SelectionScreen(),
          ),
          (route) => false,
        );
        print('🔥 LOGOUT: Navigation completed');
      } else {
        print('🔥 LOGOUT: Widget not mounted - cannot navigate');
        // Force navigation even if not mounted using a different approach
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const SelectionScreen(),
              ),
              (route) => false,
            );
            print('🔥 LOGOUT: Post-frame navigation completed');
          }
        });
      }
    } catch (e) {
      print('🔥 LOGOUT ERROR: $e');
      DebugLogger.log('Logout error: $e');
      
      // Try to navigate even on error
      try {
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const SelectionScreen(),
            ),
            (route) => false,
          );
          print('🔥 LOGOUT: Emergency navigation completed');
        }
      } catch (navError) {
        print('🔥 LOGOUT: Emergency navigation failed: $navError');
      }
    } finally {
      _isLoggingOut = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFDBEAFE), Color(0xFFFECACA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(230),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text("🏛️", style: TextStyle(fontSize: 56)),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    "Resident Access",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  const Text(
                    "Use your Gmail account to access barangay services",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Loading indicator
                  if (_isLoading) ...[
                    const SpinKitThreeBounce(
                      color: Colors.blue,
                      size: 50,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Authenticating with Gmail...",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ],

                  // Error message
                  if (_errorMessage.isNotEmpty && !_isLoading) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: TextStyle(
                                color: Colors.red.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Gmail Login Button
                  if (!_isLoading) ...[
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _handleGmailAuth(false),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google Logo
                                Text(
                                  "G",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4285F4),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  "Login with Gmail",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Gmail Registration Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF34A853), Color(0xFF4285F4)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _handleGmailAuth(true),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google Logo
                                Text(
                                  "G",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  "Register with Gmail",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Info text
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade600),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Gmail authentication provides automatic verification for barangay residents",
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "• No password required\n• Instant verification\n• Secure access",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
