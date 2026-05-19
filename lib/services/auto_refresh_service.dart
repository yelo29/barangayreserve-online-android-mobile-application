import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'auth_api_service.dart';
import '../services/api_service.dart';

class AutoRefreshService {
  static final AutoRefreshService _instance = AutoRefreshService._internal();
  factory AutoRefreshService() => _instance;
  AutoRefreshService._internal();

  final Map<String, StreamController<Map<String, dynamic>>> _refreshControllers = {};
  final Map<String, VoidCallback> _refreshCallbacks = {};
  
  /// Register a refresh callback for a specific screen/component
  void registerRefreshCallback(String componentId, VoidCallback callback) {
    _refreshCallbacks[componentId] = callback;
    print('🔄 Registered refresh callback for: $componentId');
  }
  
  /// Unregister a refresh callback
  void unregisterRefreshCallback(String componentId) {
    _refreshCallbacks.remove(componentId);
    print('🔄 Unregistered refresh callback for: $componentId');
  }
  
  /// Get a stream for refresh events
  Stream<Map<String, dynamic>> getRefreshStream(String componentId) {
    _refreshControllers.putIfAbsent(componentId, () => StreamController<Map<String, dynamic>>.broadcast());
    return _refreshControllers[componentId]!.stream;
  }
  
  /// Trigger auto-refresh based on API response refresh_data
  Future<void> triggerAutoRefresh(Map<String, dynamic> refreshData) async {
    print('🔄 Auto-refresh triggered: ${refreshData['trigger']}');
    
    final String trigger = refreshData['trigger'] ?? 'unknown';
    final List<String> requiresRefresh = List<String>.from(refreshData['requires_refresh'] ?? []);
    
    // Execute refresh callbacks for each required component
    for (String component in requiresRefresh) {
      if (_refreshCallbacks.containsKey(component)) {
        print('🔄 Executing refresh for: $component');
        _refreshCallbacks[component]!();
        
        // Send refresh event to stream
        if (_refreshControllers.containsKey(component)) {
          _refreshControllers[component]!.add({
            'trigger': trigger,
            'timestamp': refreshData['timestamp'],
            'data': refreshData,
          });
        }
      } else {
        print('⚠️ No refresh callback registered for: $component');
      }
    }
    
    // Handle special cases
    await _handleSpecialRefreshCases(refreshData);
  }
  
  /// Handle refresh based on trigger type
  Future<void> _handleSpecialRefreshCases(Map<String, dynamic> refreshData) async {
    final String trigger = refreshData['trigger'] ?? '';
    
    print('🔄 Auto-refresh triggered: $trigger');
    
    switch (trigger) {
      case 'booking_created':
        await _handleBookingCreatedRefresh(refreshData);
        break;
      case 'booking_updated':
        _handleBookingUpdatedRefresh(refreshData);
        break;
      case 'booking_cancelled':
        _handleBookingCancelledRefresh(refreshData);
        break;
      case 'profile_updated':
        _handleProfileUpdatedRefresh(refreshData);
        break;
      case 'verification_submitted':
        _handleVerificationSubmittedRefresh(refreshData);
        break;
    }
  }
  
  /// Handle booking creation refresh with cross-implications
  Future<void> _handleBookingCreatedRefresh(Map<String, dynamic> refreshData) async {
    final String facilityId = refreshData['facility_id']?.toString() ?? '';
    final String bookingDate = refreshData['booking_date'] ?? '';
    final String user_email = refreshData['user_email'] ?? '';
    
    print('🔄 Handling booking creation refresh:');
    print('  - Facility ID: $facilityId');
    print('  - Booking Date: $bookingDate');
    print('  - User Email: $user_email');
    
    // Check if this is a conflict notification for current user
    if (refreshData.containsKey('conflict_notification')) {
      final conflictNotification = refreshData['conflict_notification'];
      await _handleConflictNotification(conflictNotification);
    }
    
    // If there are rejected bookings, trigger additional refreshes
    if (refreshData.containsKey('rejected_bookings')) {
      final List<dynamic> rejectedBookings = refreshData['rejected_bookings'];
      print('🔄 Refreshing for ${rejectedBookings.length} rejected bookings');
      
      for (var rejectedBooking in rejectedBookings) {
        final String residentEmail = rejectedBooking['resident_email'] ?? '';
        if (residentEmail.isNotEmpty) {
          // Trigger refresh for affected residents
          _refreshCallbacks['resident_notifications']?.call();
        }
      }
    }
    
    // Trigger general booking-related callbacks
    _refreshCallbacks['booking_created']?.call();
    _refreshCallbacks['calendar_view']?.call();
    _refreshCallbacks['bookings_list']?.call();
    _refreshCallbacks['time_slots']?.call();
    
    // Trigger specific refresh targets
    final requiresRefresh = refreshData['requires_refresh'] as List<dynamic>? ?? [];
    for (final target in requiresRefresh) {
      _refreshCallbacks[target]?.call();
    }
  }

  // Handle conflict notifications
  Future<void> _handleConflictNotification(Map<String, dynamic> conflictNotification) async {
    print('🔄 AutoRefresh: Handling conflict notification');
    
    // Get current user email to check if this notification applies to them
    final currentUserEmail = await _getCurrentUserEmail();
    
    if (currentUserEmail != null && 
        conflictNotification['exclude_user'] != currentUserEmail) {
      
      // This is a conflict for another user, show notification
      _showConflictDialog(conflictNotification);
    }
  }

  // Get current user email (integrated with AuthApiService)
  Future<String?> _getCurrentUserEmail() async {
    try {
      final currentUser = await AuthApiService.instance.getCurrentUser();
      if (currentUser != null) {
        return currentUser['email'] as String?;
      }
    } catch (e) {
      print('❌ Error getting current user email: $e');
    }
    return null;
  }

  // Show conflict dialog
  void _showConflictDialog(Map<String, dynamic> conflictNotification) {
    print('🔄 AutoRefresh: Showing conflict dialog');
    
    // This will be handled by the UI layer
    // You can use a stream controller or callback system
    _conflictController.add(conflictNotification);
  }

  // Stream controller for conflict notifications
  final StreamController<Map<String, dynamic>> _conflictController = 
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream for conflict notifications
  Stream<Map<String, dynamic>> get conflictStream => _conflictController.stream;

  /// Handle booking update refresh
  void _handleBookingUpdatedRefresh(Map<String, dynamic> refreshData) {
    print('🔄 Handling booking update refresh');
    // Refresh booking details and status
    _refreshCallbacks['booking_details']?.call();
    _refreshCallbacks['bookings_list']?.call();
  }
  
  /// Handle booking cancellation refresh
  void _handleBookingCancelledRefresh(Map<String, dynamic> refreshData) {
    print('🔄 Handling booking cancellation refresh');
    // Refresh calendar availability and user bookings
    _refreshCallbacks['calendar_view']?.call();
    _refreshCallbacks['bookings_list']?.call();
    _refreshCallbacks['time_slots']?.call();
  }
  
  /// Handle profile update refresh
  void _handleProfileUpdatedRefresh(Map<String, dynamic> refreshData) {
    print('🔄 Handling profile update refresh');
    
    final List<String> updatedFields = List<String>.from(refreshData['updated_fields'] ?? []);
    
    // Refresh user data across all screens
    _refreshCallbacks['user_profile']?.call();
    _refreshCallbacks['account_settings']?.call();
    _refreshCallbacks['resident_dashboard']?.call();
    
    // If profile photo was updated, trigger additional refreshes
    if (updatedFields.contains('profile_photo_url')) {
      print('🔄 Profile photo updated - triggering photo-specific refreshes');
      _refreshCallbacks['profile_photo_display']?.call();
      _refreshCallbacks['official_profile']?.call();
    }
    
    // If name was updated, refresh displays that show user name
    if (updatedFields.contains('full_name')) {
      print('🔄 User name updated - refreshing name displays');
      _refreshCallbacks['user_name_display']?.call();
    }
  }
  
  /// Handle verification submission refresh
  void _handleVerificationSubmittedRefresh(Map<String, dynamic> refreshData) {
    print('🔄 Handling verification submission refresh');
    // Refresh verification status and lock state
    _refreshCallbacks['verification_status']?.call();
    _refreshCallbacks['profile_verification']?.call();
    _refreshCallbacks['account_settings']?.call();
  }
  
  /// Cleanup method to dispose all controllers
  void dispose() {
    for (var controller in _refreshControllers.values) {
      controller.close();
    }
    _refreshControllers.clear();
    _refreshCallbacks.clear();
    print('🔄 AutoRefreshService disposed');
  }
}

/// Mixin for widgets that need auto-refresh functionality
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> {
  late final String _refreshComponentId;
  StreamSubscription<Map<String, dynamic>>? _refreshSubscription;
  
  /// Initialize auto-refresh for this widget
  void initAutoRefresh(String componentId) {
    _refreshComponentId = componentId;
    
    // Register for refresh events
    _refreshSubscription = AutoRefreshService().getRefreshStream(componentId).listen((refreshData) {
      if (mounted) {
        onAutoRefresh(refreshData);
      }
    });
    
    print('🔄 Auto-refresh initialized for: $componentId');
  }
  
  /// Override this method to handle auto-refresh events
  void onAutoRefresh(Map<String, dynamic> refreshData) {
    // Default implementation - override in widgets
    print('🔄 Auto-refresh received in ${widget.runtimeType}: ${refreshData['trigger']}');
  }
  
  /// Register a refresh callback for this widget
  void registerRefreshCallback(VoidCallback callback) {
    AutoRefreshService().registerRefreshCallback(_refreshComponentId, callback);
  }
  
  /// Unregister refresh callback
  void unregisterRefreshCallback() {
    AutoRefreshService().unregisterRefreshCallback(_refreshComponentId);
  }
  
  @override
  void dispose() {
    _refreshSubscription?.cancel();
    AutoRefreshService().unregisterRefreshCallback(_refreshComponentId);
    super.dispose();
  }
}
