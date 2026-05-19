import 'package:flutter/material.dart';
import '../../../services/data_service.dart';
import '../../../services/auth_api_service.dart';
import '../../../utils/debug_logger.dart';
import '../resident/my_bookings_page.dart';

class ResidentBookingsTab extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const ResidentBookingsTab({super.key, this.userData});

  @override
  State<ResidentBookingsTab> createState() => _ResidentBookingsTabState();
}

class _ResidentBookingsTabState extends State<ResidentBookingsTab> {
  List<Map<String, dynamic>> _myBookings = [];
  List<Map<String, dynamic>> _filteredBookings = [];
  bool _isLoading = true;
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
    _loadMyBookings();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh bookings when the tab becomes visible again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMyBookings();
      }
    });
  }

  Future<void> _loadMyBookings() async {
    try {
      DebugLogger.ui('Loading my bookings for resident...');
      print('🔍 _loadMyBookings() called'); // Debug logging
      
      // Get current user data
      final userData = await DataService.getCurrentUserData();
      if (userData == null) {
        throw Exception('User not logged in');
      }
      
      print('🔍 Current user data: $userData'); // Debug logging
      
      // Use DataService with explicit user role and email for residents
      final bookingsResponse = await DataService.fetchBookings(
        userRole: 'resident',
      );
      
      if (bookingsResponse['success'] == true) {
        final List<Map<String, dynamic>> bookings = bookingsResponse['data'] ?? [];
        print('🔍 Received ${bookings.length} bookings from DataService'); // Debug logging
        
        // Filter bookings for current user (DataService already filters by user email for residents)
        final myBookings = bookings.where((booking) => 
          booking['user_email'] != null && booking['user_email'] == userData['email']
        ).toList();
        
        print('🔍 Filtered to ${myBookings.length} bookings for current user'); // Debug logging
        
        // Debug: Print first few bookings to check structure
        if (myBookings.isNotEmpty) {
          print('🔍 DEBUG: First booking structure:');
          print('  Keys: ${myBookings.first.keys.toList()}');
          print('  Status: ${myBookings.first['status']}');
          print('  Rejection reason: ${myBookings.first['rejection_reason']}');
        }
        
        setState(() {
          _myBookings = myBookings;
          _filteredBookings = List.from(myBookings); // Create immutable copy
          DebugLogger.ui('Loaded ${_myBookings.length} bookings for resident');
          _isLoading = false;
        });
      } else {
        throw Exception(bookingsResponse['error'] ?? 'Failed to fetch bookings');
      }
    } catch (e) {
      DebugLogger.error('Error loading my bookings: $e');
      print('🔍 Error loading bookings: $e'); // Debug logging
      setState(() {
        _myBookings = [];
        _filteredBookings = [];
        _isLoading = false;
      });
    }
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
      _filteredBookings = _applyFilters(_myBookings, _selectedStatusFilter, _selectedFacilityFilter, _selectedSubmittedDateSort, _selectedBookingDateSort, _searchQuery);
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        // Filter controls
        _buildFilterControls(),
        const SizedBox(height: 16),
        // Bookings list
        Expanded(
          child: MyBookingsPage(bookings: _filteredBookings),
        ),
      ],
    );
  }

@override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Safe filter UI widget
  Widget _buildFilterControls() {
    final uniqueFacilities = _getUniqueFacilities(_myBookings);
    
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with hamburger menu
          Row(
            children: [
              const Text(
                'Filter Bookings',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.menu,
                    color: Colors.blue,
                    size: 20,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status filter
          _buildFilterDropdown(
            'Status',
            _selectedStatusFilter,
            ['all', 'pending', 'approved', 'rejected', 'completed'],
            (value) {
              if (value != null) {
                setState(() {
                  _selectedStatusFilter = value;
                });
                _updateFilters();
              }
            },
          ),
          
          const SizedBox(height: 8),
          
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
          
          const SizedBox(height: 8),
          
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
              const SizedBox(width: 8),
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
          
          const SizedBox(height: 8),
          
          // Search and clear row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Search facility or email',
                    labelStyle: TextStyle(fontSize: 13),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _updateFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
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
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 6),
          
          // Results count
          Text(
            'Showing ${_filteredBookings.length} of ${_myBookings.length}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          DropdownButton<String>(
            value: currentValue,
            isExpanded: true,
            style: const TextStyle(fontSize: 13),
            items: options.map((option) => 
              DropdownMenuItem(
                value: option,
                child: Text(option, style: TextStyle(fontSize: 13)),
              )
            ).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
