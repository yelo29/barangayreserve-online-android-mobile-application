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

  const FacilityEditScreen({super.key, this.facility});

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
      appBar: AppBar(
        title: Text(
          widget.facility == null
              ? 'Add New Facility'
              : 'Edit ${widget.facility!['name'] ?? 'Facility'}',
        ),
        backgroundColor: Colors.blue,
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
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
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
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Tap to add facility image',
                                    style: TextStyle(
                                      color: Colors.grey,
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
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 24),

              // Basic Information
              const Text(
                'Basic Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Facility Name',
                  hintText: 'Enter facility name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
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
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter facility description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
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
                decoration: const InputDecoration(
                  labelText: 'Capacity',
                  hintText: 'e.g., 50 people',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
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
              const Text(
                'Pricing Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _rateController,
                decoration: const InputDecoration(
                  labelText: 'Rate',
                  hintText: 'e.g., ₱500 per 2 hours',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
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
                decoration: const InputDecoration(
                  labelText: 'Downpayment Amount',
                  hintText: 'e.g., ₱200',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_wallet),
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
              const Text(
                'Amenities',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amenitiesController,
                decoration: const InputDecoration(
                  labelText: 'Available Amenities',
                  hintText: 'e.g., Tables, Chairs, Sound System, Lights',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.list),
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
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade600),
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
                    backgroundColor: Colors.blue,
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
