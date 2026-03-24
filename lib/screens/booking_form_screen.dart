import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../../services/data_service.dart';
import '../../../services/auth_api_service.dart';
import '../../../services/api_service.dart';
import '../../../services/ban_validation_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../utils/debug_logger.dart';
import '../../../screens/facility_calendar_screen.dart';
import '../../../config/app_config.dart';

class BookingFormScreen extends StatefulWidget {
  final Map<String, dynamic> facility;
  final DateTime selectedDate;
  final Map<String, dynamic>? userData;

  const BookingFormScreen({
    super.key,
    required this.facility,
    required this.selectedDate,
    this.userData,
  });

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _purposeController = TextEditingController();
  final _receiptDetailsController = TextEditingController();
  
  String _selectedTimeSlot = '';
  File? _receiptImage;
  bool _isLoading = false;
  bool _isLoadingTimeSlots = true;
  bool _userHasExistingBooking = false;
  
  final List<String> _timeSlots = [
    '6:00 AM - 8:00 AM',
    '8:00 AM - 10:00 AM',
    '10:00 AM - 12:00 PM',
    '12:00 PM - 2:00 PM',
    '2:00 PM - 4:00 PM',
    '4:00 PM - 6:00 PM',
    '6:00 PM - 8:00 PM',
    '8:00 PM - 10:00 PM',
  ];
  
  Map<String, String> _timeSlotStatuses = {};
  final ImagePicker _imagePicker = ImagePicker();

  // Helper function to convert time slot ID to time slot string
  String? _getTimeSlotFromId(dynamic timeSlotId) {
    if (timeSlotId == null) return null;
    
    final Map<int, String> timeSlotMap = {
      1: '6:00 AM - 8:00 AM',
      2: '8:00 AM - 10:00 AM',
      3: '10:00 AM - 12:00 PM',
      4: '12:00 PM - 2:00 PM',
      5: '2:00 PM - 4:00 PM',
      6: '4:00 PM - 6:00 PM',
      7: '6:00 PM - 8:00 PM',
      8: '8:00 PM - 10:00 PM',
    };
    
    final int? slotId = int.tryParse(timeSlotId.toString());
    if (slotId == null) return null;
    
    // Handle wrap-around for IDs > 8
    final int wrappedId = ((slotId - 1) % 8) + 1;
    return timeSlotMap[wrappedId] ?? 'Time Slot $slotId';
  }

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

  // Get auth service instance
  AuthApiService? get _authApiService {
    try {
      return AuthApiService.instance;
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTimeSlotAvailability();
    _loadUserData(); // Add auto-fill functionality
    // Note: Ban checking removed - user will implement new approach
  }

  // Auto-fill user data from profile
  Future<void> _loadUserData() async {
    try {
      // Get current user data
      final authApiService = AuthApiService.instance;
      final currentUser = await authApiService.ensureUserLoaded();
      
      if (currentUser != null) {
        setState(() {
          _nameController.text = currentUser['full_name'] ?? '';
          _contactController.text = currentUser['contact_number'] ?? '';
          _addressController.text = currentUser['address'] ?? '';
        });
        print('🔍 Booking Form - Auto-filled with user data:');
        print('  - Full Name: "${_nameController.text}"');
        print('  - Contact: "${_contactController.text}"');
        print('  - Address: "${_addressController.text}"');
      }
    } catch (e) {
      print('❌ Error auto-filling user data: $e');
    }
  }

  // Helper method to check if current user is an official
  bool get _isOfficial {
    final String currentUserEmail = widget.userData?['email'] ?? '';
    return currentUserEmail.contains('official') || 
           currentUserEmail.contains('barangay') ||
           currentUserEmail.contains('admin');
  }

  Future<void> _loadTimeSlotAvailability() async {
    if (mounted) {
      setState(() {
        _isLoadingTimeSlots = true;
      });
    }

    try {
      print('🔍 Loading time slot availability for date: ${widget.selectedDate.toIso8601String().split('T')[0]}');
      
      // Use the real-time availability API instead of fetchBookings
      final selectedDate = widget.selectedDate.toIso8601String().split('T')[0];
      final availabilityResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/available-timeslots?facility_id=${widget.facility['id']}&date=$selectedDate'),
        headers: await ApiService.getHeaders(),
      ).then((response) async {
        final data = json.decode(response.body);
        return {
          'success': response.statusCode == 200,
          'data': data,
          'statusCode': response.statusCode
        };
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout after 10 seconds');
        },
      );
      
      if (availabilityResponse['success'] == true) {
        final data = availabilityResponse['data'];
        final List<String> availableSlots = List<String>.from(data['available_timeslots'] ?? []);
        final List<String> userBookedSlots = List<String>.from(data['user_booked_timeslots'] ?? []);
        final List<String> competitiveSlots = List<String>.from(data['competitive_timeslots'] ?? []);
        
        print('🔍 Available slots: ${availableSlots.length}');
        print('🔍 User booked slots: ${userBookedSlots.length}');
        print('🔍 Competitive slots: ${competitiveSlots.length}');
        
        // Initialize all time slots with their real-time status
        Map<String, String> statusMap = {};
        for (String timeSlot in _timeSlots) {
          if (availableSlots.contains(timeSlot)) {
            statusMap[timeSlot] = 'available';
          } else if (userBookedSlots.contains(timeSlot)) {
            statusMap[timeSlot] = 'booked'; // Could be pending or approved
          } else if (competitiveSlots.contains(timeSlot)) {
            statusMap[timeSlot] = 'competitive';
          } else {
            statusMap[timeSlot] = 'available'; // Default to available
          }
        }
        
        // Get current user's bookings to determine if booked slots are pending or approved
        String currentUserEmail = widget.userData?['email'] ?? '';
        if (currentUserEmail.isNotEmpty && userBookedSlots.isNotEmpty) {
          try {
            final bookingsResponse = await DataService.fetchBookings(
              facilityId: widget.facility['id'].toString(),
              date: widget.selectedDate.toIso8601String().split('T')[0],
            );
            
            if (bookingsResponse['success'] == true) {
              final List<Map<String, dynamic>> allBookings = List<Map<String, dynamic>>.from(bookingsResponse['data'] ?? []);
              
              // Filter bookings for current user
              final userBookings = allBookings.where((booking) {
                return booking['user_email'] == currentUserEmail;
              }).toList();
              
              // Update status for user's own bookings
              for (final booking in userBookings) {
                String? bookingTimeSlot = booking['time_slot'] ?? booking['timeslot'];
                
                // Try to construct from start_time and end_time
                if (bookingTimeSlot == null) {
                  final startTime = booking['start_time'] ?? '';
                  final endTime = booking['end_time'] ?? '';
                  if (startTime.isNotEmpty && endTime.isNotEmpty) {
                    bookingTimeSlot = '$startTime - $endTime';
                  }
                }
                
                // Find matching time slot
                if (bookingTimeSlot != null) {
                  for (String displaySlot in _timeSlots) {
                    if (displaySlot.contains(bookingTimeSlot) || bookingTimeSlot.contains(displaySlot)) {
                      String bookingStatus = booking['status'] ?? 'pending';
                      if (bookingStatus == 'approved') {
                        statusMap[displaySlot] = 'approved';
                      } else if (bookingStatus == 'pending') {
                        statusMap[displaySlot] = 'pending';
                      }
                      break;
                    }
                  }
                }
              }
            }
          } catch (e) {
            print('⚠️ Could not fetch user bookings: $e');
          }
        }
        
        if (mounted) {
          setState(() {
            _timeSlotStatuses = statusMap;
            _isLoadingTimeSlots = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading time slot availability: $e');
      if (mounted) {
        setState(() {
          _isLoadingTimeSlots = false;
        });
        
        // Show user-friendly error message
        String errorMessage = 'Failed to load time slots';
        if (e.toString().contains('Network is unreachable') || 
            e.toString().contains('Connection failed')) {
          errorMessage = 'Network connection failed. Please check your internet connection.';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Connection timeout. Please try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _loadTimeSlotAvailability(),
            ),
          ),
        );
      }
    }
  }

  void _showOfficialTimeSlotDetails(String timeSlot) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading booking details...'),
          ],
        ),
      ),
    );

    try {
      // Fetch all bookings to get detailed information
      final bookingsResponse = await DataService.fetchBookings();
      
      if (bookingsResponse['success'] == true) {
        final List<Map<String, dynamic>> allBookings = List<Map<String, dynamic>>.from(bookingsResponse['data'] ?? []);
        final String selectedDate = widget.selectedDate.toIso8601String().split('T')[0];
        
        // Filter bookings for this facility, date, and time slot
        List<Map<String, dynamic>> timeSlotBookings = allBookings.where((booking) {
          final String bookingDate = booking['date'] ?? booking['booking_date'] ?? '';
          String? bookingTimeSlot = booking['time_slot'] ?? booking['timeslot'];
          
          if (bookingTimeSlot == null && booking['time_slot_id'] != null) {
            bookingTimeSlot = _getTimeSlotFromId(booking['time_slot_id']);
          }
          
          return booking['facility_id'] == widget.facility['id'] && 
                 bookingDate == selectedDate &&
                 bookingTimeSlot == timeSlot;
        }).toList();

        // Close loading dialog
        Navigator.of(context).pop();

        if (timeSlotBookings.isEmpty) {
          // No bookings found
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Time Slot Details'),
              content: Text('No bookings found for $timeSlot'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
          return;
        }

        // Show booking details dialog
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Time Slot: $timeSlot',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.selectedDate.toString().split(' ')[0],
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Existing Bookings:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          ...timeSlotBookings.map((booking) => _buildBookingDetailCard(booking)),
                        ],
                      ),
                    ),
                  ),
                  
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Contact residents to coordinate refunds if you proceed with booking.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to load booking details: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildBookingDetailCard(Map<String, dynamic> booking) {
    final String status = booking['status'] ?? 'pending';
    final Color statusColor = status == 'approved' ? Colors.green : Colors.orange;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: statusColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
        color: statusColor.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  status == 'approved' ? Icons.check_circle : Icons.pending,
                  color: statusColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  'Refund: ₱${booking['total_amount'] ?? '0'}',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Booking details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Name:', booking['full_name'] ?? 'N/A'),
                _buildDetailRow('Email:', booking['user_email'] ?? 'N/A'),
                _buildDetailRow('Contact:', booking['contact_number'] ?? 'N/A'),
                _buildDetailRow('Purpose:', booking['purpose'] ?? 'N/A'),
                const SizedBox(height: 12),
                
                // Receipt image if available
                if (booking['receipt_base64'] != null && booking['receipt_base64'].toString().isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Receipt:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(booking['receipt_base64'].toString().split(',').last),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade100,
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, color: Colors.grey),
                                      Text('Receipt image not available'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.grey.shade600, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'No receipt uploaded',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
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
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReceiptImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (pickedFile != null && mounted) {
        setState(() {
          _receiptImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // 🔒 BAN VALIDATION: Check if user is banned before allowing booking
    final banValidation = await BanValidationService.validateUserForBooking();
    if (!banValidation['allowed']) {
      if (mounted) {
        BanValidationService.showBanDialog(context, banValidation);
      }
      return;
    }
    
    if (_selectedTimeSlot.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }
    
    if (!_isOfficial && _receiptImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a payment receipt'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare booking data
      Map<String, dynamic> bookingData = {
        'facility_id': widget.facility['id'],
        'user_email': widget.userData?['email'] ?? 'user@example.com',
        'date': widget.selectedDate.toIso8601String().split('T')[0],
        'timeslot': _selectedTimeSlot,
        'total_amount': widget.facility['hourly_rate'] ?? widget.facility['rate'] ?? widget.facility['price'] ?? widget.facility['base_rate'] ?? 0,
        'status': _isOfficial ? 'approved' : 'pending', // Officials get auto-approved
      };

      // Add personal information only for residents
      if (!_isOfficial) {
        bookingData['full_name'] = _nameController.text;
        bookingData['contact_number'] = _contactController.text;
        bookingData['address'] = _addressController.text;
        bookingData['purpose'] = _purposeController.text;
      } else {
        // For officials, use data from userData
        bookingData['full_name'] = widget.userData?['name'] ?? 'Barangay Official';
        bookingData['contact_number'] = widget.userData?['contact_number'] ?? '';
        bookingData['address'] = widget.userData?['address'] ?? 'Barangay Hall';
        bookingData['purpose'] = 'Official barangay business';
      }

      // Add receipt if available (only for residents)
      if (_receiptImage != null) {
        final bytes = await _receiptImage!.readAsBytes();
        bookingData['receipt_base64'] = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        bookingData['receipt_filename'] = _receiptImage!.path.split('/').last;
      }

      // Submit booking using API service
      final result = await ApiService.createBooking(bookingData);
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isOfficial ? 'Facility booked successfully!' : 'Booking submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          // Check if this is a ban error
          if (result['error_type'] == 'user_banned') {
            // Show ban dialog instead of generic error
            BanValidationService.showBanDialog(context, {
              'reason': 'Account is banned',
              'ban_reason': result['ban_reason'] ?? 'Account has been banned by administrator.'
            });
          } else {
            // Show generic error for other cases
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to submit booking: ${result['error'] ?? 'Unknown error'}')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting booking: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book ${widget.facility['name']}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning for existing booking
              if (_userHasExistingBooking)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You already have a booking for this date. You can create additional bookings if needed.',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Facility Details Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.business, color: Colors.blue.shade700, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.facility['name'] ?? 'Facility Name',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Date: ${DateFormat.yMMMMd().format(widget.selectedDate)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailChip(
                              icon: Icons.attach_money,
                              label: '₱${_getFacilityRate(widget.facility)}',
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDetailChip(
                              icon: Icons.payment,
                              label: '₱${_getFacilityDownpayment(widget.facility)} down',
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Personal Information Section - Only for residents
              if (!_isOfficial) ...[
                _buildSectionHeader('Personal Information*', Icons.person),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: _buildInputDecoration(
                            'Full Name*',
                            'Enter your full name',
                            Icons.person,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contactController,
                          decoration: _buildInputDecoration(
                            'Contact Number*',
                            'Enter your contact number',
                            Icons.phone,
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your contact number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: _buildInputDecoration(
                            'Address*',
                            'Enter your complete address',
                            Icons.location_on,
                          ),
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _purposeController,
                          decoration: _buildInputDecoration(
                            'Purpose of Booking*',
                            'Describe the purpose of your booking',
                            Icons.description,
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the purpose of booking';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Time Slot Selection Section
              _buildSectionHeader('Select Time Slot*', Icons.access_time),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time Slot Container (takes most space)
                  Expanded(
                    flex: 9,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isLoadingTimeSlots)
                              const Center(child: CircularProgressIndicator())
                            else
                              Container(
                                constraints: const BoxConstraints(maxHeight: 600), // Increased from 500 to 600
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const ClampingScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 1.1, // Increased from 1.1 to make buttons taller
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: _timeSlots.length,
                            itemBuilder: (context, index) {
                              final timeSlot = _timeSlots[index];
                              final status = _timeSlotStatuses[timeSlot] ?? 'available';
                              Color backgroundColor;
                              Color textColor;
                              bool isDisabled = false;
                              IconData statusIcon;

                              switch (status) {
                                case 'approved':
                                  backgroundColor = Colors.green.shade100;
                                  textColor = Colors.green.shade700;
                                  isDisabled = true; // Approved bookings - untappable for residents, tappable for officials to see details
                                  statusIcon = Icons.check_circle;
                                  break;
                                case 'pending':
                                  backgroundColor = Colors.yellow.shade100;
                                  textColor = Colors.orange.shade700;
                                  isDisabled = true; // Pending bookings - untappable for residents, tappable for officials to see details
                                  statusIcon = Icons.pending;
                                  break;
                                case 'booked':
                                  backgroundColor = Colors.grey.shade100; // Gray for booked slots by other residents
                                  textColor = Colors.grey.shade700;
                                  isDisabled = true; // Booked slots - untappable for residents, tappable for officials to see details
                                  statusIcon = Icons.block;
                                  break;
                                case 'competitive':
                                  backgroundColor = Colors.red.shade50;
                                  textColor = Colors.red.shade700;
                                  isDisabled = true; // Competitive slots - untappable for residents
                                  statusIcon = Icons.priority_high;
                                  break;
                                case 'available':
                                default:
                                  backgroundColor = Colors.white;
                                  textColor = Colors.black87;
                                  isDisabled = false;
                                  statusIcon = Icons.access_time;
                              }

                              return InkWell(
                                onTap: () {
                                  final String currentUserEmail = widget.userData?['email'] ?? '';
                                  final bool isOfficial = currentUserEmail.contains('official') || 
                                                         currentUserEmail.contains('barangay') ||
                                                         currentUserEmail.contains('admin');
                                  
                                  if (isOfficial && (status == 'pending' || status == 'approved' || status == 'booked')) {
                                    // Officials can tap booked slots to see details
                                    _showOfficialTimeSlotDetails(timeSlot);
                                  } else if (!isDisabled) {
                                    // Only available slots can be selected for booking
                                    setState(() {
                                      _selectedTimeSlot = timeSlot;
                                    });
                                  }
                                  // Residents cannot tap booked slots (isDisabled = true)
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: backgroundColor,
                                    border: Border.all(
                                      color: _selectedTimeSlot == timeSlot
                                          ? Colors.blue
                                          : Colors.grey.shade300,
                                      width: _selectedTimeSlot == timeSlot ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        statusIcon,
                                        color: textColor,
                                        size: 16,
                                      ),
                                      const SizedBox(height: 1),
                                      Flexible(
                                        child: Text(
                                          timeSlot,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: _selectedTimeSlot == timeSlot
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 12, // Increased from 10 to 12
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2, // Increased from 1 to 2
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (status != 'available') ...[
                                        const SizedBox(height: 1),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: textColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
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
                  ),
                  
                 
                 
                ],
              ),
              const SizedBox(height: 16),

              // GCash Payment Information - Only for residents
              if (!_isOfficial) ...[
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payment, color: Colors.green, size: 24),
                            const SizedBox(width: 8),
                            const Text(
                              'GCash Payment Guide',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // QR Code Section
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // QR Code Image
                              GestureDetector(
                                onTap: () => _showQRCodeFullScreen(),
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      children: [
                                        Image.asset(
                                          'assets/images/qr_codes/qr-code-merchant-image.jpg',
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(
                                              Icons.qr_code_scanner, 
                                              size: 48, 
                                              color: Colors.grey.shade400,
                                            );
                                          },
                                        ),
                                        // Tap indicator
                                        Positioned(
                                          bottom: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              Icons.fullscreen,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'QR Code Scan to pay',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Merchant Number: 09079267391\n'
                                'Merchant Name: JO*N RO**C A\n'
                                'Tap to view full screen',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Payment Instructions
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Instructions:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '1. Tap the QR code above to view full screen\n'
                                '2. Scan using GCash app\n'
                                '3. Enter the exact amount shown\n'
                                '4. Take a screenshot of the payment confirmation\n'
                                '5. Upload the receipt below',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _showDetailedPaymentGuide,
                                icon: const Icon(Icons.help_outline),
                                label: const Text('Detailed Guide'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _openGCashApp,
                                icon: const Icon(Icons.account_balance_wallet),
                                label: const Text('Open GCash'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Receipt Upload Section - Only for residents
              if (!_isOfficial) ...[
                _buildSectionHeader('Upload Receipt *', Icons.receipt),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '!Payment receipt is required to complete booking\n'
                    '!Please upload a clear photo of your payment receipt\n'
                    '!Before submitting your booking request, make sure to fill out personal information first',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _pickReceiptImage,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            height: 150,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade50,
                            ),
                            child: _receiptImage != null
                                ? Stack(
                                    children: [
                                      Image.file(_receiptImage!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.check, color: Colors.white, size: 20),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.cloud_upload, size: 48, color: Colors.grey.shade400),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap to upload receipt *',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Required for booking submission',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isOfficial ? 'Quick Book Facility' : 'Submit Booking',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (!_isOfficial && _receiptImage == null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.warning, size: 18, color: Colors.yellow),
                            ] else if (!_isOfficial) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.check_circle, size: 18, color: Colors.white),
                            ] else ...[
                              const SizedBox(width: 8),
                              Icon(Icons.flash_on, size: 18, color: Colors.white),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.blue.shade700),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailedPaymentGuide() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    Icon(Icons.payment, color: Colors.green, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Complete GCash Payment Guide',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '📱 Getting Started:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Make sure you have GCash app installed\n• Ensure you have sufficient balance\n• Have your MPIN ready',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  '🔍 Detailed Steps:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailedStep('1', 'Tap the QR code to view full screen'),
                _buildDetailedStep('2', 'Open your GCash app'),
                _buildDetailedStep('3', 'Tap "Scan QR" or QR code icon'),
                _buildDetailedStep('4', 'Scan the merchant QR code'),
                _buildDetailedStep('5', 'Enter the amount: ₱${_getFacilityRate(widget.facility)}'),
                _buildDetailedStep('6', 'Confirm payment details'),
                _buildDetailedStep('7', 'Enter your MPIN to complete'),
                _buildDetailedStep('8', 'Screenshot the payment confirmation'),
                const SizedBox(height: 16),
                const Text(
                  '⚠️ Important Notes:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Payment is non-refundable\n• Keep the payment confirmation screenshot\n• Upload the receipt in the form below\n• Contact support if payment fails',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Got it!'),
                  ),
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailedStep(String step, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$step ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Open GCash app or Play Store
  Future<void> _openGCashApp() async {
    // Use the gcash:// scheme to trigger the app
    final Uri gcashUri = Uri.parse("gcash://");
    
    try {
      // Check if the app is installed
      if (await canLaunchUrl(gcashUri)) {
        await launchUrl(
          gcashUri, 
          mode: LaunchMode.externalApplication, // This forces Android to open the native app
        );
      } else {
        // If GCash is not installed, redirect them to the Play Store
        final Uri playStoreUri = Uri.parse("market://details?id=com.globe.gcash.android");
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print("Could not launch GCash: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open GCash: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showQRCodeFullScreen() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                children: [
                  // Header with close button
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // QR Code - takes most of the screen with zoom capability
                  Expanded(
                    child: InteractiveViewer(
                      panEnabled: true,
                      boundaryMargin: const EdgeInsets.all(20),
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Large QR Code with zoom
                            Container(
                              width: MediaQuery.of(context).size.width * 0.9,
                              height: MediaQuery.of(context).size.height * 0.6,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/images/qr_codes/qr-code-merchant-image.jpg',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        Icons.qr_code_scanner,
                                        size: 100,
                                        color: Colors.grey.shade400,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // Instructions
                            const Text(
                              'Scan this QR Code with GCash',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Pinch to zoom in for better scanning',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tap the X button to close',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
