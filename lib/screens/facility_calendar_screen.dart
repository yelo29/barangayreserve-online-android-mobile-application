import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../services/auth_api_service.dart';
import '../services/auto_refresh_service.dart';
import '../widgets/enhanced_calendar.dart';
import '../widgets/loading_widget.dart';
import '../utils/debug_logger.dart';
import 'booking_form_screen.dart';
import 'official_booking_form_screen.dart';

class FacilityCalendarScreen extends StatefulWidget {
  final Map<String, dynamic> facility;
  final Map<String, dynamic>? userData;

  const FacilityCalendarScreen({
    super.key,
    required this.facility,
    this.userData,
  });

  @override
  State<FacilityCalendarScreen> createState() => _FacilityCalendarScreenState();
}

class _FacilityCalendarScreenState extends State<FacilityCalendarScreen> with AutoRefreshMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _currentUser;
  final AuthApiService _authApiService = AuthApiService.instance;
  
  // Booking data
  List<Map<String, dynamic>> _allBookings = [];
  Map<String, List<Map<String, dynamic>>> _pendingBookings = {};
  Map<String, List<Map<String, dynamic>>> _approvedBookings = {};
  Map<String, List<Map<String, dynamic>>> _officialBookings = {};
  
  // Calendar status cache
  Map<String, String>? _cachedBookingStatuses;

  // Helper function to get facility rate with fallback
  String _getFacilityRate(Map<String, dynamic> facility) {
    // Check the actual database fields first
    final rate = facility['hourly_rate'] ?? facility['rate'] ?? facility['price'] ?? facility['base_rate'];
    if (rate != null) return rate.toString();
    
    final facilityName = facility['name']?.toString().toLowerCase() ?? '';
    if (facilityName.contains('covered court') || facilityName.contains('basketball')) {
      return '300';
    } else if (facilityName.contains('meeting room')) {
      return '150';
    } else if (facilityName.contains('multi-purpose') || facilityName.contains('hall')) {
      return '200';
    } else if (facilityName.contains('garden')) {
      return '100';
    } else {
      return '200';
    }
  }

  // Helper function to get facility downpayment with fallback
  String _getFacilityDownpayment(Map<String, dynamic> facility) {
    // Check the actual database fields first
    final downpayment = facility['downpayment_rate'] ?? facility['downpayment'] ?? facility['downpayment_amount'];
    if (downpayment != null) return downpayment.toString();
    
    final rate = double.tryParse(_getFacilityRate(facility)) ?? 200.0;
    return (rate * 0.5).toStringAsFixed(0);
  }

  // Helper function to get facility capacity with fallback
  String _getFacilityCapacity(Map<String, dynamic> facility) {
    final capacity = facility['capacity'] ?? facility['max_capacity'];
    if (capacity != null) return capacity.toString();
    
    final facilityName = facility['name']?.toString().toLowerCase() ?? '';
    if (facilityName.contains('covered court') || facilityName.contains('basketball')) {
      return '50';
    } else if (facilityName.contains('meeting room')) {
      return '15';
    } else if (facilityName.contains('multi-purpose') || facilityName.contains('hall')) {
      return '100';
    } else if (facilityName.contains('garden')) {
      return '30';
    } else {
      return '25';
    }
  }

  // Format amenities for display
  String _formatAmenities(dynamic amenities) {
    if (amenities == null) return 'No amenities specified';
    
    if (amenities is String) {
      try {
        List<dynamic> amenitiesList = json.decode(amenities);
        return amenitiesList.join(', ');
      } catch (e) {
        return amenities;
      }
    } else if (amenities is List) {
      return amenities.join(', ');
    }
    
    return amenities.toString();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize auto-refresh for calendar view
    initAutoRefresh('calendar_view');
    
    // Register refresh callback for booking data updates
    registerRefreshCallback(() {
      if (mounted) {
        _loadBookingData();
      }
    });
    
    // Refresh data when tab becomes visible again
    if (mounted) {
      _loadBookingData();
    }
  }

  Future<void> _loadBookingData() async {
    try {
      // Initialize current user data from widget.userData
      _currentUser = widget.userData;
      DebugLogger.api('Loading bookings for facility: ${widget.facility['id']} (${widget.facility['name']})');
      DebugLogger.api('Current user: ${_currentUser?['email']}, role: ${_currentUser?['role']}');
      
      // Use DataService for consistent data fetching (residents only see their own bookings)
      final bookingsResponse = await DataService.fetchBookings();
      
      if (bookingsResponse['success'] == true) {
        final List<Map<String, dynamic>> allBookings = bookingsResponse['data'] ?? [];
        DebugLogger.api('Received ${allBookings.length} total bookings from DataService');
        
        // Separate bookings by type and status
        final List<dynamic> pending = allBookings
            .where((booking) => booking['status'] == 'pending')
            .toList();
        final List<dynamic> approved = allBookings
            .where((booking) => booking['status'] == 'approved')
            .toList();
        
        // Separate official bookings (for locking)
        final List<dynamic> officialBookings = allBookings
            .where((booking) {
                final String userEmail = booking['user_email']?.toString() ?? '';
                final bool isOfficialEmail = userEmail.contains('official') || 
                                         userEmail.contains('barangay') ||
                                         userEmail.contains('admin');
                final bool isOfficialFlag = booking['is_official_booking'] == true;
                final bool isApproved = booking['status'] == 'approved';
                final bool isOfficialBooking = isOfficialEmail || isOfficialFlag;
                DebugLogger.api('Booking check: user=$userEmail, official=$isOfficialBooking, approved=$isApproved');
                return isOfficialBooking && isApproved;
            })
            .toList();

        DebugLogger.api('Booking totals - pending: ${pending.length}, approved: ${approved.length}, official: ${officialBookings.length}');

        // Filter bookings for this specific facility
        Map<String, List<Map<String, dynamic>>> pendingFiltered = {};
        Map<String, List<Map<String, dynamic>>> approvedFiltered = {};
        Map<String, List<Map<String, dynamic>>> officialFiltered = {};

        // Filter pending bookings (only current user's pending bookings)
        for (final booking in pending) {
          final bookingFacilityId = booking['facilityId'] ?? booking['facility_id'];
          if (bookingFacilityId.toString() == widget.facility['id'].toString() && 
              booking['user_email'] == _currentUser?['email']) {
            final date = booking['date'] ?? booking['booking_date'];
            if (date != null) {
              pendingFiltered.putIfAbsent(date, () => []).add(Map<String, dynamic>.from(booking));
              DebugLogger.api('Added user pending booking for date: $date');
            }
          }
        }

        // Filter approved bookings (current user's + official bookings only)
        for (final booking in approved) {
          final bookingFacilityId = booking['facilityId'] ?? booking['facility_id'];
          if (bookingFacilityId.toString() == widget.facility['id'].toString()) {
            final String bookingUserEmail = booking['user_email'] ?? '';
            final String currentUserEmail = _currentUser?['email'] ?? '';
            final bool isCurrentUserBooking = bookingUserEmail == currentUserEmail;
            final bool isOfficialBooking = bookingUserEmail.contains('official') || 
                                           bookingUserEmail.contains('barangay') ||
                                           bookingUserEmail.contains('admin');
            
            // Only show user's own approved bookings and official bookings
            if (isCurrentUserBooking || isOfficialBooking) {
              final date = booking['date'] ?? booking['booking_date'];
              if (date != null) {
                approvedFiltered.putIfAbsent(date, () => []).add(Map<String, dynamic>.from(booking));
                DebugLogger.api('Added approved booking for date: $date by ${isOfficialBooking ? 'OFFICIAL' : 'USER'}');
              }
            }
          }
        }

        // Filter official bookings (for locking)
        DebugLogger.api('Processing official bookings for calendar locking');
        for (final booking in officialBookings) {
          final bookingFacilityId = booking['facilityId'] ?? booking['facility_id'];
          DebugLogger.api('Checking official booking: ID ${booking['id']}, Facility: $bookingFacilityId, Target: ${widget.facility['id']}');
          if (bookingFacilityId.toString() == widget.facility['id'].toString()) {
            final date = booking['date'] ?? booking['booking_date'];
            if (date != null) {
              officialFiltered.putIfAbsent(date, () => []).add(Map<String, dynamic>.from(booking));
              DebugLogger.success('Added official booking for date: $date by ${booking['user_email']} (ID: ${booking['id']})');
            } else {
              DebugLogger.warning('Skipped official booking - no date: ${booking['id']}');
            }
          } else {
            DebugLogger.warning('Skipped official booking - wrong facility: ${booking['id']} (Facility: $bookingFacilityId vs Target: ${widget.facility['id']})');
          }
        }

        if (mounted) {
          setState(() {
            _pendingBookings = pendingFiltered;
            _approvedBookings = approvedFiltered;
            _officialBookings = officialFiltered;
            _isLoading = false;
            _cachedBookingStatuses = null; // Clear cache when data changes
          });
        }

        DebugLogger.api('Filtered bookings for facility - pending: ${_pendingBookings.length} dates, approved: ${_approvedBookings.length} dates, official: ${_officialBookings.length} dates');
      } else {
        throw Exception(bookingsResponse['error'] ?? 'Failed to fetch bookings');
      }
    } catch (e) {
      DebugLogger.error('Error loading booking data', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, String> _buildBookingStatuses() {
    // Only build once and cache the result
    if (_cachedBookingStatuses != null) {
      DebugLogger.api('Using cached booking statuses: ${_cachedBookingStatuses!.length}');
      return _cachedBookingStatuses!;
    }
    
    Map<String, String> statuses = {};
    final String currentUserEmail = _currentUser?['email'] ?? '';
    final bool isOfficial = currentUserEmail.contains('official') || 
                           currentUserEmail.contains('barangay') ||
                           currentUserEmail.contains('admin');

    DebugLogger.api('Building booking statuses for user: $currentUserEmail (isOfficial: $isOfficial)');

    // SAME LOGIC FOR BOTH ROLES - just different visibility
    // Add all pending bookings (yellow) - visible to both roles
    _pendingBookings.forEach((date, bookings) {
      if (bookings.isNotEmpty) {
        final formattedDate = _formatDateForCalendar(date);
        statuses[formattedDate] = 'pending'; // All pending bookings
        DebugLogger.api('Added pending booking: $date -> $formattedDate');
      }
    });

    // 🔥 ROLE-SPECIFIC LOGIC: Different behavior for residents vs officials
    DebugLogger.api('Building calendar statuses from approved bookings for user: ${_currentUser?['role']} (isOfficial: $isOfficial)');
    
    _approvedBookings.forEach((date, bookings) {
      if (bookings.isNotEmpty) {
        final formattedDate = _formatDateForCalendar(date);
        
        if (isOfficial) {
          // 👨‍💼 OFFICIALS: Resident approved bookings should NOT lock calendar
          DebugLogger.api('Resident approved booking IGNORED for OFFICIAL: $date -> $formattedDate (bookings: ${bookings.length})');
          // Don't add to statuses - show as available for officials
        } else {
          // 👥 RESIDENTS: Check if approved booking belongs to current user
          final bool hasOwnBooking = bookings.any((booking) => 
            booking['user_email']?.toString() == _currentUser?['email']?.toString()
          );
          
          if (hasOwnBooking) {
            // Resident's OWN approved booking - show as green in calendar but still tappable
            statuses[formattedDate] = 'own_approved'; 
            DebugLogger.success('RESIDENT OWN approved booking (GREEN/TAPPABLE): $date -> $formattedDate (bookings: ${bookings.length})');
          } else {
            // Other residents' approved bookings - lock calendar
            statuses[formattedDate] = 'approved'; 
            DebugLogger.api('LOCKED date for RESIDENT (OTHER USER): $date -> $formattedDate (bookings: ${bookings.length})');
          }
        }
        
        bookings.forEach((booking) {
          final isOwnBooking = booking['user_email']?.toString() == _currentUser?['email']?.toString();
          DebugLogger.api('Resident Approved Booking: ${booking['user_email']} - ${booking['status']} (ID: ${booking['id']}) ${isOwnBooking ? '(OWN)' : '(OTHER)'}');
        });
      } else {
        DebugLogger.warning('Empty approved bookings for date: $date');
      }
    });
    // 🔥 END: Role-specific approved booking logic

    // 🔥 ROLE-SPECIFIC LOGIC: Different locking behavior for residents vs officials
    DebugLogger.api('Building calendar statuses from official bookings for user: ${_currentUser?['role']} (isOfficial: $isOfficial)');
    
    _officialBookings.forEach((date, bookings) {
      if (bookings.isNotEmpty) {
        final formattedDate = _formatDateForCalendar(date);
        
        // 🔒 LOCK for BOTH roles: Official bookings block calendar for everyone
        statuses[formattedDate] = 'official_locked'; 
        DebugLogger.success('LOCKED date for ALL USERS: $date -> $formattedDate (bookings: ${bookings.length})');
        
        bookings.forEach((booking) {
          DebugLogger.api('Official Booking: ${booking['user_email']} - ${booking['status']} (ID: ${booking['id']})');
        });
      } else {
        DebugLogger.warning('Empty official bookings for date: $date');
      }
    });
    // 🔥 END: Official bookings lock calendar for everyone

    if (mounted) {
      setState(() {
        _cachedBookingStatuses = statuses;
      });
    }

    DebugLogger.api('Total booking statuses: ${statuses.length}');
    
    return statuses;
  }

  String _formatDateForCalendar(String dateStr) {
    try {
      final DateTime date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      DebugLogger.error('Error parsing date: $dateStr', error: e);
      return dateStr; // Return original string if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.facility['name'] ?? 'Facility Calendar'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Facility Info Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.facility['name'] ?? 'Facility Name',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.facility['description'] ?? 'Facility description',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      Row(
                        children: [
                          _buildInfoChip(
                            icon: Icons.attach_money,
                            label: '₱${_getFacilityRate(widget.facility)}',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _buildInfoChip(
                            icon: Icons.payment,
                            label: '₱${_getFacilityDownpayment(widget.facility)} down',
                            color: Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildInfoChip(
                            icon: Icons.group,
                            label: '${_getFacilityCapacity(widget.facility)} capacity',
                            color: Colors.purple,
                          ),
                        ],
                      ),
                      if ((widget.facility['amenities']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Amenities:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatAmenities(widget.facility['amenities']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Calendar
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Calendar Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Select a Date',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Calendar Widget
                        Expanded(
                          child: EnhancedCalendar(
                            selectedDate: DateTime.now(),
                            onDateSelected: (selectedDate) {
                              _handleDateSelection(selectedDate);
                            },
                            bookingStatuses: _buildBookingStatuses(),
                            currentUserEmail: _currentUser?['email'],
                            currentUserRole: _currentUser?['role'],
                          ),
                        ),
                        
                        // Calendar Legend
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status Color Guide:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  _buildCalendarLegendItem('Available', Colors.white),
                                  _buildCalendarLegendItem('Your Pending', Colors.yellow),
                                  _buildCalendarLegendItem('Your Approved', Colors.green),
                                  _buildCalendarLegendItem('Official Event', Colors.grey, 'Locked'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _handleDateSelection(DateTime selectedDate) {
    final String currentUserEmail = _currentUser?['email'] ?? '';
    final bool isOfficial = currentUserEmail.contains('official') || 
                           currentUserEmail.contains('barangay') ||
                           currentUserEmail.contains('admin');
    
    // Get the date status
    final String dateKey = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    final Map<String, String> statuses = _buildBookingStatuses();
    final String? dateStatus = statuses[dateKey];
    
    DebugLogger.api('Date selection: $dateKey, status: $dateStatus, isOfficial: $isOfficial');
    
    if (isOfficial && (dateStatus == 'pending' || dateStatus == 'official')) {
      // Show warning dialog for officials when there are existing bookings
      _showOfficialBookingWarning(selectedDate);
    } else {
      // Normal navigation
      _navigateToBookingForm(selectedDate);
    }
  }

  void _showOfficialBookingWarning(DateTime selectedDate) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              const Text('Booking Notice'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Before booking, you must tap the time slot to see who has approved or pending bookings.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Contact the resident users to inform them that you will give them back their money.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This ensures proper coordination with existing bookings.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToBookingForm(selectedDate);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Proceed Anyway'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToBookingForm(DateTime selectedDate) {
    final String currentUserEmail = _currentUser?['email'] ?? '';
    final bool isOfficial = currentUserEmail.contains('official') || 
                           currentUserEmail.contains('barangay') ||
                           currentUserEmail.contains('admin');
    
    DebugLogger.api('Opening calendar for facility: ${widget.facility['name']} with user: ${_currentUser?['email']} (isOfficial: $isOfficial)');
    
    if (isOfficial) {
      // Navigate to official booking form
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OfficialBookingFormScreen(
            facility: widget.facility,
            selectedDate: selectedDate,
            userData: _currentUser,
          ),
        ),
      );
    } else {
      // Navigate to resident booking form
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingFormScreen(
            facility: widget.facility,
            selectedDate: selectedDate,
            userData: _currentUser,
          ),
        ),
      );
    }
  }

  Widget _buildCalendarLegendItem(String label, Color color, [String? subtitle]) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
