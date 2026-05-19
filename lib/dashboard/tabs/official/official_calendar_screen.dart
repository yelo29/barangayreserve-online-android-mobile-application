import 'package:flutter/material.dart';
import '../../../services/data_service.dart';
import '../../../widgets/enhanced_calendar.dart';
import '../../../screens/official_booking_form_screen.dart';

class OfficialCalendarScreen extends StatefulWidget {
  final Map<String, dynamic> facility;
  final bool isDarkMode;

  const OfficialCalendarScreen({
    super.key,
    required this.facility,
    this.isDarkMode = false,
  });

  @override
  State<OfficialCalendarScreen> createState() => _OfficialCalendarScreenState();
}

class _OfficialCalendarScreenState extends State<OfficialCalendarScreen> {
  List<Map<String, dynamic>> _pendingBookings = [];
  List<Map<String, dynamic>> _approvedBookings = [];
  bool _isLoading = true;
  Map<String, String>? _cachedBookingStatuses;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadBookingData();
  }

  Future<void> _loadBookingData() async {
    try {
      print('🔍 OfficialCalendarScreen._loadBookingData - fetching bookings for facility: ${widget.facility['id']}');

      // Get current user data
      _currentUser = await DataService.getCurrentUserData();
      
      final facilityId = widget.facility['id'];

      // Use DataService for consistent data fetching (officials see all bookings)
      final bookingsResponse = await DataService.fetchBookings();
      
      if (bookingsResponse['success'] == true) {
        final List<Map<String, dynamic>> allBookings = bookingsResponse['data'] ?? [];
        
        // Filter bookings for this specific facility
        final facilityBookings = allBookings.where((booking) => 
          booking['facility_id'] == facilityId
        ).toList();
        
        final pendingBookings = facilityBookings.where((booking) => 
          booking['status'] == 'pending'
        ).toList();
        
        final approvedBookings = facilityBookings.where((booking) => 
          booking['status'] == 'approved'
        ).toList();

        // TODO: Add events functionality to server

        print('🔍 OfficialCalendarScreen - pending bookings total: ${pendingBookings.length}');
        print('🔍 OfficialCalendarScreen - approved bookings total: ${approvedBookings.length}');

        setState(() {
          _pendingBookings = pendingBookings;
          _approvedBookings = approvedBookings;
          _isLoading = false;
          _cachedBookingStatuses = null; // Clear cache when data changes
        });
      } else {
        throw Exception(bookingsResponse['error'] ?? 'Failed to fetch bookings');
      }
    } catch (e) {
      print('❌ OfficialCalendarScreen._loadBookingData - Error: $e');
      if (mounted) {
        setState(() {
          _pendingBookings = [];
          _approvedBookings = [];
          _isLoading = false;
        });
      }
    }
  }

  Map<String, String> _buildBookingStatuses() {
    // Only build once and cache result
    if (_cachedBookingStatuses != null) {
      print('🔍 Using cached booking statuses: ${_cachedBookingStatuses!.length}');
      return _cachedBookingStatuses!;
    }

    final Map<String, String> statuses = {};

    // Add pending bookings
    for (final booking in _pendingBookings) {
      final date = booking['booking_date'] ?? booking['date'] ?? '';
      final formattedDate = _formatDateForCalendar(date);
      statuses[formattedDate] = 'pending';
      print('🔍 Adding pending date: $date -> $formattedDate');
    }

    // Add approved bookings (overrides pending if exists)
    for (final booking in _approvedBookings) {
      final date = booking['booking_date'] ?? booking['date'] ?? '';
      final formattedDate = _formatDateForCalendar(date);
      statuses[formattedDate] = 'approved';
      print('🔍 Adding approved date: $date -> $formattedDate');
    }

    // Cache the result
    _cachedBookingStatuses = statuses;

    print('🔍 OfficialCalendarScreen._buildBookingStatuses - total statuses: ${statuses.length}');
    print('🔍 Status map entries: ${statuses.entries.map((e) => '${e.key}: ${e.value}').toList()}');
    
    return statuses;
  }

  String _formatDateForCalendar(String dateStr) {
    try {
      final DateTime date = DateTime.parse(dateStr);
      // Use same format as enhanced calendar expects
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      print('❌ Error parsing date: $dateStr - $e');
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.grey.shade900 : Colors.white,
      appBar: AppBar(
        title: Text('${widget.facility['name']} Calendar'),
        backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Calendar
                Expanded(
                  child: EnhancedCalendar(
                    selectedDate: DateTime.now(),
                    onDateSelected: (selectedDate) {
                      // Navigate to official booking form instead of showing dialog
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OfficialBookingFormScreen(
                            facility: widget.facility,
                            selectedDate: selectedDate,
                            userData: _currentUser,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      );
                    },
                    bookingStatuses: _buildBookingStatuses(),
                    currentUserEmail: _currentUser?['email'],
                    currentUserRole: _currentUser?['role'],
                  ),
                ),
              ],
            ),
    );
  }
}
