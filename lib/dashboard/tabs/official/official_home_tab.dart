import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/data_service.dart';
import '../../../services/auth_api_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../utils/debug_logger.dart';
import '../../../widgets/facility_icon.dart';
import '../../../widgets/timeslot_dialog.dart';
import '../../../screens/official_booking_form_screen.dart';
import '../../../widgets/enhanced_calendar.dart';
import '../../../screens/booking_form_screen.dart';
import 'facility_edit_screen.dart';
import 'official_calendar_screen.dart';

class OfficialHomeTab extends StatefulWidget {
  final bool isDarkMode;
  const OfficialHomeTab({super.key, this.isDarkMode = false});

  @override
  State<OfficialHomeTab> createState() => _OfficialHomeTabState();
}

class _OfficialHomeTabState extends State<OfficialHomeTab> {
  List<Map<String, dynamic>> _facilities = [];
  Map<String, List<Map<String, dynamic>>> _pendingBookings = {};
  Map<String, List<Map<String, dynamic>>> _approvedBookings = {};
  Map<String, List<Map<String, dynamic>>> _officialBookings = {};
  bool _isLoading = true;
  Map<String, dynamic>? _currentUser;
  final AuthApiService _authApiService = AuthApiService.instance;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    try {
      DebugLogger.ui('Loading official dashboard facilities...');

      // Get current user data
      _currentUser = await _authApiService.getCurrentUser();

      // Use DataService for consistent data fetching
      final facilitiesResponse = await DataService.fetchFacilities();
      
      if (facilitiesResponse['success'] == true) {
        final List<Map<String, dynamic>> facilitiesList = facilitiesResponse['data'] ?? [];
        
        // Load all bookings for status display
        await _loadBookingData();

        if (mounted) {
          setState(() {
            _facilities = facilitiesList.where((facility) {
              try {
                final isActive = facility['active'] != false;
                DebugLogger.ui(
                  'Official Facility ${facility['name']} - active: $isActive',
                );
                return isActive;
              } catch (e) {
                DebugLogger.ui('Error processing facility: $e');
                DebugLogger.ui('Facility data: $facility');
                return false;
              }
            }).toList();
            _isLoading = false;
            DebugLogger.ui(
              'Loaded ${_facilities.length} active facilities for official',
            );
          });
        }
      } else {
        throw Exception(facilitiesResponse['error'] ?? 'Failed to fetch facilities');
      }
    } catch (e) {
      DebugLogger.error('Error loading official facilities: $e');
      if (mounted) {
        setState(() {
          _facilities = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBookingData() async {
    try {
      print('🔍 OfficialHomeTab._loadBookingData - fetching all bookings...');
      
      // Use DataService for consistent data fetching (officials see all bookings)
      final bookingsResponse = await DataService.fetchBookings();
      
      if (bookingsResponse['success'] == true) {
        final List<Map<String, dynamic>> allBookings = bookingsResponse['data'] ?? [];
        final pendingBookings = allBookings.where((booking) => booking['status'] == 'pending').toList();
        final approvedBookings = allBookings.where((booking) => booking['status'] == 'approved').toList();

        // Separate official bookings from resident approved bookings
        final officialBookings = approvedBookings.where((booking) {
          final String userEmail = booking['user_email']?.toString() ?? '';
          final bool isOfficialEmail = userEmail.contains('official') || 
                                   userEmail.contains('barangay') ||
                                   userEmail.contains('admin');
          final bool isOfficialFlag = booking['is_official_booking'] == true;
          return isOfficialEmail || isOfficialFlag;
        }).toList();

        // Resident approved bookings (non-official)
        final residentApprovedBookings = approvedBookings.where((booking) {
          final String userEmail = booking['user_email']?.toString() ?? '';
          final bool isOfficialEmail = userEmail.contains('official') || 
                                   userEmail.contains('barangay') ||
                                   userEmail.contains('admin');
          final bool isOfficialFlag = booking['is_official_booking'] == true;
          return !(isOfficialEmail || isOfficialFlag);
        }).toList();

        print('🔍 OfficialHomeTab - pending bookings total: ${pendingBookings.length}');
        print('🔍 OfficialHomeTab - resident approved bookings total: ${residentApprovedBookings.length}');
        print('🔍 OfficialHomeTab - official bookings total: ${officialBookings.length}');

        // Group bookings by date (for all facilities since officials see all)
        Map<String, List<Map<String, dynamic>>> pending = {};
        Map<String, List<Map<String, dynamic>>> approved = {};
        Map<String, List<Map<String, dynamic>>> official = {};

        for (var booking in pendingBookings) {
          final date = booking['booking_date']?.toString() ?? '';
          if (date.isNotEmpty) {
            pending.putIfAbsent(date, () => []);
            pending[date]!.add(booking);
          }
        }

        for (var booking in residentApprovedBookings) {
          final date = booking['booking_date']?.toString() ?? '';
          if (date.isNotEmpty) {
            approved.putIfAbsent(date, () => []);
            approved[date]!.add(booking);
          }
        }

        for (var booking in officialBookings) {
          final date = booking['booking_date']?.toString() ?? '';
          if (date.isNotEmpty) {
            official.putIfAbsent(date, () => []);
            official[date]!.add(booking);
          }
        }

        if (mounted) {
          setState(() {
            _pendingBookings = pending;
            _approvedBookings = approved;
            _officialBookings = official;
          });
        }
      } else {
        throw Exception(bookingsResponse['error'] ?? 'Failed to fetch bookings');
      }
    } catch (e) {
      print('❌ OfficialHomeTab._loadBookingData - Error: $e');
      if (mounted) {
        setState(() {
          _pendingBookings = {};
          _approvedBookings = {};
          _officialBookings = {};
        });
      }
    }
  }

  Map<String, String> _buildFacilityBookingStatuses(Map<String, dynamic> facility) {
    final Map<String, String> statuses = {};
    final facilityId = facility['id'];

    // Filter bookings for this specific facility
    final facilityPendingBookings = <String, List<Map<String, dynamic>>>{};
    final facilityApprovedBookings = <String, List<Map<String, dynamic>>>{};
    final facilityOfficialBookings = <String, List<Map<String, dynamic>>>{};

    // Filter pending bookings for this facility
    _pendingBookings.forEach((date, bookings) {
      final facilityBookings = bookings.where((booking) => 
        booking['facility_id'] == facilityId
      ).toList();
      
      if (facilityBookings.isNotEmpty) {
        facilityPendingBookings[date] = facilityBookings;
      }
    });

    // Filter approved bookings for this facility (resident only)
    _approvedBookings.forEach((date, bookings) {
      final facilityBookings = bookings.where((booking) => 
        booking['facility_id'] == facilityId
      ).toList();
      
      if (facilityBookings.isNotEmpty) {
        facilityApprovedBookings[date] = facilityBookings;
      }
    });

    // Filter official bookings for this facility
    _officialBookings.forEach((date, bookings) {
      final facilityBookings = bookings.where((booking) => 
        booking['facility_id'] == facilityId
      ).toList();
      
      if (facilityBookings.isNotEmpty) {
        facilityOfficialBookings[date] = facilityBookings;
      }
    });

    // Add pending bookings for this facility
    facilityPendingBookings.forEach((date, bookings) {
      final formattedDate = _formatDateForCalendar(date);
      statuses[formattedDate] = 'pending';
      print('🔍 Adding facility pending date: $date -> $formattedDate (Facility: ${facility['name']})');
    });

    // Add official bookings for this facility (highest priority - locks for everyone including officials)
    facilityOfficialBookings.forEach((date, bookings) {
      final formattedDate = _formatDateForCalendar(date);
      statuses[formattedDate] = 'official_locked';
      print('🔍 Adding facility OFFICIAL LOCKED date: $date -> $formattedDate (Facility: ${facility['name']})');
    });

    // Add resident approved bookings for this facility (lower priority than official)
    facilityApprovedBookings.forEach((date, bookings) {
      final formattedDate = _formatDateForCalendar(date);
      // Only add if not already locked by official booking
      if (!statuses.containsKey(formattedDate)) {
        statuses[formattedDate] = 'approved';
        print('🔍 Adding facility resident approved date: $date -> $formattedDate (Facility: ${facility['name']})');
      }
    });

    print('🔍 Facility ${facility['name']} booking statuses - total: ${statuses.length}');
    return statuses;
  }

  Map<String, String> _buildBookingStatuses() {
    final Map<String, String> statuses = {};

    // Add pending bookings
    _pendingBookings.forEach((date, bookings) {
      final formattedDate = _formatDateForCalendar(date);
      statuses[formattedDate] = 'pending';
      print('🔍 Adding pending date: $date -> $formattedDate');
    });

    // Add approved bookings (overrides pending if exists)
    _approvedBookings.forEach((date, bookings) {
      final formattedDate = _formatDateForCalendar(date);
      statuses[formattedDate] = 'approved';
      print('🔍 Adding approved date: $date -> $formattedDate');
    });

    print('🔍 OfficialHomeTab._buildBookingStatuses - total statuses: ${statuses.length}');
    print('🔍 Status map keys: ${statuses.keys.toList()}');
    return statuses;
  }

  String _formatDateForCalendar(String dateStr) {
    try {
      final DateTime date = DateTime.parse(dateStr);
      // Use the same format as enhanced calendar expects
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      print('❌ Error parsing date: $dateStr - $e');
      return dateStr;
    }
  }

  void _quickBookFacility(Map<String, dynamic> facility) async {
    // Show enhanced calendar dialog
    final DateTime? selectedDate = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.75,
          child: EnhancedCalendar(
            selectedDate: DateTime.now(),
            bookingStatuses: _buildFacilityBookingStatuses(facility), // Use facility-specific booking status
            pendingColor: Colors.yellow,
            bookedColor: Colors.green.shade200,
            availableColor: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
            selectedColor: Colors.blue,
            showTodayButton: false,
            currentUserEmail: _currentUser?['email'],
            currentUserRole: _currentUser?['role'],
            onDateSelected: (date) {
              Navigator.pop(ctx, date);
            },
          ),
        ),
      ),
    );

    if (selectedDate != null) {
      // Navigate to official booking form instead of instant booking
      final currentUser = await _authApiService.getCurrentUser();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OfficialBookingFormScreen(
            facility: facility,
            selectedDate: selectedDate,
            userData: currentUser,
            isDarkMode: widget.isDarkMode,
          ),
        ),
      );
    }
  }

  // Refresh data method
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Reload facilities and user data
    await _loadFacilities();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.grey.shade900 : Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  // Quick Booking Section
                  Container(
                    height: 300, // Fixed height for Quick Booking section
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? Colors.grey.shade800 : Colors.pink.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: widget.isDarkMode ? Colors.grey.shade700 : Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.flash_on,
                              color: widget.isDarkMode ? Colors.red.shade400 : Colors.red.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Quick Booking',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: widget.isDarkMode ? Colors.red.shade400 : Colors.red,
                              ),
                            ),
                            const Spacer(),
                            // Refresh button
                            IconButton(
                              onPressed: _refreshData,
                              icon: Icon(Icons.refresh, color: widget.isDarkMode ? Colors.red.shade400 : Colors.red.shade700),
                              tooltip: 'Refresh',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Instant booking for officials (auto-approved)',
                          style: TextStyle(fontSize: 14, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _facilities.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.business,
                                        size: 64,
                                        color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No facilities found',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap the + button to add your first facility',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _facilities.length,
                                  itemBuilder: (context, index) {
                                    final facility = _facilities[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: Card(
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        color: widget.isDarkMode ? Colors.grey.shade700 : Colors.blue.shade50,
                                        child: InkWell(
                                          onTap: () => _quickBookFacility(facility),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Row(
                                              children: [
                                                FacilityIcon(
                                                  iconName:
                                                      facility['main_photo_url'] ??
                                                      'location_city',
                                                  size: 40,
                                                  color: widget.isDarkMode ? Colors.red.shade400 : Colors.red.shade600,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        facility['name'] ??
                                                            'Unknown Facility',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: widget.isDarkMode ? Colors.white : Colors.black87,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Book entire day instantly',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: widget.isDarkMode ? Colors.red.shade700 : Colors.red.shade600,
                                                    borderRadius:
                                                        BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                        'Quick Book Day',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Facility Management Section
                  Container(
                    height: 250, // Fixed height for Manage Facilities section
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? Colors.grey.shade800 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: widget.isDarkMode ? Colors.grey.shade700 : Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.settings,
                              color: widget.isDarkMode ? Colors.orange.shade400 : Colors.orange.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Manage Facilities',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: widget.isDarkMode ? Colors.orange.shade400 : Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _facilities.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'Add your first facility using the + button',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _facilities.length,
                                  itemBuilder: (context, index) {
                                    final facility = _facilities[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: Card(
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        color: widget.isDarkMode ? Colors.grey.shade700 : Colors.white,
                                        child: InkWell(
                                          onTap: () => _editFacility(facility),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Row(
                                              children: [
                                                FacilityIcon(
                                                  iconName:
                                                      facility['main_photo_url'] ??
                                                      'location_city',
                                                  size: 32,
                                                  color: widget.isDarkMode ? Colors.red.shade400 : Colors.red.shade700,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        facility['name']?.toString() ??
                                                            'Unknown Facility',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                          color: widget.isDarkMode ? Colors.white : Colors.black87,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      
                                                      
                                                      const SizedBox(height: 8),
                                                      Container(
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: widget.isDarkMode ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade100,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: GestureDetector(
                                                                onTap: () => _editFacility(facility),
                                                                child: Text(
                                                                  'Edit',
                                                                  style: TextStyle(
                                                                    color: widget.isDarkMode ? Colors.red.shade400 : Colors.red,
                                                                    fontSize: 10,
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: widget.isDarkMode ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade100,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: GestureDetector(
                                                                onTap: () => _regenerateTimeSlots(facility),
                                                                child: Text(
                                                                  'Slots',
                                                                  style: TextStyle(
                                                                    color: widget.isDarkMode ? Colors.blue.shade400 : Colors.blue,
                                                                    fontSize: 10,
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: widget.isDarkMode ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade100,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: GestureDetector(
                                                                onTap: () => _deleteFacility(facility),
                                                                child: Text(
                                                                  'Delete',
                                                                  style: TextStyle(
                                                                    color: widget.isDarkMode ? Colors.red.shade400 : Colors.red,
                                                                    fontSize: 10,
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ), // Column children
            ), // SingleChildScrollView
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewFacility,
        backgroundColor: widget.isDarkMode ? Colors.red.shade700 : Colors.red,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add New Facility',
      ),
    );
  }

  void _viewFacilityCalendar(Map<String, dynamic> facility) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OfficialCalendarScreen(facility: facility, isDarkMode: widget.isDarkMode),
      ),
    );
  }

  void _addNewFacility() async {
    // Navigate to facility edit screen with null for new facility
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityEditScreen(facility: null, isDarkMode: widget.isDarkMode),
      ),
    );

    if (result == true) {
      _loadFacilities(); // Refresh the facility list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facility added successfully')),
      );
    }
  }

  void _editFacility(Map<String, dynamic> facility) async {
    // Navigate to facility edit screen with existing facility data
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityEditScreen(facility: facility, isDarkMode: widget.isDarkMode),
      ),
    );

    if (result == true) {
      _loadFacilities(); // Refresh the facility list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facility updated successfully')),
      );
    }
  }

  void _deleteFacility(Map<String, dynamic> facility) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
        title: Text('Delete Facility', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87)),
        content: Text('Are you sure you want to delete "${facility['name']}"?\n\nThis action cannot be undone.', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Deleting facility...', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87)),
            ],
          ),
        ),
      );

      try {
        // Use DataService.deleteFacility to actually delete the facility
        final result = await DataService.deleteFacility(facility['id'].toString());
        
        // Close loading dialog
        Navigator.pop(context);
        
        // Show result
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
            title: Text(result['success'] ? 'Success' : 'Error', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87)),
            content: Text(result['success'] 
                ? 'Facility deleted successfully!' 
                : result['message'] ?? 'Failed to delete facility', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Refresh facilities after successful deletion
                  if (result['success']) {
                    _loadFacilities();
                  }
                },
                child: Text('OK', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
              ),
            ],
          ),
        );
      } catch (e) {
        // Close loading dialog
        Navigator.pop(context);
        
        // Show error
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
            title: Text('Error', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87)),
            content: Text('Failed to delete facility: $e', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _regenerateTimeSlots(Map<String, dynamic> facility) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
        title: Text('Regenerate Time Slots', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87)),
        content: Text('Are you sure you want to regenerate time slots for "${facility['name']}"?\n\nThis will replace all existing time slots with new ones based on the facility type.', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Regenerating time slots...', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87)),
            ],
          ),
        ),
      );

      try {
        // Call API to regenerate time slots
        final result = await DataService.regenerateFacilityTimeSlots(facility['id'].toString());
        
        // Close loading dialog
        Navigator.pop(context);
        
        // Show result
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
            title: Text(result['success'] ? 'Success' : 'Error', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87)),
            content: Text(result['success'] 
                ? 'Time slots regenerated successfully!\nCreated: ${result['time_slots_created']} slots' 
                : result['message'] ?? 'Failed to regenerate time slots', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
              ),
            ],
          ),
        );
      } catch (e) {
        // Close loading dialog
        Navigator.pop(context);
        
        // Show error
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
            title: Text('Error', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87)),
            content: Text('Failed to regenerate time slots: $e', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
              ),
            ],
          ),
        );
      }
    }
  }
}
