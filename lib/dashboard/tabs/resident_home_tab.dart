import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../services/data_service.dart';
import '../../../services/auth_api_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/facility_icon.dart';
import '../../../widgets/base64_image_widget.dart';
import '../../../utils/debug_logger.dart';
import '../../../screens/facility_calendar_screen.dart';
import '../../../screens/booking_form_screen.dart';
import 'resident/my_bookings_page.dart';

class ResidentHomeTab extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const ResidentHomeTab({super.key, this.userData});

  @override
  State<ResidentHomeTab> createState() => _ResidentHomeTabState();
}

class _ResidentHomeTabState extends State<ResidentHomeTab> {
  List<Map<String, dynamic>> _facilities = [];
  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;
  bool _isLoadingFacilities = false;
  AuthApiService _authApiService = AuthApiService.instance;
  
  // Helper function to get facility rate with fallback
  String _getFacilityRate(Map<String, dynamic> facility) {
    // Check multiple possible field names
    final rate = facility['hourly_rate'] ?? facility['rate'] ?? facility['price'] ?? facility['base_rate'];
    if (rate != null) {
      return rate.toString();
    }
    
    // Default rates based on facility type
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
      return '200'; // Default rate
    }
  }

  // Helper function to get facility downpayment with fallback
  String _getFacilityDownpayment(Map<String, dynamic> facility) {
    // Check multiple possible field names
    final downpayment = facility['downpayment_rate'] ?? facility['downpayment'] ?? facility['downpayment_amount'];
    if (downpayment != null) {
      return downpayment.toString();
    }
    
    // Calculate downpayment as 50% of rate
    final rate = double.tryParse(_getFacilityRate(facility)) ?? 200.0;
    return (rate * 0.5).toStringAsFixed(0);
  }

  // Helper function to get facility capacity with fallback
  String _getFacilityCapacity(Map<String, dynamic> facility) {
    // Check multiple possible field names
    final capacity = facility['max_capacity'] ?? facility['capacity'];
    if (capacity != null) {
      return capacity.toString();
    }
    
    // Default capacities based on facility type
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
      return '25'; // Default capacity
    }
  }

  // Helper function to format amenities display
  String _formatAmenities(dynamic amenities) {
    if (amenities == null) return 'No amenities specified';
    
    if (amenities is String) {
      try {
        // Try to parse as JSON array
        List<dynamic> amenitiesList = json.decode(amenities);
        return amenitiesList.join(', ');
      } catch (e) {
        // If not JSON, return as is
        return amenities;
      }
    } else if (amenities is List) {
      return amenities.join(', ');
    }
    
    return amenities.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadFacilities();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Note: Ban checking removed - user will implement new approach
  }

  // Fallback facilities data if API fails
  List<Map<String, dynamic>> _getFallbackFacilities() {
    return [
      {
        'id': 1,
        'name': 'Covered Court',
        'description': 'Multi-purpose covered court for sports and events',
        'amenities': '["Volleyball net", "Badminton setup", "Lighting", "Sound system"]',
        'max_capacity': 50,
        'rate': 300,
        'downpayment': 150,
        'active': true,
      },
      {
        'id': 2,
        'name': 'Meeting Room',
        'description': 'Air-conditioned meeting room with presentation equipment',
        'amenities': '["Projector", "Whiteboard", "Air conditioning", "Tables", "Chairs"]',
        'max_capacity': 15,
        'rate': 150,
        'downpayment': 75,
        'active': true,
      },
      {
        'id': 3,
        'name': 'Multi-Purpose Hall',
        'description': 'Large hall for events and gatherings',
        'amenities': '["Tables", "Chairs", "Sound system", "Air conditioning", "Stage"]',
        'max_capacity': 100,
        'rate': 200,
        'downpayment': 100,
        'active': true,
      },
      {
        'id': 4,
        'name': 'Community Garden',
        'description': 'Outdoor garden space for small gatherings',
        'amenities': '["Garden seating", "Plants", "Shade area"]',
        'max_capacity': 30,
        'rate': 100,
        'downpayment': 50,
        'active': true,
      },
      {
        'id': 5,
        'name': 'Basketball Court',
        'description:': 'Outdoor basketball court with lighting',
        'amenities': '["Basketball hoops", "Lighting", "Scoreboard"]',
        'max_capacity': 20,
        'rate': 250,
        'downpayment': 125,
        'active': true,
      },
    ];
  }

  // Enhanced facility data fetching with better field mapping
  Future<void> _loadFacilities() async {
    if (mounted) {
      setState(() {
        _isLoading = true; // Use the main loading state
        _isLoadingFacilities = true;
      });
    }

    try {
      print('🔍 ResidentHomeTab._loadFacilities - calling DataService.fetchFacilities()');
      
      // Add timeout to prevent infinite loading
      final facilitiesResponse = await DataService.fetchFacilities().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Facility loading timed out after 10 seconds');
        },
      );
      
      if (facilitiesResponse['success'] == true) {
        final List<dynamic> facilitiesData = facilitiesResponse['data'] ?? [];
        print('🔍 ResidentHomeTab._loadFacilities - received ${facilitiesData.length} facilities');
        
        if (mounted) {
          setState(() {
            _facilities = facilitiesData.cast<Map<String, dynamic>>();
            _isLoading = false; // Set loading to false when done
            _isLoadingFacilities = false;
          });
        }
        
        // Debug: Print facility structure
        for (var facility in _facilities) {
          print('🔍 Facility ${facility['id']} structure:');
          print('  - ID: ${facility['id']}');
          print('  - Name: ${facility['name']}');
          print('  - Rate fields: hourly_rate=${facility['hourly_rate']}, rate=${facility['rate']}, price=${facility['price']}');
          print('  - Downpayment fields: downpayment_rate=${facility['downpayment_rate']}, downpayment=${facility['downpayment']}');
          print('  - Capacity fields: max_capacity=${facility['max_capacity']}, capacity=${facility['capacity']}');
          print('  - Icon: ${facility['main_photo_url']}');
          print('  - Amenities: ${facility['amenities']}');
        }
        
        // Check if facilities have pricing data
        final bool hasPricingData = _facilities.any((facility) => 
          facility['hourly_rate'] != null || facility['rate'] != null || facility['price'] != null);
        
        if (!hasPricingData) {
          print('⚠️ WARNING: Facilities missing pricing data - using default values');
        }
        
      } else {
        throw Exception(facilitiesResponse['error'] ?? 'Failed to fetch facilities');
      }
    } catch (e) {
      print('❌ Error loading facilities: $e');
      if (mounted) {
        setState(() {
          _isLoading = false; // Ensure loading is set to false on error
          _isLoadingFacilities = false;
          // Use fallback facilities
          _facilities = _getFallbackFacilities();
        });
        
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using offline facilities data. ${e.toString()}'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _loadFacilities(),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadUserData() async {
    // Use ensureUserLoaded instead of calling restoreUserFromToken directly
    final user = await _authApiService.ensureUserLoaded();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
      print('🔍 ResidentHomeTab - User data updated: ${_authApiService.getUserFullName()}');
      print('🔍 ResidentHomeTab - User email: ${_currentUser?['email']}');
    }
  }

  // Refresh data method
  Future<void> _refreshData() async {
    setState(() {
      _isLoadingFacilities = true;
      _isLoading = true;
    });
    
    // Reload user data and facilities
    await _loadUserData();
    await _loadFacilities();
    
    if (mounted) {
      setState(() {
        _isLoadingFacilities = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Welcome Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Welcome, ${_authApiService.getUserFullName()}!',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Refresh button
                      IconButton(
                        onPressed: _refreshData,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Book facilities for your events',
                    style: TextStyle(fontSize: 16, color: Colors.blue[100]),
                  ),
                  if (_authApiService.getUserContactNumber().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.blue[100]),
                          const SizedBox(width: 4),
                          Text(
                            _authApiService.getUserContactNumber(),
                            style: TextStyle(fontSize: 14, color: Colors.blue[100]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Facilities List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _facilities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_city,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No facilities available',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _facilities.length,
                      itemBuilder: (context, index) {
                        final facility = _facilities[index];
                        return _buildFacilityCard(facility);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilityCard(Map<String, dynamic> facility) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // TODO: Navigate to facility calendar
            _showFacilityCalendar(facility);
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showFacilityImagePreview(facility['main_photo_url'] ?? 'location_city'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FacilityIcon(
                          iconName: facility['main_photo_url'] ?? 'location_city',
                          size: 48,
                          color: Colors.blue[600],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            facility['name'] ?? 'Facility Name',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            facility['description'] ?? 'Facility description',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.blue[600],
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Verification Tags Section (only for verified users)
                if (_isUserVerified()) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getVerificationDiscountColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _getVerificationDiscountColor().withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: _getVerificationDiscountColor(),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getVerificationTagText(),
                          style: TextStyle(
                            color: _getVerificationDiscountColor(),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildInfoChip(
                      icon: Icons.attach_money,
                      label: '₱${_getFacilityRate(facility)}',
                      color: Colors.green,
                    ),
                    _buildInfoChip(
                      icon: Icons.payment,
                      label: '₱${_getFacilityDownpayment(facility)} down',
                      color: Colors.orange,
                    ),
                    _buildInfoChip(
                      icon: Icons.group,
                      label: '${_getFacilityCapacity(facility)} capacity',
                      color: Colors.purple,
                    ),
                    if (_authApiService.isUserVerified())
                      _buildInfoChip(
                        icon: Icons.local_offer,
                        label: '${(_authApiService.getUserDiscountRate() * 100).toStringAsFixed(0)}% discount',
                        color: Colors.red,
                      ),
                  ],
                ),
                // Amenities Section
                if (facility['amenities'] != null && facility['amenities'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Amenities',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatAmenities(facility['amenities']),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
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

  void _showFacilityCalendar(Map<String, dynamic> facility) {
    print('🔍 Opening calendar for facility: ${facility['name']}');
    print('🔍 Passing user data: ${_currentUser?['email']}');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityCalendarScreen(
          facility: facility,
          userData: _currentUser,
        ),
      ),
    ).then((_) {
      // Refresh user data when returning from calendar
      _loadUserData();
    });
  }

  void _showBookingForm(Map<String, dynamic> facility) {
    print('🔍 Opening booking form for facility: ${facility['name']}');
    print('🔍 Passing user data: ${_currentUser?['email']}');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingFormScreen(
          facility: facility,
          selectedDate: DateTime.now(),
          userData: _currentUser,
        ),
      ),
    ).then((result) {
      if (result == true) {
        // Refresh data after successful booking
        _loadFacilities();
      }
    });
  }

  void _showFacilityImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Facility Image',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Image content
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: imageUrl.startsWith('data:image') || (imageUrl.length > 100 && !imageUrl.contains(' '))
                        ? Base64ImageWidget(
                            base64Data: imageUrl,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          )
                        : Center(
                            child: Text(
                              imageUrl,
                              style: const TextStyle(fontSize: 80),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Verification helper methods
  bool _isUserVerified() {
    return _currentUser?['verified'] == true || 
           _currentUser?['verified'] == 1 || 
           _currentUser?['verified'] == 2;
  }

  String _getVerificationTagText() {
    final verified = _currentUser?['verified'];
    if (verified == 1) {
      return 'Verified Resident (10% OFF)';
    } else if (verified == 2) {
      return 'Verified Non-Resident (5% OFF)';
    }
    return 'Verified User';
  }

  Color _getVerificationDiscountColor() {
    final verified = _currentUser?['verified'];
    if (verified == 1) {
      return Colors.green; // Resident gets green for 10%
    } else if (verified == 2) {
      return Colors.orange; // Non-resident gets orange for 5%
    }
    return Colors.blue; // Default blue
  }
}
