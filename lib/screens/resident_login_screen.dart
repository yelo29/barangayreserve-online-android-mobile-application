import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_api_service.dart';
import '../services/data_service.dart';
import '../services/google_auth_service.dart';
import '../services/persistent_auth_service.dart';
import '../dashboard/resident_dashboard.dart';
import '../screens/selection_screen.dart';
import '../screens/email_verification_screen.dart';
import '../screens/profile_configuration_screen.dart';

class ResidentLoginScreen extends StatefulWidget {
  const ResidentLoginScreen({super.key});

  @override
  State<ResidentLoginScreen> createState() => _ResidentLoginScreenState();
}

class _ResidentLoginScreenState extends State<ResidentLoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _registerWithGmail() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Use Gmail authentication with REGISTER endpoint
      final result = await GoogleAuthService.signInWithGoogle('/api/auth/google-register');
      
      if (result['success'] == true) {
        final userData = result['user'];
        final token = result['token'];
        
        // New user - save login state and navigate to Resident Access screen
        await PersistentAuthService.saveLoginState(userData, token);
        
        if (mounted) {
          // Show success message and redirect to Resident Access screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Please login to continue.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Navigate back to Resident Access screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const ResidentLoginScreen(),
            ),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = result['message'] ?? 'Gmail registration failed';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gmail registration error: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGmail() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Use Gmail authentication with LOGIN endpoint
      final result = await GoogleAuthService.signInWithGoogle('/api/auth/google-login');
      
      if (result['success'] == true) {
        final userData = result['user'];
        final token = result['token'];
        final hasCompleteProfile = result['has_complete_profile'] ?? false;
        
        if (hasCompleteProfile) {
          // User has complete profile - login directly
          await PersistentAuthService.saveLoginState(userData, token);
          
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => ResidentDashboard(
                  onLogout: (context) => _logout(context),
                  userData: userData,
                ),
              ),
              (route) => false,
            );
          }
        } else {
          // User has incomplete profile - redirect to profile configuration
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileConfigurationScreen(
                  userData: userData,
                  token: token,
                ),
              ),
              (route) => false,
            );
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = result['message'] ?? 'Gmail login failed';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gmail login error: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _logout(BuildContext context) async {
    try {
      print('🔥 ResidentLoginScreen logout - clearing authentication data');
      
      // Sign out from Google to force account selection next time
      await GoogleAuthService.signOut();
      
      // Clear authentication data
      await AuthApiService.instance.signOut();
      await ApiService.clearUserData();
      
      // Navigate back to selection screen
      if (context.mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const SelectionScreen())
        );
      }
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFECACA), Color(0xFFDBEAFE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text("Resident Log-in/Sign-up",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 10)
                          ],
                        ),
                        child: Column(
                          children: [
                            // Logo and Title
                            const Icon(Icons.account_circle, size: 80, color: Colors.blue),
                            const SizedBox(height: 16),
                            const Text(
                              "Please select your preferred login method",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Choose how you want to access your account",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Error Message Display
                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  border: Border.all(color: Colors.red.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error, color: Colors.red.shade600, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Gmail Login Button
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _signInWithGmail,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.mail, size: 20),
                                label: const Text("Login with Gmail"),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Gmail Register Button
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.blue[600],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _registerWithGmail,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.person_add, size: 20),
                                label: const Text("Register with Gmail"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
