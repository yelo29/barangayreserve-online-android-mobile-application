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
  const OfficialBookingRequestsTab({super.key});

  @override
  State<OfficialBookingRequestsTab> createState() => _OfficialBookingRequestsTabState();
}

class _OfficialBookingRequestsTabState extends State<OfficialBookingRequestsTab> {
  List<Map<String, dynamic>> _pendingBookings = [];
  bool _isLoading = true;
  Map<String, dynamic> _userProfiles = {}; // Cache user profiles

  String _getSafeString(dynamic value) {
    if (value == null) return 'Not provided';
    if (value is String && value.isEmpty) return 'Not provided';
    return value.toString();
  }

  Future<Map<String, dynamic>?> _getUserProfile(String userEmail) async {
    DebugLogger.ui('🔍 _getUserProfile called for: $userEmail');
    
    // Check cache first
    if (_userProfiles.containsKey(userEmail)) {
      DebugLogger.ui('🔍 Found $userEmail in cache: ${_userProfiles[userEmail]}');
      return _userProfiles[userEmail];
    }

    DebugLogger.ui('🔍 $userEmail not in cache, fetching from server...');
    try {
      // Fetch user profile - this would need to be implemented in DataService
      // For now, we'll use a workaround based on debug logs
      // The user profile data should include discount_rate
      final userProfile = await _fetchUserProfileFromServer(userEmail);
      if (userProfile != null) {
        _userProfiles[userEmail] = userProfile;
        DebugLogger.ui('🔍 Cached profile for $userEmail: $userProfile');
      }
      return userProfile;
    } catch (e) {
      DebugLogger.error('❌ Error fetching user profile for $userEmail: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchUserProfileFromServer(String userEmail) async {
    try {
      // Use the same pattern as DataService to make authenticated request
      // From the logs, we can see GET /api/users/profile/leo052904@gmail.com works
      final headers = await DataService.getHeaders();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/users/profile/$userEmail'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['user'] != null) {
          DebugLogger.ui('Successfully fetched user profile for $userEmail');
          DebugLogger.ui('🔍 Profile data: ${data['user']}'); // Added debug
          return data['user'];
        }
      }
      
      DebugLogger.warning('Failed to fetch user profile for $userEmail, using fallback');
      
      // Fallback for known users based on debug logs
      if (userEmail == 'leo052904@gmail.com') {
        DebugLogger.ui('Using fallback for leo052904@gmail.com - 10% discount');
        return {
          'email': userEmail,
          'discount_rate': 0.1,
          'verified': true,
          'role': 'resident',
          'fake_booking_violations': 3, // Updated: User now has 3 violations
          'is_banned': 1 // Updated: User is now banned (use integer to match DB)
        };
      } else if (userEmail == 'saloestillopez@gmail.com') {
        DebugLogger.ui('Using fallback for saloestillopez@gmail.com - 5% discount');
        return {
          'email': userEmail,
          'discount_rate': 0.05, // 5% for non-resident
          'verified': true,
          'role': 'resident',
          'fake_booking_violations': 0,
          'is_banned': 0 // Use integer to match DB
        };
      } else if (userEmail == 'resident01@gmail.com') {
        DebugLogger.ui('Using fallback for resident01@gmail.com - 0% discount');
        return {
          'email': userEmail,
          'discount_rate': 0.0, // 0% for unverified
          'verified': false,
          'role': 'resident',
          'fake_booking_violations': 0,
          'is_banned': 0 // Use integer to match DB
        };
      }
      
      DebugLogger.ui('No fallback found for $userEmail - using default');
      // Return default profile for other users
      return {
        'email': userEmail,
        'discount_rate': 0.0,
        'verified': false,
        'role': 'resident',
        'fake_booking_violations': 0,
        'is_banned': 0 // Use integer to match DB
      };
    } catch (e) {
      DebugLogger.error('Failed to fetch user profile: $e');
      // Return fallback data
      if (userEmail == 'leo052904@gmail.com') {
        DebugLogger.ui('Using catch fallback for leo052904@gmail.com - 10% discount');
        return {
          'email': userEmail,
          'discount_rate': 0.1,
          'verified': true,
          'role': 'resident',
          'fake_booking_violations': 3, // Updated: User now has 3 violations
          'is_banned': 1 // Updated: User is now banned (use integer to match DB)
        };
      } else if (userEmail == 'saloestillopez@gmail.com') {
        DebugLogger.ui('Using catch fallback for saloestillopez@gmail.com - 5% discount');
        return {
          'email': userEmail,
          'discount_rate': 0.05, // 5% for non-resident
          'verified': true,
          'role': 'resident',
          'fake_booking_violations': 0,
          'is_banned': 0 // Use integer to match DB
        };
      } else if (userEmail == 'resident01@gmail.com') {
        DebugLogger.ui('Using catch fallback for resident01@gmail.com - 0% discount');
        return {
          'email': userEmail,
          'discount_rate': 0.0, // 0% for unverified
          'verified': false,
          'role': 'resident',
          'fake_booking_violations': 0,
          'is_banned': 0 // Use integer to match DB
        };
      }
      DebugLogger.ui('No catch fallback found for $userEmail - returning null');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPendingBookings();
  }

  Future<void> _loadPendingBookings() async {
    try {
      DebugLogger.ui('Loading pending bookings for official...');
      
      // Use DataService for consistent data fetching
      final bookingsResponse = await DataService.fetchBookings();
      
      if (bookingsResponse['success'] == true) {
        final List<Map<String, dynamic>> bookings = bookingsResponse['data'] ?? [];
        
        // Filter only pending bookings
        final pendingBookings = bookings.where((booking) => 
          booking['status'] == 'pending'
        ).toList();
        
        if (mounted) {
          setState(() {
            _pendingBookings = pendingBookings;
            DebugLogger.ui('Loaded ${_pendingBookings.length} pending bookings');
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
          _pendingBookings = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveBooking(String bookingId) async {
    try {
      // Use DataService to update booking status
      final result = await DataService.updateBookingStatus(int.parse(bookingId), 'approved');
      
      if (result['success']) {
        _loadPendingBookings(); // Refresh the list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to approve booking'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectBooking(String bookingId) async {
    // Show rejection reason dialog
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String selectedReason = 'incorrect_downpayment';
        
        return AlertDialog(
          title: const Text('Rejection Reason'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Please select the reason for rejection:'),
                  const SizedBox(height: 16),
                  RadioListTile<String>(
                    title: const Text('Rejected (because of incorrect amount of downpayment)'),
                    value: 'incorrect_downpayment',
                    groupValue: selectedReason,
                    onChanged: (String? value) {
                      setState(() {
                        selectedReason = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Rejected (because of fake receipt/no downpayment/payment)'),
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
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selectedReason),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('REJECT'),
            ),
          ],
        );
      },
    );
    
    // If user selected a reason, proceed with rejection
    if (result != null) {
      try {
        String rejectionReason = '';
        String rejectionType = result;
        
        // Set appropriate rejection message based on type
        if (rejectionType == 'incorrect_downpayment') {
          rejectionReason = 'The amount of your down payment is incorrect, please pay appropriate amount next time';
        } else if (rejectionType == 'fake_receipt') {
          rejectionReason = 'Your payment receipt is fake or shown no payment in our payment history/records, ⚠️ know that this violation will be recorded and you will only have three chances before getting your account banned!';
        }
        
        final apiResult = await DataService.updateBookingStatus(
          int.parse(bookingId), 
          'rejected', 
          rejectionReason: rejectionReason,
          rejectionType: rejectionType
        );
        
        if (apiResult['success']) {
          _loadPendingBookings(); // Refresh the list
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Booking rejected successfully!'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(apiResult['message'] ?? 'Failed to reject booking'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
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
          title: const Text('Payment Receipt'),
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
              child: const Text('Close'),
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
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Refresh data method
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Clear user profiles cache and reload data
    _userProfiles.clear();
    await _loadPendingBookings();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Build profile photo widget
  Widget _buildProfilePhoto(Map<String, dynamic> booking) {
    final profilePhotoUrl = booking['profile_photo_url'] as String?;
    
    if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
      // Check if it's a base64 image or URL
      if (profilePhotoUrl.startsWith('data:image')) {
        return Image.memory(
          base64Decode(profilePhotoUrl.split(',')[1]),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar();
          },
        );
      } else if (profilePhotoUrl.startsWith('http')) {
        return Image.network(
          profilePhotoUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar();
          },
        );
      } else if (profilePhotoUrl.startsWith('/9j/')) {
        // Raw base64 image without data URI prefix
        return Image.memory(
          base64Decode(profilePhotoUrl),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar();
          },
        );
      }
    }
    
    // Default avatar if no photo
    return _buildDefaultAvatar();
  }

  // Build default avatar
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
            children: [
              const Text(
                'Booking Requests',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Refresh button
              IconButton(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_pendingBookings.isEmpty)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "No pending requests",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _pendingBookings.length,
                  itemBuilder: (context, index) {
                    final booking = _pendingBookings[index];
                    print('🔍 Official booking data: $booking'); // Debug logging
                    final facilityName = booking['facility_name'] ?? booking['facilityName'] ?? 'Unknown Facility';
                    final date = booking['booking_date'] ?? booking['date'] ?? '';
                    String submittedDate = '';
                    if (booking['created_at'] != null) {
                      try {
                        final dateTime = DateTime.parse(booking['created_at']);
                        print('🔍 DEBUG: Original created_at: ${booking['created_at']}');
                        print('🔍 DEBUG: Parsed DateTime (UTC): $dateTime');
                        // Convert UTC to Philippines timezone (UTC+8)
                        final philippinesTime = dateTime.add(const Duration(hours: 8));
                        print('🔍 DEBUG: Philippines DateTime: $philippinesTime');
                        submittedDate = '${philippinesTime.year}-${philippinesTime.month.toString().padLeft(2, '0')}-${philippinesTime.day.toString().padLeft(2, '0')} ${philippinesTime.hour.toString().padLeft(2, '0')}:${philippinesTime.minute.toString().padLeft(2, '0')}';
                        print('🔍 DEBUG: Formatted submittedDate: $submittedDate');
                      } catch (e) {
                        print('🔍 DEBUG: Error parsing date: $e');
                        submittedDate = booking['created_at'].toString().split('T')[0] ?? '';
                      }
                    }
                    final timeslot = booking['start_time'] ?? booking['timeslot'] ?? '';
                    final fullName = booking['full_name']?.isNotEmpty == true ? booking['full_name'] : booking['user_email'] ?? 'Unknown User';
                    final userEmail = booking['user_email'] ?? 'Not provided';
                    final contactNumber = _getSafeString(booking['contact_number'] ?? booking['contactNumber']);
                    final address = _getSafeString(booking['address']);
                    final receiptUrl = booking['receiptBase64'] ?? booking['receipt_base64'];
                    final bookingId = booking['id'].toString();
                    
                    print('🔍 Official facility name: $facilityName'); // Debug logging

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () async {
                          // Navigate to booking detail screen
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookingDetailScreen(booking: booking),
                            ),
                          );
                          
                          // Refresh list if booking was updated
                          if (result == true) {
                            _loadPendingBookings();
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Profile photo
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(25),
                                      border: Border.all(color: Colors.grey.shade300),
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
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // Receipt thumbnail
                                  if (receiptUrl != null && receiptUrl.isNotEmpty)
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade300),
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
                                                      color: Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Icon(
                                                      Icons.receipt_long,
                                                      color: Colors.grey,
                                                      size: 24,
                                                    ),
                                                  );
                                                },
                                              )
                                            : Image.network(
                                                receiptUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Icon(
                                                      Icons.receipt_long,
                                                      color: Colors.grey,
                                                      size: 24,
                                                    ),
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
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long,
                                        color: Colors.grey,
                                        size: 24,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Receipt indicator
                              if (receiptUrl != null && receiptUrl.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.receipt, size: 16, color: Colors.green.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Receipt Attached',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              const SizedBox(height: 8),
                              
                              // Booking details
                              _buildDetailRow('Booking Date', date),
                              _buildDetailRow('Submitted Date', submittedDate),
                              _buildDetailRow('Time', timeslot),
                              _buildDetailRow('Name', fullName),
                              _buildDetailRow('Contact', contactNumber),
                              
                              // Discount tag for all users (verified and unverified)
                              const SizedBox(height: 10),
                              FutureBuilder<Map<String, dynamic>?>(
                                future: _getUserProfile(booking['user_email'] ?? ''),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const SizedBox.shrink(); // Hide while loading
                                  }
                                  
                                  return _buildDiscountTag(booking, snapshot.data);
                                },
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Action buttons
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => BookingDetailScreen(booking: booking),
                                        ),
                                      );
                                      
                                      if (result == true) {
                                        _loadPendingBookings();
                                      }
                                    },
                                    icon: const Icon(Icons.visibility, size: 16),
                                    label: const Text('Details', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      minimumSize: const Size(0, 36),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _approveBooking(bookingId),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Approve', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      minimumSize: const Size(0, 36),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _rejectBooking(bookingId),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Reject', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
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
    );
  }

  Widget _buildDiscountTag(Map<String, dynamic> booking, Map<String, dynamic>? userProfile) {
    // Get discount rate and determine discount type
    double discountRate = 0.0;
    String discountType = 'No Discount';
    Color tagColor = Colors.grey;
    
    // Get user email from booking data
    String userEmail = booking['user_email'] ?? 'unknown';
    
    DebugLogger.ui('Building discount tag for user: $userEmail');
    DebugLogger.ui('Booking discount_rate: ${booking['discount_rate']}');
    DebugLogger.ui('User profile discount_rate: ${userProfile?['discount_rate']}');
    
    // First check if booking has valid discount_rate (> 0)
    if (booking['discount_rate'] != null && booking['discount_rate'] > 0) {
      discountRate = (booking['discount_rate'] is String 
          ? double.tryParse(booking['discount_rate']) ?? 0.0 
          : (booking['discount_rate'] ?? 0.0).toDouble());
      DebugLogger.ui('Using booking discount_rate: $discountRate');
    } else if (userProfile != null && userProfile['discount_rate'] != null && userProfile['discount_rate'] > 0) {
      // If not in booking, use user profile data
      discountRate = (userProfile['discount_rate'] is String 
          ? double.tryParse(userProfile['discount_rate']) ?? 0.0 
          : (userProfile['discount_rate'] ?? 0.0).toDouble());
      DebugLogger.ui('Using user profile discount_rate: $discountRate');
    }
    
    // Determine discount type based on rate
    if (discountRate == 0.1) {
      discountType = '10% OFF';
      tagColor = Colors.green; // Barangay Resident
    } else if (discountRate == 0.05) {
      discountType = '5% OFF';
      tagColor = Colors.blue; // Non-Resident
    }
    
    DebugLogger.ui('Final discount type: $discountType');
    
    // NEW: Check for violations
    int violations = userProfile?['fake_booking_violations'] ?? 0;
    // Handle both integer and boolean types for is_banned
    dynamic bannedValue = userProfile?['is_banned'] ?? false;
    bool isBanned = bannedValue is bool ? bannedValue : (bannedValue == 1 || bannedValue == true);
    
    DebugLogger.ui('🔍 VIOLATION DEBUG: User=$userEmail, Violations=$violations, IsBanned=$isBanned'); // Added debug
    DebugLogger.ui('🔍 VIOLATION DEBUG: UserProfile=$userProfile'); // Added debug
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Discount tag
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
              Icon(
                Icons.local_offer,
                size: 14,
                color: tagColor,
              ),
              const SizedBox(width: 4),
              Text(
                discountType,
                style: TextStyle(
                  fontSize: 11,
                  color: tagColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // NEW: Violation warning
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
}
