import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../services/data_service.dart';
import '../../../services/auth_api_service.dart';
import '../../../services/auto_refresh_service.dart';
import '../../../screens/resident_account_settings_new.dart';
import '../../../screens/resident_verification_new.dart';
import '../../../main.dart';

class ResidentProfileTab extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final Function(BuildContext) onLogout;
  final bool isDarkMode;
  
  const ResidentProfileTab({
    super.key, 
    this.userData,
    required this.onLogout,
    this.isDarkMode = false,
  });

  @override
  State<ResidentProfileTab> createState() => _ResidentProfileTabState();
}

class _ResidentProfileTabState extends State<ResidentProfileTab> with AutoRefreshMixin {
  Map<String, dynamic>? _currentUser;
  AuthApiService _authApiService = AuthApiService.instance;
  bool _isLoading = true;
  String? _profilePhotoUrl;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize auto-refresh for profile tab
    initAutoRefresh('user_profile');
    
    // Register refresh callback for profile updates
    registerRefreshCallback(() {
      if (mounted) {
        _loadUserData();
      }
    });
    
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Refresh cached user data when tab is accessed (like Account Settings does)
    if (mounted) {
      _refreshCachedUserData();
    }
  }

  Future<void> _refreshCachedUserData() async {
    try {
      print('🔄 ResidentProfileTab - Refreshing cached user data (like Account Settings)');
      await _authApiService.refreshCurrentUser();
      print('🔄 ResidentProfileTab - Cached data refreshed');
    } catch (e) {
      print('❌ ResidentProfileTab - Error refreshing cached data: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      // Use DataService for consistent user profile fetching
      final profileResponse = await DataService.fetchUserProfile();
      
      if (profileResponse['success'] == true) {
        final currentUser = profileResponse['data'];
        
        // Debug: Print the entire profile data structure
        print('🔍 DEBUG: Profile response data structure:');
        print('🔍 DEBUG: Full data: $currentUser');
        if (currentUser is Map) {
          print('🔍 DEBUG: Available fields: ${currentUser.keys.toList()}');
          print('🔍 DEBUG: profile_photo_url field exists: ${currentUser.containsKey('profile_photo_url')}');
          print('🔍 DEBUG: profile_photo_url value: ${currentUser['profile_photo_url']}');
        }
        
        // Also get current user data from AuthApiService for consistency
        final authUser = await _authApiService.getCurrentUser();
        
        setState(() {
          _currentUser = authUser ?? currentUser;
          _isLoading = false;
        });
        
        print('🔍 ResidentProfileTab - User profile loaded from DataService: $currentUser');
        print('🔍 ResidentProfileTab - Verified status: ${_currentUser?['verified']}');
        print('🔍 ResidentProfileTab - Discount rate: ${_currentUser?['discount_rate']}');
        
        // Load profile photo using same method as Account Settings (from SharedPreferences cache)
        if (_currentUser != null) {
          _profilePhotoUrl = await _authApiService.getUserProfilePhoto();
          print('🔍 ResidentProfileTab - Profile photo URL from AuthApiService (same as Account Settings): $_profilePhotoUrl');
          
          // Also check if profile photo exists in user data for debugging
          final userPhotoUrl = _currentUser!['profile_photo_url'];
          print('🔍 ResidentProfileTab - Profile photo URL from user data: $userPhotoUrl');
          print('🔍 ResidentProfileTab - Using cached photo (Account Settings method): ${_profilePhotoUrl?.isNotEmpty ?? false}');
        }
        
        print('🔍 ResidentProfileTab - isVerifiedResident: ${_authApiService.isVerifiedResident()}');
        print('🔍 ResidentProfileTab - isVerifiedNonResident: ${_authApiService.isVerifiedNonResident()}');
      } else {
        // Fallback to AuthApiService if DataService fails
        await _authApiService.restoreUserFromToken();
        final currentUser = await _authApiService.getCurrentUser();
        setState(() {
          _currentUser = currentUser;
          _isLoading = false;
        });
        
        // Load profile photo using same method as Account Settings (from SharedPreferences cache)
        if (_currentUser != null) {
          _profilePhotoUrl = await _authApiService.getUserProfilePhoto();
          print('🔍 ResidentProfileTab - Profile photo URL from AuthApiService (fallback): $_profilePhotoUrl');
        }
        
        print('🔍 ResidentProfileTab - Fallback to AuthApiService: $currentUser');
      }
    } catch (e) {
      print('❌ ResidentProfileTab - Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Refresh data method
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Reload user data
    await _loadUserData();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? Colors.grey.shade800 : Colors.blue,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.isDarkMode ? Colors.grey.shade700 : Colors.white,
                              border: Border.all(color: widget.isDarkMode ? Colors.grey.shade600 : Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: (_profilePhotoUrl?.isNotEmpty == true ||
                                    _currentUser?['profile_photo_url']?.isNotEmpty == true ||
                                    _currentUser?['profilePhotoUrl']?.isNotEmpty == true ||
                                    _currentUser?['profilePhoto']?.isNotEmpty == true ||
                                    _currentUser?['profile_image']?.isNotEmpty == true ||
                                    _currentUser?['profileImage']?.isNotEmpty == true ||
                                    _currentUser?['avatar']?.isNotEmpty == true ||
                                    _currentUser?['photo_url']?.isNotEmpty == true ||
                                    _currentUser?['imageUrl']?.isNotEmpty == true)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: _buildBase64Image(
                                    _profilePhotoUrl ??
                                    _currentUser!['profile_photo_url'] ?? 
                                    _currentUser!['profilePhotoUrl'] ?? 
                                    _currentUser!['profilePhoto'] ??
                                    _currentUser!['profile_image'] ??
                                    _currentUser!['profileImage'] ??
                                    _currentUser!['avatar'] ??
                                    _currentUser!['photo_url'] ??
                                    _currentUser!['imageUrl']
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 40,
                                  color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _authApiService.getUserFullName(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentUser?['email'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_authApiService.isUserVerified())
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _authApiService.isVerifiedResident() 
                                          ? 'Verified Resident' 
                                          : 'Verified Non-Resident',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Refresh button
                      IconButton(
                        onPressed: _refreshData,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        tooltip: 'Refresh Profile',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Profile Options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Account Settings
                  _buildProfileOption(
                    icon: Icons.settings,
                    title: 'Account Settings',
                    subtitle: 'Update your profile information',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ResidentAccountSettingsScreen(
                            userData: widget.userData,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Account Verification
                  _buildProfileOption(
                    icon: Icons.verified_user,
                    title: 'Account Verification',
                    subtitle: _authApiService.isVerifiedResident() 
                        ? 'Already verified as Barangay Resident (10% discount)' 
                        : (_authApiService.isVerifiedNonResident()
                            ? 'Verified as Non-Resident (5% discount) - Tap to upgrade'
                            : 'Get verified for discount benefits'),
                    onTap: () {
                      // Allow ALL users to access verification screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ResidentVerificationScreen(
                            userData: _currentUser,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      ).then((_) {
                        // Refresh user data when returning from verification screen
                        _loadUserData();
                      });
                    },
                  ),

                  const SizedBox(height: 32),

                  // Simple Logout Button
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoggingOut ? null : () {
                        print('🔥 Logout button pressed - using official logout method');
                        setState(() {
                          _isLoggingOut = true;
                        });
                        widget.onLogout(context);
                        // Reset the flag after a delay to allow future logouts
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) {
                            setState(() {
                              _isLoggingOut = false;
                            });
                          }
                        });
                      },
                      icon: _isLoggingOut 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.logout),
                      label: Text(_isLoggingOut ? 'Logging out...' : 'Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isDarkMode ? Colors.red.shade700 : Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.blue.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? Colors.grey.shade700 : Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: widget.isDarkMode ? Colors.blue.shade300 : Colors.blue[600],
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: widget.isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: widget.isDarkMode ? Colors.blue.shade300 : Colors.blue[600],
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showCustomerService() {
   
  }

  Widget _buildBase64Image(String base64String) {
    try {
      // Remove data URL prefix if present
      String cleanBase64 = base64String;
      if (base64String.startsWith('data:image/')) {
        cleanBase64 = base64String.split(',')[1];
      }
      
      final decodedBytes = base64Decode(cleanBase64);
      return Image.memory(
        decodedBytes,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading profile image: $error');
          return Icon(Icons.person, size: 40, color: Colors.blue[600]);
        },
      );
    } catch (e) {
      print('❌ Error decoding base64 image: $e');
      return Icon(Icons.person, size: 40, color: Colors.blue[600]);
    }
  }
}
