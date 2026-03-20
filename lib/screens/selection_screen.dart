import 'package:flutter/material.dart';
import '../dashboard/widgets/option_card.dart';
import '../services/permission_service.dart';
import '../services/ban_detection_service.dart';
import '../services/persistent_auth_service.dart';
import '../services/auth_api_service.dart';
import '../utils/debug_logger.dart';
import 'resident_auth_screen.dart';
import 'resident_login_screen.dart';
import 'official_login_screen.dart';
import '../config/app_config.dart';
import '../dashboard/resident_dashboard.dart';
import '../dashboard/barangay_official_dashboard.dart';

class SelectionScreen extends StatefulWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  
  const SelectionScreen({super.key, this.navigatorKey});

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  bool _isCheckingAuth = true;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    
    // Set navigator key for ban detection service
    if (widget.navigatorKey != null) {
      BanDetectionService.setNavigatorKey(widget.navigatorKey!);
    }
    
    _requestPermissions();
    _checkPersistentAuth();
  }

  // Check persistent authentication state
  Future<void> _checkPersistentAuth() async {
    try {
      setState(() => _isCheckingAuth = true);
      
      // Check if user is already logged in on this device
      final isLoggedIn = await PersistentAuthService.isUserLoggedIn();
      
      if (isLoggedIn) {
        final currentUser = await PersistentAuthService.getCurrentUser();
        final deviceId = await PersistentAuthService.getDeviceId();
        
        if (currentUser != null && mounted) {
          setState(() {
            _currentUser = currentUser;
            _isCheckingAuth = false;
          });
          
          print('User already logged in on device: $deviceId');
          print('User email: ${currentUser['email']}');
          
          // Navigate to appropriate dashboard based on user role
          final userRole = currentUser['role']?.toString() ?? 'resident';
          
          if (userRole == 'resident') {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ResidentDashboard(onLogout: _logout, userData: currentUser),
                ),
              );
            }
          } else if (userRole == 'official') {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => BarangayOfficialDashboard(onLogout: _logout),
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          setState(() => _isCheckingAuth = false);
        }
        print('No persistent login found, showing selection screen');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingAuth = false);
      }
      print('Persistent auth check error: $e');
    }
  }

  // Logout function
  void _logout(BuildContext context) async {
    print('🔥 LOGOUT STARTED: Beginning logout process');
    
    try {
      // Sign out from AuthApiService (which also clears persistent login state)
      print('🔥 LOGOUT: Calling AuthApiService.signOut()');
      await AuthApiService.instance.signOut();
      print('🔥 LOGOUT: AuthApiService.signOut() completed');
      
      // Navigate without mounted check to ensure it happens
      print('🔥 LOGOUT: Starting navigation to SelectionScreen');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SelectionScreen()),
        (route) => false, // Remove all routes
      );
      print('🔥 LOGOUT: Navigation command executed');
    } catch (e) {
      print('🔥 LOGOUT ERROR: $e');
      // Still try to navigate even if there's an error
      try {
        print('🔥 LOGOUT: Attempting fallback navigation');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SelectionScreen()),
          (route) => false, // Remove all routes
        );
        print('🔥 LOGOUT: Fallback navigation executed');
      } catch (navError) {
        print('🔥 LOGOUT NAVIGATION ERROR: $navError');
      }
    }
  }

  Future<void> _requestPermissions() async {
    // Request permissions after a short delay to allow UI to render
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        PermissionService.requestAllPermissions(context);
      }
    });
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
        child: Center(
          child: _isCheckingAuth
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                        child: CircularProgressIndicator(color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Checking authentication...",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
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
                      const SizedBox(height: 24),

                      // Welcome message
                      Text(
                        "Welcome to Barangay Reserve",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // User info display (if logged in)
                      if (_currentUser != null) ...[
                        Text(
                          "Logged in as: ${_currentUser!['email']}",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Tap to continue to dashboard",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Logout button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _logout(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Logout'),
                          ),
                        ),
                      ],

                      // Resident option
                      OptionCard(
                        title: "Resident",
                        description: "Book facilities and submit requests",
                        icon: "👤",
                        borderColor: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResidentLoginScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Official option
                      OptionCard(
                        title: "Barangay Official",
                        description: "Manage bookings and approve requests",
                        icon: "👨‍💼",
                        borderColor: Colors.red,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OfficialLoginScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
        ),
      ),
      ),
    );
  }
}
