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
    return Container(
      color: widget.isDarkMode ? Colors.grey.shade900 : Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Account Settings',
                style: TextStyle(
                  fontSize: 24,
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
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Profile Header
          Container(
            constraints: const BoxConstraints(minHeight: 100),
            child: Card(
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
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: widget.isDarkMode ? Colors.grey.shade700 : Colors.pink.shade100,
                        child: Icon(Icons.admin_panel_settings, color: widget.isDarkMode ? Colors.red.shade400 : Colors.red.shade700, size: 28),
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
                                fontSize: 16,
                                color: widget.isDarkMode ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentUser?['email'] ?? 'Loading...',
                              style: TextStyle(
                                color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button - Simple like resident
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                print('🔥 Official Logout button pressed - using resident logout method');
                widget.onLogout(context);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
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
        ],
      ),
    ),
    );
  }
}
