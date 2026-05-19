import 'package:flutter/material.dart';
import 'tabs/resident_home_tab.dart';
import 'tabs/resident_bookings_tab.dart';
import 'tabs/resident_profile_tab.dart';
import '../services/theme_service.dart';

class ResidentDashboard extends StatefulWidget {
  final Function(BuildContext) onLogout; // Callback for logging out
  final Map<String, dynamic>? userData; // User data from server

  const ResidentDashboard({super.key, required this.onLogout, this.userData});

  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final ThemeService _themeService = ThemeService();
  bool _isDarkMode = false;
  
  @override
  void initState() {
    super.initState();
    _themeService.addListener(() {
      setState(() {
        _isDarkMode = _themeService.isDarkMode;
      });
    });
    _isDarkMode = _themeService.isDarkMode;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ResidentHomeTab(userData: widget.userData, isDarkMode: _isDarkMode),
      ResidentBookingsTab(userData: widget.userData, isDarkMode: _isDarkMode),
      ResidentProfileTab(
        userData: widget.userData,
        onLogout: widget.onLogout,
        isDarkMode: _isDarkMode,
      ), 
    ];

    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          // If not on Home tab, navigate to Home tab
          setState(() {
            _currentIndex = 0;
            _pageController.jumpToPage(0);
          });
          return false; // Prevent default back behavior
        } else {
          // If on Home tab, show logout confirmation dialog
          return await _showLogoutConfirmationDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Resident Page"),
          automaticallyImplyLeading: false,
          elevation: 1,
          backgroundColor: _isDarkMode ? Colors.grey.shade900 : Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                _themeService.toggleTheme();
              },
              tooltip: 'Toggle Dark Mode',
            ),
          ],
        ),
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          children: pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: _isDarkMode ? Colors.blue.shade300 : Colors.blue,
          unselectedItemColor: _isDarkMode ? Colors.grey.shade500 : Colors.grey,
          backgroundColor: _isDarkMode ? Colors.grey.shade900 : Colors.white,
          onTap: (index) {
            _pageController.jumpToPage(index);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: 'My Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showTutorialDialog,
          backgroundColor: _isDarkMode ? Colors.grey.shade700 : Colors.orange,
          foregroundColor: Colors.white,
          mini: true,
          child: const Icon(Icons.help_outline),
          tooltip: 'Tutorial',
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      ),
    );
  }

  void _showTutorialDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.school,
                      color: Colors.orange,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'How to Use the App',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: Colors.grey,
                      iconSize: 28,
                    ),
                  ],
                ),
                const Divider(height: 28),
                
                // Tutorial Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTutorialSection(
                          '🏠 Home Tab - Your Starting Point',
                          '• This is the first screen you see when you open the app\n'
                          '• Look for your name and verification status at the top\n'
                          '• Your discount (if any) will be shown clearly\n'
                          '• Scroll down to see all available facilities like:\n'
                          '  - Basketball Court, Covered Court, Multi-Purpose Hall\n'
                          '• Tap on any facility to start booking it\n'
                          '• Recent bookings appear here for quick access',
                        ),
                        _buildTutorialSection(
                          '📋 My Bookings Tab - Track Your Requests',
                          '• See ALL your booking requests in one place\n'
                          '• Each booking shows its status with clear colors:\n'
                          '  🟡 PENDING = Still waiting for approval\n'
                          '  🟢 APPROVED = Your booking is confirmed\n'
                          '  🔴 REJECTED = Your booking was not approved\n'
                          '• 📊 NEW: Use filters to find specific bookings:\n'
                          '  - Filter by status (Pending, Approved, Rejected)\n'
                          '  - Filter by facility (Basketball, Court, Hall)\n'
                          '  - Search by name or email\n'
                          '  - Sort by submission or booking date\n'
                          '• To upload payment receipts:\n'
                          '  1. Find your booking in the list\n'
                          '  2. Tap "Upload Receipt"\n'
                          '  3. Take a photo or select from gallery\n'
                          '  4. Make sure the receipt photo is clear and readable\n'
                          '• You can cancel bookings that are still pending',
                        ),
                        _buildTutorialSection(
                          '👤 Profile Tab - Your Personal Information',
                          '• This is where you manage your account details\n'
                          '• To update your information:\n'
                          '  1. Tap the edit button (pencil icon)\n'
                          '  2. Type your correct information\n'
                          '  3. Scroll down and tap "Save"\n'
                          '• To change your profile photo:\n'
                          '  1. Tap on your current photo\n'
                          '  2. Choose "Take Photo" or "Select from Gallery"\n'
                          '  3. Adjust the photo if needed\n'
                          '  4. Tap "Confirm" to save\n'
                          '• Your verification type and discount rate are shown here\n'
                          '• Use the logout button at the bottom when done',
                        ),
                        _buildTutorialSection(
                          '🎯 Complete Booking Process - Step by Step',
                          'Step 1: CHOOSE FACILITY\n'
                          '  • From Home tab, tap on the facility you want\n'
                          '  • Read the facility details and rates\n'
                          '\n'
                          'Step 2: PICK DATE AND TIME\n'
                          '  • Select the date you want to use the facility\n'
                          '  • Choose your preferred time slot\n'
                          '  • Green slots are available, red are taken\n'
                          '\n'
                          'Step 3: FILL THE BOOKING FORM\n'
                          '  • Your personal info will auto-fill if complete\n'
                          '  • Double-check all information is correct\n'
                          '  • Add any special requests or notes\n'
                          '\n'
                          'Step 4: PAYMENT AND RECEIPT\n'
                          '  • Pay the required amount (shown on screen)\n'
                          '  • Take a clear photo of the payment receipt\n'
                          '  • Make sure receipt details are readable\n'
                          '  • Upload the receipt immediately\n'
                          '\n'
                          'Step 5: WAIT FOR APPROVAL\n'
                          '  • Your booking will show as "PENDING"\n'
                          '  • Check back regularly for status updates\n'
                          '  • Approved bookings are ready to attend!',
                        ),
                        _buildTutorialSection(
                          '💡 Important Tips for Elderly Users',
                          '🔍 READING THE SCREEN:\n'
                          '• Use two fingers to zoom in if text is too small\n'
                          '• Hold your phone at a comfortable distance\n'
                          '• Take breaks if your eyes feel tired\n'
                          '\n'
                          '📸 TAKING PHOTOS:\n'
                          '• Ensure good lighting when taking receipt photos\n'
                          '• Hold the camera steady for clear pictures\n'
                          '• Ask for help if you\'re unsure about photo quality\n'
                          '\n'
                          '💾 SAVING YOUR WORK:\n'
                          '• Always tap "Save" or "Submit" when finished\n'
                          '• The app will confirm when your booking is sent\n'
                          '• Check your email for confirmation messages\n'
                          '\n'
                          '🆘 GETTING HELP:\n'
                          '• Contact barangay officials for assistance\n'
                          '• Ask family members to help with the app\n'
                          '• Practice using the app with someone nearby\n'
                          '• Don\'t hesitate to ask questions',
                        ),
                        _buildTutorialSection(
                          '⚠️ Important Reminders',
                          '• Book facilities at least 1 day in advance\n'
                          '• Upload payment receipts immediately after payment\n'
                          '• Check your booking status before going to the facility\n'
                          '• Bring a copy of your approved booking on the day\n'
                          '• Cancel bookings early if you can\'t make it\n'
                          '• Keep your contact information updated\n'
                          '• Report any problems with the app immediately',
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Footer
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Got it!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTutorialSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[700],
            height: 1.6,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<bool> _showLogoutConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Cancel
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // OK
                widget.onLogout(context); // Call logout callback
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    ) ?? false; // Default to false if dialog is dismissed
  }
}
