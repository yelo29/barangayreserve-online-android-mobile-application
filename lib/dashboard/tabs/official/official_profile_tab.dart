import 'package:flutter/material.dart';
import '../../../services/data_service.dart';
import '../../../screens/official_account_settings_screen.dart';
import '../../../services/auth_api_service.dart';
import '../../../services/auto_refresh_service.dart';

class OfficialProfileTab extends StatefulWidget {
  final Function(BuildContext) onLogout;
  final bool isDarkMode;
  
  const OfficialProfileTab({super.key, required this.onLogout, this.isDarkMode = false});

  @override
  State<OfficialProfileTab> createState() => _OfficialProfileTabState();
}

class _OfficialProfileTabState extends State<OfficialProfileTab> with AutoRefreshMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  Map<String, dynamic>? _currentUser;
  final _authApiService = AuthApiService.instance;

  @override
  void initState() {
    super.initState();
    
    // Initialize auto-refresh for official profile tab
    initAutoRefresh('official_profile');
    
    // Register refresh callback for profile updates
    registerRefreshCallback(() {
      if (mounted) {
        _loadOfficialData();
      }
    });
    
    _loadOfficialData();
  }

  Future<void> _loadOfficialData() async {
    try {
      // Use AuthApiService for current user data (already logged in)
      final userData = await _authApiService.getCurrentUser();
      if (userData != null) {
        setState(() {
          _currentUser = userData;
          // Pre-fill form fields with current user data
          _nameController.text = userData['full_name'] ?? '';
          _contactController.text = userData['contact_number'] ?? '';
        });
        print('🔍 OfficialProfileTab - Official data loaded: $userData');
      }
    } catch (e) {
      print('❌ OfficialProfileTab - Error loading official data: $e');
    }
  }

  // Refresh data method
  Future<void> _refreshData() async {
    // Reload official data
    await _loadOfficialData();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Container(
      color: widget.isDarkMode ? Colors.grey.shade900 : Colors.white,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with Title and Refresh
              Row(
                children: [
                  Text(
                    'Account Settings',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  // Refresh button
                  IconButton(
                    onPressed: _refreshData,
                    icon: Icon(Icons.refresh, color: widget.isDarkMode ? Colors.white : Colors.black),
                    tooltip: 'Refresh',
                    iconSize: isSmallScreen ? 24 : 28,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Profile Header Card
              Card(
                color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OfficialAccountSettingsScreen(isDarkMode: widget.isDarkMode),
                      ),
                    ).then((_) {
                      // Refresh data when returning from settings
                      _loadOfficialData();
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 20, 
                      vertical: isSmallScreen ? 12 : 16
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: isSmallScreen ? 28 : 32,
                          backgroundColor: widget.isDarkMode ? Colors.grey.shade700 : Colors.pink.shade100,
                          child: Icon(
                            Icons.admin_panel_settings, 
                            color: widget.isDarkMode ? Colors.red.shade400 : Colors.red.shade700, 
                            size: isSmallScreen ? 28 : 32
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentUser?['full_name'] ?? 'Loading...',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 16 : 18,
                                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentUser?['email'] ?? 'Loading...',
                                style: TextStyle(
                                  color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                  fontSize: isSmallScreen ? 13 : 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: isSmallScreen ? 16 : 18,
                          color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),

              // Additional Information Card
              Card(
                color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Information',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Role Information
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.badge, 
                            color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                            size: isSmallScreen ? 20 : 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Role',
                                  style: TextStyle(
                                    color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                                    fontSize: isSmallScreen ? 12 : 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: widget.isDarkMode ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Barangay Official',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 13,
                                      fontWeight: FontWeight.w600,
                                      color: widget.isDarkMode ? Colors.red.shade400 : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Divider
                      Divider(
                        color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                        height: 1,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Contact Number Display
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.phone, 
                            color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                            size: isSmallScreen ? 20 : 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Contact Number',
                                  style: TextStyle(
                                    color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                                    fontSize: isSmallScreen ? 12 : 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentUser?['contact_number']?.isNotEmpty == true 
                                      ? _currentUser!['contact_number'] 
                                      : 'Not set',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 15,
                                    color: widget.isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    print('🔥 Official Logout button pressed - using resident logout method');
                    widget.onLogout(context);
                  },
                  icon: Icon(Icons.logout, size: isSmallScreen ? 20 : 24),
                  label: Text(
                    'Logout',
                    style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isDarkMode ? Colors.red.shade700 : Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              
              // Add bottom padding for better spacing
              SizedBox(height: isSmallScreen ? 16 : 24),
            ],
          ),
        ),
      ),
    );
  }
}