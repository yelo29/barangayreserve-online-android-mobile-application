import 'package:flutter/material.dart';
import '../../../services/data_service.dart';
import '../../../services/auth_api_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';

class ResidentBookingsTab extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final bool isDarkMode;
  
  const ResidentBookingsTab({super.key, this.userData, this.isDarkMode = false});

  @override
  State<ResidentBookingsTab> createState() => _ResidentBookingsTabState();
}

class _ResidentBookingsTabState extends State<ResidentBookingsTab> {
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _filteredBookings = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatusFilter = 'all';
  String _selectedFacilityFilter = 'all';
  String _selectedSubmittedDateSort = 'none';
  String _selectedBookingDateSort = 'none';
  String _searchQuery = '';
  bool _showFilterMenu = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  @override
  void didUpdateWidget(ResidentBookingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh data when widget is updated (e.g., when navigating back)
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final currentUser = await AuthApiService.instance.getCurrentUser();
      if (currentUser == null || currentUser.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'User not logged in';
          });
        }
        return;
      }

      print('🔍 Loading bookings for user: ${currentUser['email']}');
      
      // Use DataService for consistent data fetching
      final bookingsResponse = await DataService.fetchBookings();
      
      if (bookingsResponse['success'] == true) {
        final List<Map<String, dynamic>> bookings = bookingsResponse['data'] ?? [];
        print('🔍 Received ${bookings.length} bookings from DataService');
        
        // Debug: Show booking structure
        if (bookings.isNotEmpty) {
          print('🔍 DEBUG: First booking structure: ${bookings.first}');
          print('🔍 DEBUG: Booking keys: ${bookings.first.keys.toList()}');
        }
        
        // Filter bookings for current user (double privacy protection)
        final userBookings = bookings.where((booking) {
          return booking['user_email'] == currentUser['email'];
        }).toList();
        
        if (mounted) {
          setState(() {
            _bookings = userBookings;
            _filteredBookings = List.from(userBookings); // Create immutable copy
            _isLoading = false;
          });
        }
      } else {
        throw Exception(bookingsResponse['error'] ?? 'Failed to fetch bookings');
      }
    } catch (e) {
      print('❌ Error loading bookings: $e');
      if (mounted) {
        setState(() {
          _bookings = [];
          _filteredBookings = [];
          _isLoading = false;
          _error = 'Failed to load bookings: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _refreshBookings() async {
    await _loadBookings();
  }

  // Pure function for filtering - no side effects
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> bookings, String statusFilter, String facilityFilter, String submittedDateSort, String bookingDateSort, String searchQuery) {
    // Create immutable copy to avoid data mutation
    List<Map<String, dynamic>> filtered = List.from(bookings);
    
    // Apply status filter
    if (statusFilter != 'all') {
      filtered = filtered.where((booking) => 
        (booking['status']?.toString().toLowerCase() ?? 'pending') == statusFilter.toLowerCase()
      ).toList();
    }
    
    // Apply facility filter
    if (facilityFilter != 'all') {
      filtered = filtered.where((booking) {
        final facilityName = (booking['facility_name']?.toString() ?? 
                            booking['facilityName']?.toString() ?? 
                            'Unknown Facility').toLowerCase();
        return facilityName == facilityFilter.toLowerCase();
      }).toList();
    }
    
    // Apply search filter (facility name and user email)
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((booking) {
        final facilityName = (booking['facility_name']?.toString() ?? 
                            booking['facilityName']?.toString() ?? 
                            'Unknown Facility').toLowerCase();
        final userEmail = (booking['user_email']?.toString() ?? 
                          booking['email']?.toString() ?? 
                          'Unknown User').toLowerCase();
        return facilityName.contains(query) || userEmail.contains(query);
      }).toList();
    }
    
    // Apply submitted date sorting
    if (submittedDateSort != 'none') {
      filtered = List.from(filtered)..sort((a, b) {
        final dateA = a['created_at']?.toString() ?? '';
        final dateB = b['created_at']?.toString() ?? '';
        try {
          final dateTimeA = DateTime.parse(dateA);
          final dateTimeB = DateTime.parse(dateB);
          return submittedDateSort == 'asc' 
              ? dateTimeA.compareTo(dateTimeB)
              : dateTimeB.compareTo(dateTimeA);
        } catch (e) {
          return dateA.compareTo(dateB);
        }
      });
    }
    
    // Apply booking date sorting
    if (bookingDateSort != 'none') {
      filtered = List.from(filtered)..sort((a, b) {
        final dateA = (a['booking_date']?.toString() ?? a['date']?.toString() ?? '');
        final dateB = (b['booking_date']?.toString() ?? b['date']?.toString() ?? '');
        try {
          final dateTimeA = DateTime.parse(dateA);
          final dateTimeB = DateTime.parse(dateB);
          return bookingDateSort == 'asc' 
              ? dateTimeA.compareTo(dateTimeB)
              : dateTimeB.compareTo(dateTimeA);
        } catch (e) {
          return dateA.compareTo(dateB);
        }
      });
    }
    
    return filtered; // Return new filtered list, never modify original
  }
  
  // Safe filter update method
  void _updateFilters() {
    setState(() {
      _filteredBookings = _applyFilters(_bookings, _selectedStatusFilter, _selectedFacilityFilter, _selectedSubmittedDateSort, _selectedBookingDateSort, _searchQuery);
    });
  }
  
  // Helper method to get unique facilities from bookings
  List<String> _getUniqueFacilities(List<Map<String, dynamic>> bookings) {
    final Set<String> facilities = {};
    for (final booking in bookings) {
      final facilityName = (booking['facility_name']?.toString() ?? 
                          booking['facilityName']?.toString() ?? 
                          'Unknown Facility');
      facilities.add(facilityName);
    }
    final facilityList = facilities.toList();
    facilityList.sort(); // Sort alphabetically
    return facilityList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? Colors.grey.shade800 : Colors.blue,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Bookings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your booking requests',
                    style: TextStyle(
                      fontSize: 16,
                      color: widget.isDarkMode ? Colors.grey.shade300 : Colors.blue[100],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Filter Controls
            _buildFilterControls(),
            
            const SizedBox(height: 8),

            // Bookings List
            Container(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 80,
                                color: widget.isDarkMode ? Colors.red.shade400 : Colors.red[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading bookings',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _refreshBookings,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.isDarkMode ? Colors.blue.shade700 : Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _filteredBookings.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.book_online,
                                    size: 60,
                                    color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No bookings yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Book a facility to get started',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: _refreshBookings,
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.isDarkMode ? Colors.blue.shade700 : Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _refreshBookings,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: _filteredBookings.length,
                                itemBuilder: (context, index) {
                                  final booking = _filteredBookings[index];
                                  return _buildBookingCard(booking);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
        ), );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final facilityName = booking['facility_name'] ?? booking['facilityName'] ?? 'Unknown Facility';
    
    print('🔍 _buildBookingCard: $facilityName'); // Debug logging
    
    // Debug logging for rejection processing
    final statusText = status.toUpperCase();
    print('🔥🔥🔥 ResidentBookingsTab: Processing booking ID ${booking['id']}');
    print('🔥🔥🔥 ResidentBookingsTab: Status: "$status" -> "$statusText"');
    print('🔥🔥🔥 ResidentBookingsTab: Is REJECTED? ${statusText == 'REJECTED'}');
    print('🔥🔥🔥 ResidentBookingsTab: Has rejection_reason? ${booking['rejection_reason'] != null}');
    if (booking['rejection_reason'] != null) {
      print('🔥🔥🔥 ResidentBookingsTab: Rejection reason: "${booking['rejection_reason']}"');
    }
    
    if (statusText == 'REJECTED') {
      print('🔥🔥🔥 ResidentBookingsTab: === WILL DISPLAY REJECTION SECTION ===');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    facilityName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Booking Details
            _buildDetailRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value: booking['booking_date'] ?? booking['date'] ?? 'Not set',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.access_time,
              label: 'Time Slot',
              value: booking['start_time'] ?? booking['timeslot'] ?? booking['time_slot'] ?? 'Not set',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.attach_money,
              label: 'Total Amount',
              value: '₱${booking['total_amount'] ?? booking['totalAmount'] ?? '0'}',
            ),
            if (booking['downpayment'] != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                icon: Icons.payment,
                label: 'Downpayment',
                value: '₱${booking['downpayment']}',
              ),
            ],

            // Purpose/Notes
            if (booking['purpose'] != null && booking['purpose'].isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purpose',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking['purpose'],
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Rejection Reason/Apology Message for REJECTED bookings
            if (status.toUpperCase() == 'REJECTED') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.isDarkMode ? Colors.red.shade700 : Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, size: 16, color: widget.isDarkMode ? Colors.red.shade400 : Colors.red.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Booking Rejected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: widget.isDarkMode ? Colors.red.shade400 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // NEW: Check if rejection reason contains violation warning (fake receipt only)
                    if (booking['rejection_reason'] != null && 
                        booking['rejection_reason'].toString().contains('violation will be recorded')) 
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'VIOLATION WARNING',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getRejectionMessage(booking),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        _getRejectionMessage(booking),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Created Date
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final createdAt = booking['created_at'] ?? booking['createdAt'] ?? 'Unknown';
                print('🔍 Booking created_at field: $createdAt'); // Debug logging
                return Text(
                  'Booked on ${_formatDate(createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey[500],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: widget.isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.yellow;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'cancelled':
        return Icons.not_interested;
      default:
        return Icons.help;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    
    DateTime dateTime;
    if (date is DateTime) {
      dateTime = date;
    } else if (date is String) {
      try {
        // Parse string date "2026-02-01 16:51:24"
        dateTime = DateTime.parse(date);
      } catch (e) {
        print('🔍 Error parsing date string: $date - $e');
        return 'Unknown';
      }
    } else if (date is Map && date.containsKey('_seconds')) {
      // Handle Firebase timestamp format
      try {
        final seconds = date['_seconds'] as int;
        final nanoseconds = date['_nanoseconds'] as int? ?? 0;
        dateTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000 + nanoseconds ~/ 1000000);
      } catch (e) {
        print('🔍 Error parsing Firebase timestamp: $date - $e');
        return 'Unknown';
      }
    } else {
      print('🔍 Unsupported date type: ${date.runtimeType}');
      return 'Unknown';
    }

    // Format to "February 1, 2026"
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  String _getRejectionMessage(Map<String, dynamic> booking) {
    final rejectionReason = booking['rejection_reason']?.toString();
    
    if (rejectionReason == 'OFFICIAL_OVERLAP') {
      return 'This booking was automatically rejected due to an official barangay event. We apologize for the inconvenience. Please wait for refund in 2-3 days, depending on your payment status';
    }
    
    // Default message for other rejections
    return booking['rejection_reason'] ?? 'This date has been Rejected by Officials due to fake Reciept or Wrong downpayment given.';
  }
  
  // Safe filter UI widget
  Widget _buildFilterControls() {
    final uniqueFacilities = _getUniqueFacilities(_bookings);
    
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with hamburger menu
          Row(
            children: [
              Text(
                'Filter Bookings',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black),
              ),
              const Spacer(),
              // Hamburger menu icon
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showFilterMenu = !_showFilterMenu;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? Colors.grey.shade700 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.menu,
                    color: widget.isDarkMode ? Colors.blue.shade300 : Colors.blue,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          
          // Filter controls (expandable)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showFilterMenu 
                ? _buildExpandedFilterControls(uniqueFacilities)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
  
  // Expanded filter controls
  Widget _buildExpandedFilterControls(List<String> uniqueFacilities) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey.shade700 : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status filter
          _buildFilterDropdown(
            'Status',
            _selectedStatusFilter,
            ['all', 'pending', 'approved', 'rejected'],
            (value) {
              if (value != null) {
                setState(() {
                  _selectedStatusFilter = value;
                });
                _updateFilters();
              }
            },
          ),
          
          const SizedBox(height: 6),
          
          // Facility filter
          _buildFilterDropdown(
            'Facility',
            _selectedFacilityFilter,
            ['all', ...uniqueFacilities],
            (value) {
              if (value != null) {
                setState(() {
                  _selectedFacilityFilter = value;
                });
                _updateFilters();
              }
            },
          ),
          
          const SizedBox(height: 6),
          
          // Date sorting row
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'Submitted',
                  _selectedSubmittedDateSort,
                  ['none', 'asc', 'desc'],
                  (value) {
                    if (value != null) {
                      setState(() {
                        _selectedSubmittedDateSort = value;
                      });
                      _updateFilters();
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildFilterDropdown(
                  'Booking',
                  _selectedBookingDateSort,
                  ['none', 'asc', 'desc'],
                  (value) {
                    if (value != null) {
                      setState(() {
                        _selectedBookingDateSort = value;
                      });
                      _updateFilters();
                    }
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 6),
          
          // Search and clear row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Search facility or email',
                    labelStyle: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search, size: 18, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _updateFilters();
                  },
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedStatusFilter = 'all';
                    _selectedFacilityFilter = 'all';
                    _selectedSubmittedDateSort = 'none';
                    _selectedBookingDateSort = 'none';
                    _searchQuery = '';
                    _searchController.clear();
                  });
                  _updateFilters();
                },
                icon: Icon(Icons.clear_all, size: 16, color: widget.isDarkMode ? Colors.white : Colors.black),
                label: Text('Clear', style: TextStyle(fontSize: 11, color: widget.isDarkMode ? Colors.white : Colors.black)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          // Results count
          Text(
            'Showing ${_filteredBookings.length} of ${_bookings.length}',
            style: TextStyle(fontSize: 11, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black),
          ),
        ],
      ),
    );
  }
  
  // Helper method to build filter dropdown
  Widget _buildFilterDropdown(String label, String currentValue, List<String> options, Function(String?) onChanged) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: widget.isDarkMode ? Colors.white : Colors.black)),
          const SizedBox(height: 2),
          DropdownButton<String>(
            value: currentValue,
            isExpanded: true,
            style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.white : Colors.black),
            items: options.map((option) => 
              DropdownMenuItem(
                value: option,
                child: Text(option, style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.white : Colors.black)),
              )
            ).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
