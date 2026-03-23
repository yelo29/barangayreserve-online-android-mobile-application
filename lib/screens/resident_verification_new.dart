import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/base64_image_service.dart';
import '../services/ban_validation_service.dart';
import '../services/auth_api_service.dart';

class ResidentVerificationScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  
  const ResidentVerificationScreen({super.key, this.userData});

  @override
  State<ResidentVerificationScreen> createState() => _ResidentVerificationScreenState();
}

class _ResidentVerificationScreenState extends State<ResidentVerificationScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  
  // State variables
  String _selectedVerificationType = '';
  bool _isLoading = false;
  File? _profileImage;
  File? _idImage;
  String? _profileImageUrl;
  String? _idImageUrl;
  // State variables for form locking
  bool _canSubmit = true;
  String _lockMessage = "";
  bool _isVerifiedResident = false;
  bool _isVerifiedNonResident = false;
  
  @override
  void initState() {
    super.initState();
    _initializeForm();
    _checkVerificationStatus();
  }

  void _checkVerificationStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final authApiService = AuthApiService.instance;
      _isVerifiedResident = authApiService.isVerifiedResident();
      _isVerifiedNonResident = authApiService.isVerifiedNonResident();
      
      // Check verification status for form locking
      final verificationStatus = await AuthApiService.getVerificationStatus();
      
      setState(() {
        _canSubmit = verificationStatus?['can_submit'] ?? true;
        _lockMessage = verificationStatus?['lock_message'] ?? "";
        _isLoading = false;
      });
      
      print('🔍 Verification Status Check:');
      print('  - Can Submit: $_canSubmit');
      print('  - Lock Message: $_lockMessage');
      print('  - Current Status: ${verificationStatus?['current_status']}');
      
    } catch (e) {
      print('❌ Error checking verification status: $e');
      setState(() => _isLoading = false);
    }
  }

  void _initializeForm() async {
    // Auto-fill user data from latest profile
    try {
      final authApiService = AuthApiService.instance;
      final currentUser = await authApiService.ensureUserLoaded();
      
      if (currentUser != null) {
        setState(() {
          _nameController.text = currentUser['full_name'] ?? '';
          _contactController.text = currentUser['contact_number'] ?? '';
          _addressController.text = currentUser['address'] ?? '';
        });
        print('🔍 Verification Form - Auto-filled with latest profile data:');
        print('  - Full Name: "${_nameController.text}"');
        print('  - Contact: "${_contactController.text}"');
        print('  - Address: "${_addressController.text}"');
      } else if (widget.userData != null) {
        // Fallback to widget data if current user not available
        setState(() {
          _nameController.text = widget.userData!['fullName'] ?? '';
          _contactController.text = widget.userData!['contactNumber'] ?? '';
          _addressController.text = widget.userData!['address'] ?? '';
        });
        print('🔍 Verification Form - Auto-filled with widget data (fallback):');
        print('  - Full Name: "${_nameController.text}"');
        print('  - Contact: "${_contactController.text}"');
        print('  - Address: "${_addressController.text}"');
      }
    } catch (e) {
      print('❌ Error auto-filling verification form: $e');
      // Fallback to widget data
      if (widget.userData != null) {
        setState(() {
          _nameController.text = widget.userData!['fullName'] ?? '';
          _contactController.text = widget.userData!['contactNumber'] ?? '';
          _addressController.text = widget.userData!['address'] ?? '';
        });
        print('🔍 Verification Form - Fallback to widget data:');
        print('  - Full Name: "${_nameController.text}"');
        print('  - Contact: "${_contactController.text}"');
        print('  - Address: "${_addressController.text}"');
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        print('🔍 DEBUG: Profile image picked - path: ${pickedFile.path}');
        try {
          final file = File(pickedFile.path);
          if (await file.exists()) {
            setState(() {
              _profileImage = file;
            });
            print('✅ DEBUG: Profile image file created successfully');
          } else {
            print('❌ DEBUG: Profile image file does not exist at path: ${pickedFile.path}');
          }
        } catch (e) {
          print('❌ DEBUG: Error creating File from XFile: $e');
        }
      }
    } catch (e) {
      print('❌ Error uploading images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking profile image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickIdImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        print('🔍 DEBUG: ID image picked - path: ${pickedFile.path}');
        try {
          final file = File(pickedFile.path);
          if (await file.exists()) {
            setState(() {
              _idImage = file;
            });
            print('✅ DEBUG: ID image file created successfully');
          } else {
            print('❌ DEBUG: ID image file does not exist at path: ${pickedFile.path}');
          }
        } catch (e) {
          print('❌ DEBUG: Error creating File from XFile: $e');
        }
      }
    } catch (e) {
      print('❌ Error uploading images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking ID image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _uploadImages() async {
    if (_profileImage == null || _idImage == null) return false;

    try {
      // Get user ID from server user data
      final authApiService = AuthApiService.instance;
      final userData = await authApiService.ensureUserLoaded();
      final userId = userData?['id']?.toString() ?? 'unknown';
      
      // Upload profile image as Base64
      _profileImageUrl = await Base64ImageService.uploadVerificationPhoto(
        photoImage: _profileImage,
        userId: userId,
        type: 'profile',
      );

      // Upload ID image as Base64
      _idImageUrl = await Base64ImageService.uploadVerificationPhoto(
        photoImage: _idImage,
        userId: userId,
        type: 'id',
      );

      if (_profileImageUrl != null && _idImageUrl != null) {
        print('✅ Profile image converted to base64: ${(_profileImageUrl!.length / 1024).toStringAsFixed(2)} KB');
        print('✅ ID image converted to base64: ${(_idImageUrl!.length / 1024).toStringAsFixed(2)} KB');
      }

      return _profileImageUrl != null && _idImageUrl != null;
    } catch (e) {
      print('Error uploading images: $e');
      return false;
    }
  }

  Future<void> _submitVerification() async {
    // Check if form can be submitted
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_lockMessage),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;

    if (_selectedVerificationType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select verification type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_profileImage == null || _idImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both profile photo and ID photo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check ban status first
      final banValidation = await BanValidationService.validateUserForVerification();
      if (!banValidation['allowed']) {
        BanValidationService.showBanDialog(context, banValidation);
        return;
      }

      // Upload images first
      final uploadSuccess = await _uploadImages();
      
      if (!uploadSuccess) {
        throw Exception('Failed to upload images');
      }

      // Create verification request
      final authApiService = AuthApiService.instance;
      final currentUser = await authApiService.ensureUserLoaded();
      
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final verificationData = {
        'residentId': currentUser['id'],
        'fullName': _nameController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'address': _addressController.text.trim(),
        'verificationType': _selectedVerificationType,
        'userPhotoUrl': _profileImageUrl,
        'validIdUrl': _idImageUrl,
        'status': 'pending',
        'submittedAt': DateTime.now().toIso8601String(),
      };

      // Submit verification request to server
      final result = await ApiService.createVerificationRequest(verificationData);
      
      if (result['success']) {
        // Update verification status after successful submission
        await AuthApiService.updateVerificationStatus({
          'success': true,
          'can_submit': false,
          'lock_message': 'You already submitted a Verification Request! wait for officials to either Reject or Approve your request',
          'current_status': 'pending_request',
          'verified': result['user']?['verified'] ?? 0,
          'verification_type': result['user']?['verification_type'],
          'user_id': result['user']?['id'],
          'email': result['user']?['email'],
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        // Check if it's a ban error
        if (result['error_type'] == 'user_banned') {
          print('🚫 Ban error detected: ${result['message']}');
          BanValidationService.showBanDialog(context, result);
        } else {
          print('❌ Verification error: ${result['message']}');
          throw Exception(result['message'] ?? 'Failed to submit verification');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting verification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text('Account Verification'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lock Message Display
              if (!_canSubmit) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[600], size: 24),
                      const SizedBox(height: 8),
                      Text(
                        _lockMessage,
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
              
              // Verification Info Card
              _buildInfoCard(),

              const SizedBox(height: 24),

              // Personal Information Section
              _buildSectionCard(
                title: 'Personal Information*',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: _buildInputDecoration('Full Name*', Icons.person),
                      enabled: _canSubmit, // Lock based on verification status
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
                      decoration: _buildInputDecoration('Contact Number*', Icons.phone),
                      keyboardType: TextInputType.phone,
                      enabled: _canSubmit, // Lock based on verification status
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
                      decoration: _buildInputDecoration('Complete Address*', Icons.location_on),
                      maxLines: 2,
                      enabled: _canSubmit, // Lock based on verification status
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildVerificationTypeSelector(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Photo Upload Section
              _buildPhotoUploadSection(),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_canSubmit && !_isLoading) ? _submitVerification : null, // Lock based on verification status
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.verified_user),
                  label: Text(_isLoading ? 'Submitting...' : 'Submit Verification'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSubmit ? Colors.blue : Colors.grey, // Blue for enabled, grey for locked
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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

  Widget _buildInfoCard() {
    // Determine content based on verification status
    String mainTitle, subtitle;
    
    if (_isVerifiedResident) {
      mainTitle = "Congrats on being Verified Resident!";
      subtitle = "Enjoy your 10% Discount on all Facility Bookings!";
    } else if (_isVerifiedNonResident) {
      mainTitle = "Upgrade Verified Status for Discounts";
      subtitle = "Upgrade your Verified account to get a higher discounts on facility bookings";
    } else {
      mainTitle = "Get Verified for Discounts";
      subtitle = "Verify your account to get exclusive discounts on facility bookings";
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _isVerifiedResident ? Icons.verified : Icons.verified_user,
                  color: _isVerifiedResident ? Colors.green : Colors.blue[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mainTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isVerifiedResident ? Colors.green : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildDiscountChip('Resident', '10% OFF', Colors.green),
              const SizedBox(width: 8),
              _buildDiscountChip('Non-Resident', '5% OFF', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountChip(String type, String discount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            type,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            discount,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verification Type*',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: (_canSubmit && !_isVerifiedResident) ? () { // Lock if canSubmit is false OR already verified resident
                  setState(() {
                    _selectedVerificationType = 'resident';
                  });
                } : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedVerificationType == 'resident' ? Colors.blue : ((_canSubmit && !_isVerifiedResident) ? Colors.grey[100] : Colors.grey[50]),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedVerificationType == 'resident' ? Colors.blue : ((_canSubmit && !_isVerifiedResident) ? Colors.grey[300]! : Colors.grey[200]!),
                    ),
                  ),
                  child: Text(
                    'Barangay Resident',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _selectedVerificationType == 'resident' ? Colors.white : ((_canSubmit && !_isVerifiedResident) ? Colors.black87 : Colors.grey[400]),
                      fontWeight: _selectedVerificationType == 'resident' ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: (_canSubmit && !_isVerifiedNonResident) ? () { // Lock if canSubmit is false OR already verified non-resident
                  setState(() {
                    _selectedVerificationType = 'non-resident';
                  });
                } : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedVerificationType == 'non-resident' ? Colors.blue : ((_canSubmit && !_isVerifiedNonResident) ? Colors.grey[100] : Colors.grey[50]),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedVerificationType == 'non-resident' ? Colors.blue : ((_canSubmit && !_isVerifiedNonResident) ? Colors.grey[300]! : Colors.grey[200]!),
                    ),
                  ),
                  child: Text(
                    'Non-Resident',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _selectedVerificationType == 'non-resident' ? Colors.white : ((_canSubmit && !_isVerifiedNonResident) ? Colors.black87 : Colors.grey[400]),
                      fontWeight: _selectedVerificationType == 'non-resident' ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoUploadSection() {
    return _buildSectionCard(
      title: 'Upload Documents*',
      child: Column(
        children: [
          // Profile Photo Upload
          _buildImageUploadCard(
            title: 'Profile Photo*',
            subtitle: 'Upload a clear photo of yourself',
            image: _profileImage,
            onTap: _canSubmit ? () {
              // Create synchronous wrapper for async function
              _pickProfileImage();
            } : null, // Lock based on canSubmit
            onRemove: _canSubmit ? () { // Lock based on canSubmit
              setState(() {
                _profileImage = null;
              });
            } : null,
          ),
          const SizedBox(height: 16),
          // Valid ID Upload
          _buildImageUploadCard(
            title: 'Valid ID*',
            subtitle: 'Upload government-issued ID',
            image: _idImage,
            onTap: _canSubmit ? () {
              // Create synchronous wrapper for async function
              _pickIdImage();
            } : null, // Lock based on canSubmit
            onRemove: _canSubmit ? () { // Lock based on canSubmit
              setState(() {
                _idImage = null;
              });
            } : null,
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadCard({
    required String title,
    required String subtitle,
    File? image,
    VoidCallback? onTap,  // Make nullable
    VoidCallback? onRemove,  // Make nullable
  }) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          if (image != null)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      image!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  if (!_canSubmit) // Only show remove button for users who can submit
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _canSubmit ? Colors.grey[100] : Colors.grey[200], // Darker grey for locked
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[300]!, 
                  style: BorderStyle.solid,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _canSubmit ? onTap : null, // Lock based on canSubmit
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _canSubmit ? Icons.cloud_upload : Icons.lock,
                        size: 32,
                        color: _canSubmit ? Colors.grey[400] : Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _canSubmit ? 'Tap to upload' : 'Locked',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPG, PNG up to 5MB',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}
