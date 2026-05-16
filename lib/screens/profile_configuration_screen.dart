import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_api_service.dart';
import '../services/data_service.dart';
import '../services/persistent_auth_service.dart';
import '../dashboard/resident_dashboard.dart';
import '../screens/resident_login_screen.dart';

class ProfileConfigurationScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;

  const ProfileConfigurationScreen({
    super.key,
    required this.userData,
    required this.token,
  });

  @override
  State<ProfileConfigurationScreen> createState() => _ProfileConfigurationScreenState();
}

class _ProfileConfigurationScreenState extends State<ProfileConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing data
    _nameController.text = widget.userData['full_name'] ?? '';
    _contactController.text = widget.userData['contact_number'] ?? '';
    _addressController.text = widget.userData['address'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Update user profile with explicit token from widget
      final response = await ApiService.updateUserProfileWithToken(
        widget.token,
        {
          'email': widget.userData['email'], // Add required email field
          'user_id': widget.userData['id'],
          'full_name': _nameController.text.trim(),
          'contact_number': _contactController.text.trim(),
          'address': _addressController.text.trim(),
        },
      );

      if (response['success']) {
        // Update local storage with new profile info
        final updatedUserData = Map<String, dynamic>.from(widget.userData);
        updatedUserData.addAll(response['user'] ?? {});
        
        // Save updated user data to SharedPreferences
        await PersistentAuthService.saveLoginState(updatedUserData, widget.token);

        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back to login screen
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
            _errorMessage = response['message'] ?? 'Failed to update profile';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error updating profile: ${e.toString()}';
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: isDarkMode ? Colors.grey.shade800 : const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade800 : const Color(0xFFE8F0FE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 50,
                    color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF1E3A8A),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Title
                Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E3A8A),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 10),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade800 : Colors.blue.shade50,
                    border: Border.all(color: isDarkMode ? Colors.grey.shade600 : Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade600,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Profile Setup Required',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.blue.shade300 : Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please provide your contact information to complete your profile setup.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey.shade300 : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.orange.shade900 : Colors.orange.shade50,
                          border: Border.all(color: isDarkMode ? Colors.orange.shade700 : Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.warning_amber_outlined,
                              color: isDarkMode ? Colors.orange.shade300 : Colors.orange.shade600,
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'IMPORTANT NOTICE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.orange.shade300 : Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• After saving your profile, you will be redirected to the login screen\n'
                              '• You must login again with your Gmail account\n'
                              '• Your completed profile will be available after login',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.grey.shade300 : Colors.black87,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Full Name Field
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    labelStyle: TextStyle(color: isDarkMode ? Colors.grey.shade400 : Colors.black87),
                    hintStyle: TextStyle(color: isDarkMode ? Colors.grey.shade500 : Colors.grey),
                    prefixIcon: Icon(Icons.person, color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF1E3A8A)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF1E3A8A), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (value.trim().length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Contact Number Field
                TextFormField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Contact Number',
                    hintText: 'Enter your contact number',
                    labelStyle: TextStyle(color: isDarkMode ? Colors.grey.shade400 : Colors.black87),
                    hintStyle: TextStyle(color: isDarkMode ? Colors.grey.shade500 : Colors.grey),
                    prefixIcon: Icon(Icons.phone, color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF1E3A8A)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF1E3A8A), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your contact number';
                    }
                    if (value.trim().length < 10) {
                      return 'Please enter a valid contact number';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Address Field
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Address',
                    hintText: 'Enter your complete address',
                    labelStyle: TextStyle(color: isDarkMode ? Colors.grey.shade400 : Colors.black87),
                    hintStyle: TextStyle(color: isDarkMode ? Colors.grey.shade500 : Colors.grey),
                    prefixIcon: Icon(Icons.location_on, color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF1E3A8A)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDarkMode ? Colors.blue.shade300 : const Color(0xFF1E3A8A), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your address';
                    }
                    if (value.trim().length < 10) {
                      return 'Please enter a complete address';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 40),
                
                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.red.shade900 : Colors.red.shade50,
                      border: Border.all(color: isDarkMode ? Colors.red.shade700 : Colors.red.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: isDarkMode ? Colors.red.shade300 : Colors.red.shade600, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: isDarkMode ? Colors.red.shade300 : Colors.red.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                // Save Profile Button
                Container(
                  width: double.infinity,
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveProfile,
                        icon: const Icon(Icons.save_alt, size: 20),
                        label: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Saving Profile...'),
                                ],
                              )
                            : const Text(
                                'Save Profile & Continue to Login',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? Colors.blue.shade700 : const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'After saving, you will be redirected to login screen',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
