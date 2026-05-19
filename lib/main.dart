import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'utils/debug_logger.dart';
import 'services/auth_api_service.dart';
import 'services/ban_detection_service.dart';
import 'services/persistent_auth_service.dart';
import 'screens/selection_screen.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Using computer IP from server log
    DebugLogger.ui('Using computer IP for development');
    DebugLogger.ui('Server URL: ${AppConfig.baseUrl}');
    DebugLogger.ui('Computer IP server ready for barangay operations');
    
    // Check persistent login state on app start
    await _initializePersistentAuth();
    DebugLogger.ui('Persistent authentication initialized');
  } catch (e) {
    DebugLogger.error('Initialization error: $e');
  }
  
  runApp(const MyApp());
}

// Initialize persistent authentication
Future<void> _initializePersistentAuth() async {
  try {
    // Check if user is already logged in on this device
    final isLoggedIn = await PersistentAuthService.isUserLoggedIn();
    
    if (isLoggedIn) {
      final currentUser = await PersistentAuthService.getCurrentUser();
      final deviceId = await PersistentAuthService.getDeviceId();
      DebugLogger.ui(' User already logged in on device: $deviceId');
      DebugLogger.ui(' User email: ${currentUser?['email']}');
      
      // Initialize AuthApiService with existing session
      await AuthApiService.instance.initializeUser();
    } else {
      DebugLogger.ui(' No persistent login found, showing selection screen');
    }
  } catch (e) {
    DebugLogger.error('Persistent auth initialization error: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barangay Reserve System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: SelectionScreen(
        navigatorKey: GlobalKey<NavigatorState>(), // Pass navigator key to selection screen
      ),
    );
  }
}

/// Shared enum for account type
enum AccountType { resident, official }
