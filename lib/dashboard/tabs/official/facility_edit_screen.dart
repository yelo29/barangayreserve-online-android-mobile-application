import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../services/data_service.dart';
import '../../../services/auth_api_service.dart';
import '../../../services/base64_image_service.dart';
import '../../../utils/debug_logger.dart';
import '../../../widgets/base64_image_widget.dart';

class FacilityEditScreen extends StatefulWidget {
  final Map<String, dynamic>? facility;
  final bool isDarkMode;

  const FacilityEditScreen({super.key, this.facility, this.isDarkMode = false});

  @override
  State<FacilityEditScreen> createState() => _FacilityEditScreenState();
}

class _FacilityEditScreenState extends State<FacilityEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _downpaymentController = TextEditingController();
  final TextEditingController _amenitiesController = TextEditingController();

  // Image picker variables
  String? _selectedImageBase64;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    if (widget.facility != null) {
      _nameController.text = widget.facility!['name']?.toString() ?? '';
      _descriptionController.text =
          widget.facility!['description']?.toString() ?? '';
      _capacityController.text = widget.facility!['max_capacity']?.toString() ?? '';
      _rateController.text = widget.facility!['hourly_rate']?.toString() ?? '';
      _downpaymentController.text =
          widget.facility!['downpayment_rate']?.toString() ?? '';
      _amenitiesController.text =
          widget.facility!['amenities']?.toString() ?? '';
      
      // Load existing image from main_photo_url field
      if (widget.facility!['main_photo_url'] != null && widget.facility!['main_photo_url'].toString().isNotEmpty) {
        _selectedImageBase64 = widget.facility!['main_photo_url']?.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    _rateController.dispose();
    _downpaymentController.dispose();
    _amenitiesController.dispose();
    super.dispose();
  }

  // Image picker method
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        
        // Convert to base64
        final base64String = await Base64ImageService.imageToBase64(imageFile);
        
        if (base64String != null) {
          setState(() {
            _selectedImageBase64 = base64String;
          });
          
          DebugLogger.success('Image selected successfully');
        } else {
          DebugLogger.error('Failed to convert image to base64');
        }
      }
    } catch (e) {
      DebugLogger.error('Error picking image', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveFacility() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Prepare facility data with image
      final Map<String, dynamic> facilityData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'capacity': _capacityController.text.trim(),
        'price': _rateController.text.trim(),
        'downpayment': _downpaymentController.text.trim(),
        'amenities': _amenitiesController.text.trim(),
        'image_url': _selectedImageBase64 ?? '', // Use base64 image
        'active': true,
      };

      bool success = false;
      String successMessage = 'Failed to save facility';

      // Get user role from AuthApiService
      final userData = await AuthApiService.instance.getCurrentUser();
      final String? role = userData?['role'];
      DebugLogger.api('User role: $role');

      if (role == 'official') {
        DebugLogger.api('Using Server API for official user');
        if (widget.facility == null || widget.facility!['id'] == null) {
          // Create new facility via server
          DebugLogger.api('Creating new facility via server');
          facilityData['createdAt'] = DateTime.now().toIso8601String();
          final result = await DataService.createFacility(facilityData);
          DebugLogger.api('Create facility result: $result');
          success = result['success'] ?? false;
          successMessage = success
              ? 'Facility created successfully!'
              : result['message'] ?? 'Failed to create facility';
        } else {
          // Update facility via server
          DebugLogger.api('Updating facility ${widget.facility!['id']} via server');
          facilityData['updatedAt'] = DateTime.now().toIso8601String();
          final result = await DataService.updateFacility(
            widget.facility!['id'].toString(),
            facilityData,
          );
          DebugLogger.api('Update facility result: $result');
          success = result['success'] ?? false;
          successMessage = success
              ? 'Facility updated successfully!'
              : result['message'] ?? 'Failed to update facility';
        }
      } else {
        DebugLogger.warning('Role is not official, using server fallback. Role: $role');
        // Always use server API
        if (widget.facility == null || widget.facility!['id'] == null) {
          facilityData['createdAt'] = DateTime.now().toIso8601String();
          final result = await DataService.createFacility(facilityData);
          success = result['success'];
          successMessage = result['success']
              ? 'Facility created successfully!'
              : result['message'] ?? 'Failed to create facility';
        } else {
          facilityData['updatedAt'] = DateTime.now().toIso8601String();
          final result = await DataService.updateFacility(
            widget.facility!['id'].toString(),
            facilityData,
          );
          success = result['success'];
          successMessage = result['success']
              ? 'Facility updated successfully!'
              : result['message'] ?? 'Failed to update facility';
        }
      }

      if (!success) {
        throw Exception(
          widget.facility == null
              ? 'Failed to create facility'
              : 'Failed to update facility',
        );
      }

      // Show success message and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error updating facility: $e';
        });
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
      backgroundColor: widget.isDarkMode ? Colors.grey.shade900 : Colors.white,
      appBar: AppBar(
        title: Text(
          widget.facility == null
              ? 'Add New Facility'
              : 'Edit ${widget.facility!['name'] ?? 'Facility'}',
        ),
        backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveFacility,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Facility Image Picker
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade50,
                ),
                child: Stack(
                  children: [
                    // Display selected image or placeholder
                    _selectedImageBase64 != null
                        ? Base64ImageWidget(
                            base64Data: _selectedImageBase64,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(12),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 48,
                                    color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to add facility image',
                                    style: TextStyle(
                                      color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                          ),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap camera icon to upload facility image',
                style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 24),

              // Basic Information
              Text(
                'Basic Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Facility Name',
                  labelStyle: TextStyle(color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black87),
                  hintText: 'Enter facility name',
                  hintStyle: TextStyle(color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey),
                  ),
                  prefixIcon: Icon(Icons.business, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black87),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter facility name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black87),
                  hintText: 'Enter facility description',
                  hintStyle: TextStyle(color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey),
                  ),
                  prefixIcon: Icon(Icons.description, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black87),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter facility description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _capacityController,
                style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Capacity',
                  labelStyle: TextStyle(color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black87),
                  hintText: 'e.g., 50 people',
                  hintStyle: TextStyle(color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey),
                  ),
                  prefixIcon: Icon(Icons.people, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black87),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter facility capacity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Pricing Information
              Text(
                'Pricing Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _rateController,
                style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Rate',
                  labelStyle: TextStyle(color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black87),
                  hintText: 'e.g., ₱500 per 2 hours',
                  hintStyle: TextStyle(color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey),
                  ),
                  prefixIcon: Icon(Icons.attach_money, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black87),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter facility rate';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _downpaymentController,
                style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Downpayment Amount',
                  labelStyle: TextStyle(color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black87),
                  hintText: 'e.g., ₱200',
                  hintStyle: TextStyle(color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey),
                  ),
                  prefixIcon: Icon(Icons.account_balance_wallet, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black87),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter downpayment amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Amenities
              Text(
                'Amenities',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amenitiesController,
                style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Available Amenities',
                  labelStyle: TextStyle(color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black87),
                  hintText: 'e.g., Tables, Chairs, Sound System, Lights',
                  hintStyle: TextStyle(color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey),
                  ),
                  prefixIcon: Icon(Icons.list, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black87),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter available amenities';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: widget.isDarkMode ? Colors.red.shade700 : Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: widget.isDarkMode ? Colors.red.shade400 : Colors.red.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: widget.isDarkMode ? Colors.red.shade400 : Colors.red.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveFacility,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isDarkMode ? Colors.blue.shade700 : Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Saving...'),
                          ],
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
