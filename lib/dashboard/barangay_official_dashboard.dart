import 'package:flutter/material.dart';
import 'tabs/official/official_home_tab.dart';
import 'tabs/official/official_booking_requests_tab.dart';
import 'tabs/official/authentication_requests_tab.dart';
import 'tabs/official/official_profile_tab.dart';
import '../services/theme_service.dart';

class BarangayOfficialDashboard extends StatefulWidget {
  final Function(BuildContext) onLogout;

  const BarangayOfficialDashboard({super.key, required this.onLogout});

  @override
  State<BarangayOfficialDashboard> createState() => _BarangayOfficialDashboardState();
}

class _BarangayOfficialDashboardState extends State<BarangayOfficialDashboard> {
  int _selectedIndex = 0;
  final ThemeService _themeService = ThemeService();
  bool _isDarkMode = false;

  List<Widget> _widgetOptions() => <Widget>[
    OfficialHomeTab(isDarkMode: _isDarkMode),
    OfficialBookingRequestsTab(isDarkMode: _isDarkMode),
    OfficialAuthenticationTab(userData: {}, isDarkMode: _isDarkMode),
    OfficialProfileTab(onLogout: widget.onLogout, isDarkMode: _isDarkMode),
  ];

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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          // If not on Home tab, navigate to Home tab
          setState(() {
            _selectedIndex = 0;
          });
          return false; // Prevent default back behavior
        } else {
          // If on Home tab, show logout confirmation dialog
          return await _showLogoutConfirmationDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Barangay Official Dashboard'),
          backgroundColor: _isDarkMode ? Colors.grey.shade900 : Colors.red,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
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
        body: _widgetOptions().elementAt(_selectedIndex),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: _isDarkMode ? Colors.grey.shade900 : Colors.white,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pending_actions),
              label: 'Requests',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.verified_user),
              label: 'Auth',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: _isDarkMode ? Colors.red.shade300 : Colors.red,
          unselectedItemColor: _isDarkMode ? Colors.grey.shade500 : Colors.grey,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Future<bool> _showLogoutConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? Colors.grey.shade800 : Colors.white,
          title: Text('Confirm Logout', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87)),
          content: Text('Are you sure you want to logout?', style: TextStyle(color: _isDarkMode ? Colors.grey.shade300 : Colors.black87)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Cancel
              },
              child: Text('Cancel', style: TextStyle(color: _isDarkMode ? Colors.grey.shade300 : Colors.black87)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // OK
                widget.onLogout(context); // Call logout callback
              },
              child: Text('OK', style: TextStyle(color: _isDarkMode ? Colors.grey.shade300 : Colors.black87)),
            ),
          ],
        );
      },
    ) ?? false; // Default to false if dialog is dismissed
  }
}
