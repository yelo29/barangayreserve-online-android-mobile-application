import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/data_service.dart';
import '../../../services/auth_api_service.dart';
import '../../../config/app_config.dart';
import '../../../widgets/loading_widget.dart';
import '../../../utils/debug_logger.dart';
import '../../../screens/booking_detail_screen.dart';

class OfficialBookingRequestsTab extends StatefulWidget {
  final bool isDarkMode;
  const OfficialBookingRequestsTab({super.key, this.isDarkMode = false});

  @override
  State<OfficialBookingRequestsTab> createState() => _OfficialBookingRequestsTabState();
}

class _OfficialBookingRequestsTabState extends State<OfficialBookingRequestsTab> {
  List<Map<String, dynamic>> _pendingBookings = [];
  List<Map<String, dynamic>> _filteredBookings = [];
  bool _isLoading = true;
  String _selectedFacilityFilter = 'all';
  String _selectedSubmittedDateSort = 'none';
  String _selectedBookingDateSort = 'none';
  String _searchQuery = '';
  bool _showFilterMenu = false;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, Map<String, dynamic>> _userProfiles = {};
  final FocusNode _searchFocusNode = FocusNode();

  String _getSafeString(dynamic value) {
    if (value == null) return 'Not provided';
    if (value is String && value.isEmpty) return 'Not provided';
    return value.toString();
  }

  Future<Map<String, dynamic>?> _getUserProfile(String userEmail) async {
    if (_userProfiles.containsKey(userEmail)) {
      return _userProfiles[userEmail];
    }

    try {
      final userProfile = await _fetchUserProfileFromServer(userEmail);
      if (userProfile != null) {
        _userProfiles[userEmail] = userProfile;
      }
      return userProfile;
    } catch (e) {
      DebugLogger.error('❌ Error fetching user profile for $userEmail: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchUserProfileFromServer(String userEmail) async {
    try {
      final headers = await DataService.getHeaders();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/users/profile/$userEmail'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['user'] != null) {
          DebugLogger.ui('Successfully fetched user profile for $userEmail');
          return data['user'];
        }
      }

      DebugLogger.warning('Failed to fetch user profile for $userEmail, using fallback');

      // Fallback for known users
      if (userEmail == 'leo052904@gmail.com') {
        return {
          'email': userEmail,
          'discount_rate': 0.1,
          'verified': true,
          'role': 'resident',
          'fake_booking_violations': 3,
          'is_banned': 1,
        };
      } else if (userEmail == 'saloestillopez@gmail.com') {
        return {
          'email': userEmail,
          'discount_rate': 0.05,
          'verified': true,
          'role': 'resident',
          'fake_booking_violations': 0,
          'is_banned': 0,
        };
      } else if (userEmail == 'resident01@gmail.com') {
        return {
          'email': userEmail,
          'discount_rate': 0.0,
          'verified': false,
          'role': 'resident',
          'fake_booking_violations': 0,
          'is_banned': 0,
        };
      }

      return {
        'email': userEmail,
        'discount_rate': 0.0,
        'verified': false,
        'role': 'resident',
        'fake_booking_violations': 0,
        'is_banned': 0,
      };
    } catch (e) {
      DebugLogger.error('Failed to fetch user profile: $e');
      if (userEmail == 'leo052904@gmail.com') {
        return {
          'email': userEmail,
          'discount_rate': 0.1,
          'verified': true,
          'role': 'resident',
          'fake_booking_violations': 3,
          'is_banned': 1,
        };
      } else if (userEmail == 'saloestillopez@gmail.com') {
        return {
          'email': userEmail,
          'discount_rate': 0.05,
          'verified': true,
          'role': 'resident',
          'fake_booking_violations': 0,
          'is_banned': 0,
        };
      } else if (userEmail == 'resident01@gmail.com') {
        return {
          'email': userEmail,
          'discount_rate': 0.0,
          'verified': false,
          'role': 'resident',
          'fake_booking_violations': 0,
          'is_banned': 0,
        };
      }
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPendingBookings();
  }

  Future<void> _loadPendingBookings({bool forceRefresh = false}) async {
    try {
      DebugLogger.ui('Loading pending bookings for official...');

      if (forceRefresh && mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      final bookingsResponse = await DataService.fetchBookings();

      if (bookingsResponse['success'] == true) {
        final List<Map<String, dynamic>> bookings = bookingsResponse['data'] ?? [];

        final pendingBookings = bookings.where((booking) =>
          booking['status'] == 'pending'
        ).toList();

        if (mounted) {
          setState(() {
            _pendingBookings = pendingBookings;
            _filteredBookings = List.from(pendingBookings);
            _isLoading = false;
          });
        }
      } else {
        throw Exception(bookingsResponse['error'] ?? 'Failed to fetch bookings');
      }
    } catch (e) {
      DebugLogger.error('Error loading pending bookings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _removeBookingFromList(String bookingId) {
    if (mounted) {
      setState(() {
        _pendingBookings.removeWhere((booking) => booking['id'].toString() == bookingId);
        _filteredBookings.removeWhere((booking) => booking['id'].toString() == bookingId);
      });
    }
  }

  void _restoreBookingToList(Map<String, dynamic> booking) {
    if (mounted && booking.isNotEmpty) {
      setState(() {
        _pendingBookings.add(booking);
        _filteredBookings = _applyFilters(_pendingBookings, _selectedFacilityFilter, _selectedSubmittedDateSort, _selectedBookingDateSort, _searchQuery);
      });
    }
  }

  Future<void> _approveBooking(String bookingId) async {
    final bookingToRestore = _pendingBookings.firstWhere(
      (booking) => booking['id'].toString() == bookingId,
      orElse: () => <String, dynamic>{},
    );

    try {
      _removeBookingFromList(bookingId);

      final result = await DataService.updateBookingStatus(int.parse(bookingId), 'approved');

      if (result['success']) {
        _userProfiles.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _restoreBookingToList(bookingToRestore);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to approve booking'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      _restoreBookingToList(bookingToRestore);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectBooking(String bookingId) async {
    final bookingToRestore = _pendingBookings.firstWhere(
      (booking) => booking['id'].toString() == bookingId,
      orElse: () => <String, dynamic>{},
    );

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String selectedReason = 'incorrect_downpayment';

        return AlertDialog(
          backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
          title: Text('Rejection Reason', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87)),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Please select the reason for rejection:', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
                  const SizedBox(height: 16),
                  RadioListTile<String>(
                    title: Text('Rejected (because of incorrect amount of downpayment)', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
                    value: 'incorrect_downpayment',
                    groupValue: selectedReason,
                    onChanged: (String? value) {
                      setState(() {
                        selectedReason = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: Text('Rejected (because of fake receipt/no downpayment/payment)', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
                    value: 'fake_receipt',
                    groupValue: selectedReason,
                    onChanged: (String? value) {
                      setState(() {
                        selectedReason = value!;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('CANCEL', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selectedReason),
              style: ElevatedButton.styleFrom(backgroundColor: widget.isDarkMode ? Colors.red.shade700 : Colors.red),
              child: const Text('REJECT'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        String rejectionReason = '';
        String rejectionType = result;

        if (rejectionType == 'incorrect_downpayment') {
          rejectionReason = 'The amount of your down payment is incorrect, please pay appropriate amount next time';
        } else if (rejectionType == 'fake_receipt') {
          rejectionReason = 'Your payment receipt is fake or shown no payment in our payment history/records, ⚠️ know that this violation will be recorded and you will only have three chances before getting your account banned!';
        }

        _removeBookingFromList(bookingId);

        final apiResult = await DataService.updateBookingStatus(
          int.parse(bookingId),
          'rejected',
          rejectionReason: rejectionReason,
          rejectionType: rejectionType,
        );

        if (apiResult['success']) {
          _userProfiles.clear();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking rejected successfully!'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          _restoreBookingToList(bookingToRestore);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(apiResult['message'] ?? 'Failed to reject booking'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        _restoreBookingToList(bookingToRestore);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewReceipt(String? receiptUrl) {
    if (receiptUrl != null && receiptUrl.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
          title: Text('Payment Receipt', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87)),
          content: SizedBox(
            width: 300,
            height: 400,
            child: receiptUrl.startsWith('data:image')
                ? Image.memory(
                    base64Decode(receiptUrl.split(',')[1]),
                    fit: BoxFit.contain,
                  )
                : Image.network(receiptUrl),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No receipt available')),
      );
    }
  }

  Widget _buildDetailRow(String label, dynamic value) {
    final displayValue = value?.toString() ?? 'N/A';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> bookings, String facilityFilter, String submittedDateSort, String bookingDateSort, String searchQuery) {
    List<Map<String, dynamic>> filtered = List.from(bookings);

    if (facilityFilter != 'all') {
      filtered = filtered.where((booking) {
        final facilityName = (booking['facility_name']?.toString() ??
                            booking['facilityName']?.toString() ??
                            'Unknown Facility').toLowerCase();
        return facilityName == facilityFilter.toLowerCase();
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((booking) {
        final facilityName = (booking['facility_name']?.toString() ??
                            booking['facilityName']?.toString() ??
                            'Unknown Facility').toLowerCase();
        final fullName = (booking['full_name']?.toString() ?? '').toLowerCase();
        final userEmail = (booking['user_email']?.toString() ?? 'Unknown User').toLowerCase();
        return facilityName.contains(query) || fullName.contains(query) || userEmail.contains(query);
      }).toList();
    }

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

    return filtered;
  }

  void _updateFilters() {
    setState(() {
      _filteredBookings = _applyFilters(_pendingBookings, _selectedFacilityFilter, _selectedSubmittedDateSort, _selectedBookingDateSort, _searchQuery);
    });
  }

  List<String> _getUniqueFacilities(List<Map<String, dynamic>> bookings) {
    final Set<String> facilities = {};
    for (final booking in bookings) {
      final facilityName = (booking['facility_name']?.toString() ??
                          booking['facilityName']?.toString() ??
                          'Unknown Facility');
      facilities.add(facilityName);
    }
    final facilityList = facilities.toList();
    facilityList.sort();
    return facilityList;
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    _userProfiles.clear();
    await _loadPendingBookings(forceRefresh: true);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildProfilePhoto(Map<String, dynamic> booking) {
    final profilePhotoUrl = booking['profile_photo_url'] as String?;

    if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
      if (profilePhotoUrl.startsWith('data:image')) {
        return Image.memory(
          base64Decode(profilePhotoUrl.split(',')[1]),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
        );
      } else if (profilePhotoUrl.startsWith('http')) {
        return Image.network(
          profilePhotoUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
        );
      } else if (profilePhotoUrl.startsWith('/9j/')) {
        return Image.memory(
          base64Decode(profilePhotoUrl),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
        );
      }
    }

    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.grey.shade900 : Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Booking Requests',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _refreshData,
                    icon: Icon(Icons.refresh, color: widget.isDarkMode ? Colors.white : Colors.black),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildFilterControls(),
              const SizedBox(height: 12),

              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_filteredBookings.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 60, color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? "No requests match your filters"
                              : "No pending requests",
                          style: TextStyle(fontSize: 18, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                        ),
                        if (_searchQuery.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedFacilityFilter = 'all';
                                _selectedSubmittedDateSort = 'none';
                                _selectedBookingDateSort = 'none';
                                _searchQuery = '';
                                _searchController.clear();
                              });
                              _updateFilters();
                            },
                            child: const Text('Clear Filters'),
                          ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredBookings.length,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                    itemBuilder: (context, index) {
                      final booking = _filteredBookings[index];
                      final facilityName = booking['facility_name'] ?? booking['facilityName'] ?? 'Unknown Facility';
                      final date = booking['booking_date'] ?? booking['date'] ?? '';
                      String submittedDate = '';
                      if (booking['created_at'] != null) {
                        try {
                          final dateTime = DateTime.parse(booking['created_at']);
                          final philippinesTime = dateTime.add(const Duration(hours: 8));
                          submittedDate = '${philippinesTime.year}-${philippinesTime.month.toString().padLeft(2, '0')}-${philippinesTime.day.toString().padLeft(2, '0')} ${philippinesTime.hour.toString().padLeft(2, '0')}:${philippinesTime.minute.toString().padLeft(2, '0')}';
                        } catch (e) {
                          submittedDate = booking['created_at'].toString().split('T')[0] ?? '';
                        }
                      }
                      final timeslot = booking['start_time'] ?? booking['timeslot'] ?? '';
                      final fullName = booking['full_name']?.isNotEmpty == true ? booking['full_name'] : booking['user_email'] ?? 'Unknown User';
                      final contactNumber = _getSafeString(booking['contact_number'] ?? booking['contactNumber']);
                      final receiptUrl = booking['receiptBase64'] ?? booking['receipt_base64'];
                      final bookingId = booking['id'].toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () async {
                            _searchFocusNode.unfocus();
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookingDetailScreen(booking: booking, isDarkMode: widget.isDarkMode),
                              ),
                            );

                            if (result == true) {
                              _loadPendingBookings(forceRefresh: true);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min, // Changed to min to prevent overflow
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(25),
                                        border: Border.all(color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(25),
                                        child: _buildProfilePhoto(booking),
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

                                    if (receiptUrl != null && receiptUrl.isNotEmpty)
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: receiptUrl.startsWith('data:image')
                                              ? Image.memory(
                                                  base64Decode(receiptUrl.split(',')[1]),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      decoration: BoxDecoration(
                                                        color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Icon(Icons.receipt_long, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey, size: 24),
                                                    );
                                                  },
                                                )
                                              : Image.network(
                                                  receiptUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      decoration: BoxDecoration(
                                                        color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Icon(Icons.receipt_long, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey, size: 24),
                                                    );
                                                  },
                                                ),
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.receipt_long, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey, size: 24),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                if (receiptUrl != null && receiptUrl.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: widget.isDarkMode ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.receipt, size: 16, color: widget.isDarkMode ? Colors.green.shade400 : Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Receipt Attached',
                                          style: TextStyle(
                                            color: widget.isDarkMode ? Colors.green.shade400 : Colors.green.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 8),

                                _buildDetailRow('Booking Date', date),
                                _buildDetailRow('Submitted Date', submittedDate),
                                _buildDetailRow('Time', timeslot),
                                _buildDetailRow('Name', fullName),
                                _buildDetailRow('Contact', contactNumber),

                                const SizedBox(height: 10),
                                FutureBuilder<Map<String, dynamic>?>(
                                  future: _getUserProfile(booking['user_email'] ?? ''),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const SizedBox.shrink();
                                    }
                                    return _buildDiscountTag(booking, snapshot.data);
                                  },
                                ),

                                const SizedBox(height: 12),

                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        _searchFocusNode.unfocus();
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => BookingDetailScreen(booking: booking, isDarkMode: widget.isDarkMode),
                                          ),
                                        );

                                        if (result == true) {
                                          _loadPendingBookings(forceRefresh: true);
                                        }
                                      },
                                      icon: const Icon(Icons.visibility, size: 16),
                                      label: const Text('Details', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: widget.isDarkMode ? Colors.red.shade400 : Colors.red,
                                        side: BorderSide(color: widget.isDarkMode ? Colors.red.shade400 : Colors.red),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        minimumSize: const Size(0, 36),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _approveBooking(bookingId),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Approve', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: widget.isDarkMode ? Colors.green.shade700 : Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        minimumSize: const Size(0, 36),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _rejectBooking(bookingId),
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Reject', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: widget.isDarkMode ? Colors.red.shade700 : Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        minimumSize: const Size(0, 36),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
      ),
    );
  }

  Widget _buildDiscountTag(Map<String, dynamic> booking, Map<String, dynamic>? userProfile) {
    double discountRate = 0.0;
    String discountType = 'No Discount';
    Color tagColor = widget.isDarkMode ? Colors.grey.shade600 : Colors.grey;

    if (booking['discount_rate'] != null && booking['discount_rate'] > 0) {
      discountRate = (booking['discount_rate'] is String
          ? double.tryParse(booking['discount_rate']) ?? 0.0
          : (booking['discount_rate'] ?? 0.0).toDouble());
    } else if (userProfile != null && userProfile['discount_rate'] != null && userProfile['discount_rate'] > 0) {
      discountRate = (userProfile['discount_rate'] is String
          ? double.tryParse(userProfile['discount_rate']) ?? 0.0
          : (userProfile['discount_rate'] ?? 0.0).toDouble());
    }

    if (discountRate == 0.1) {
      discountType = '10% OFF';
      tagColor = Colors.green;
    } else if (discountRate == 0.05) {
      discountType = '5% OFF';
      tagColor = Colors.blue;
    }

    int violations = userProfile?['fake_booking_violations'] ?? 0;
    dynamic bannedValue = userProfile?['is_banned'] ?? false;
    bool isBanned = bannedValue is bool ? bannedValue : (bannedValue == 1 || bannedValue == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tagColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tagColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_offer, size: 14, color: tagColor),
              const SizedBox(width: 4),
              Text(
                discountType,
                style: TextStyle(fontSize: 11, color: tagColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        if (violations > 0 || isBanned) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isBanned ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBanned ? Colors.red.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isBanned ? Icons.block : Icons.warning,
                  size: 14,
                  color: isBanned ? Colors.red : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  isBanned ? 'BANNED' : '$violations/3 VIOLATIONS',
                  style: TextStyle(
                    fontSize: 10,
                    color: isBanned ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterControls() {
    final uniqueFacilities = _getUniqueFacilities(_pendingBookings);

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
          Row(
            children: [
              Text(
                'Filter Requests',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black),
              ),
              const Spacer(),
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

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Search facility, name, or email',
                    labelStyle: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search, size: 18, color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black),
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
                    _selectedFacilityFilter = 'all';
                    _selectedSubmittedDateSort = 'none';
                    _selectedBookingDateSort = 'none';
                    _searchQuery = '';
                    _searchController.clear();
                  });
                  _updateFilters();
                },
                icon: Icon(Icons.clear_all, size: 16, color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black),
                label: Text('Clear', style: TextStyle(fontSize: 11, color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            'Showing ${_filteredBookings.length} of ${_pendingBookings.length}',
            style: TextStyle(fontSize: 11, color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String currentValue, List<String> options, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: widget.isDarkMode ? Colors.white : Colors.black)),
        const SizedBox(height: 2),
        DropdownButton<String>(
          value: currentValue,
          isExpanded: true,
          dropdownColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
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
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}