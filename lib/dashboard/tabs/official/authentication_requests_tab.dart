import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../../services/data_service.dart';
import '../../../services/auth_api_service.dart';
import '../../../services/auto_refresh_service.dart';

class OfficialAuthenticationTab extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final Function(BuildContext)? onLogout;
  final bool isDarkMode;

  const OfficialAuthenticationTab({super.key, required this.userData, this.onLogout, this.isDarkMode = false});

  @override
  State<OfficialAuthenticationTab> createState() => _OfficialAuthenticationTabState();
}

class _OfficialAuthenticationTabState extends State<OfficialAuthenticationTab> with AutoRefreshMixin {
  List<Map<String, dynamic>> _verificationRequests = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  bool _showFilterMenu = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initAutoRefresh('verification_requests');
    registerRefreshCallback(() {
      if (mounted) _loadVerificationRequests();
    });
    _loadVerificationRequests();
  }

  Future<void> _loadVerificationRequests() async {
    try {
      final response = await DataService.getVerificationRequests();

      setState(() {
        if (response['success'] == true) {
          final responseData = response['data'];
          if (responseData == null) {
            _verificationRequests = [];
          } else if (responseData is List) {
            _verificationRequests = List<Map<String, dynamic>>.from(responseData);
          } else if (responseData is Map) {
            if (responseData.containsKey('data') && responseData['data'] is List) {
              _verificationRequests = List<Map<String, dynamic>>.from(responseData['data']);
            } else {
              _verificationRequests = [Map<String, dynamic>.from(responseData)];
            }
          } else {
            _verificationRequests = [];
          }

          _verificationRequests = _verificationRequests.map((request) {
            return {
              'id': request['id'],
              'user_id': request['user_id'],
              'verification_type': request['verificationType'],
              'requested_discount_rate': request['discountRate'],
              'user_photo_base64': request['userPhotoUrl'],
              'valid_id_base64': request['validIdUrl'],
              'status': request['status'],
              'residential_address': request['address'],
              'created_at': request['submittedAt'] ?? request['created_at'],
              'email': request['email'],
              'full_name': request['fullName'],
              'contact_number': request['contactNumber'],
            };
          }).toList();
          _filteredRequests = List.from(_verificationRequests);
        } else {
          _verificationRequests = [];
          _filteredRequests = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _verificationRequests = [];
        _filteredRequests = [];
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> requests,
    String statusFilter,
    String searchQuery,
  ) {
    List<Map<String, dynamic>> filtered = List.from(requests);

    if (statusFilter != 'all') {
      filtered = filtered.where((request) =>
        (request['status']?.toString().toLowerCase() ?? 'pending') == statusFilter.toLowerCase()
      ).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((request) {
        final fullName = (request['full_name']?.toString() ?? '').toLowerCase();
        final email = (request['email']?.toString() ?? '').toLowerCase();
        return fullName.contains(query) || email.contains(query);
      }).toList();
    }

    return filtered;
  }

  void _updateFilters() {
    setState(() {
      _filteredRequests = _applyFilters(_verificationRequests, _selectedFilter, _searchQuery);
    });
  }

  void _filterRequests(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _updateFilters();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadVerificationRequests();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: widget.isDarkMode ? Colors.grey.shade900 : Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? Colors.grey.shade800 : Colors.red,
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
                        const Expanded(
                          child: Text(
                            'Authentication Requests',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _refreshData,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                    Text(
                      'Review resident verification requests',
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.isDarkMode ? Colors.grey.shade400 : Colors.red[100],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Filter Controls ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Filter Requests',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: widget.isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _showFilterMenu = !_showFilterMenu),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: widget.isDarkMode ? Colors.grey.shade700 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.menu,
                                color: widget.isDarkMode ? Colors.blue.shade300 : Colors.blue,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: _showFilterMenu
                            ? _buildExpandedFilterControls()
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Filter Tabs ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    _buildFilterTab('all', 'All'),
                    const SizedBox(width: 8),
                    _buildFilterTab('pending', 'Pending'),
                    const SizedBox(width: 8),
                    _buildFilterTab('approved', 'Approved'),
                    const SizedBox(width: 8),
                    _buildFilterTab('rejected', 'Rejected'),
                  ],
                ),
              ),
            ),

            // ── Requests List ─────────────────────────────────────────
            SliverFillRemaining(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredRequests.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_user,
                                size: 80,
                                color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty || _selectedFilter != 'all'
                                    ? "No requests match your filters"
                                    : "No $_selectedFilter requests",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
                                ),
                              ),
                              if (_searchQuery.isNotEmpty || _selectedFilter != 'all')
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedFilter = 'all';
                                      _searchQuery = '';
                                      _searchController.clear();
                                    });
                                    _updateFilters();
                                  },
                                  child: const Text('Clear Filters'),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredRequests.length,
                          itemBuilder: (context, index) =>
                              _buildRequestCard(_filteredRequests[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedFilterControls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey.shade700 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            style: TextStyle(
              fontSize: 13,
              color: widget.isDarkMode ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              labelText: 'Search by name or email',
              labelStyle: TextStyle(
                fontSize: 13,
                color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: const OutlineInputBorder(),
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black,
              ),
              filled: widget.isDarkMode,
              fillColor: widget.isDarkMode ? Colors.grey.shade800 : null,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: widget.isDarkMode ? Colors.blue.shade300 : Colors.blue,
                ),
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _updateFilters();
            },
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Text(
                'Showing ${_filteredRequests.length} of ${_verificationRequests.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              if (_selectedFilter != 'all' || _searchQuery.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedFilter = 'all';
                      _searchQuery = '';
                      _searchController.clear();
                    });
                    _updateFilters();
                  },
                  icon: Icon(
                    Icons.clear_all,
                    size: 18,
                    color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black,
                  ),
                  label: Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    final Color color = _getFilterColor(filter);

    return Expanded(
      child: GestureDetector(
        onTap: () => _filterRequests(filter),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.red.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(_getStatusIcon(status), color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request['full_name'] ?? 'Unknown',
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
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Card Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(
                  title: 'Resident Information',
                  children: [
                    _buildInfoRow('Full Name', request['full_name'] ?? 'N/A'),
                    _buildInfoRow('Contact', request['contact_number'] ?? 'N/A'),
                    _buildInfoRow('Address', request['residential_address'] ?? 'N/A'),
                    _buildInfoRow('Type', request['verification_type'] ?? 'N/A'),
                  ],
                ),

                const SizedBox(height: 16),

                _buildInfoSection(
                  title: 'Verification Photos',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildPhotoCard(
                            title: 'Profile Photo',
                            imageUrl: request['user_photo_base64'],
                            onTap: () => _showPhotoViewer('Profile Photo', request['user_photo_base64']),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPhotoCard(
                            title: 'Valid ID',
                            imageUrl: request['valid_id_base64'],
                            onTap: () => _showPhotoViewer('Valid ID', request['valid_id_base64']),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Text(
                  'Submitted: ${_formatDate(request['created_at'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey[500],
                  ),
                ),

                if (status == 'pending') ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: request['id'] != null
                              ? () => _updateVerificationStatus(request['id'], 'rejected')
                              : null,
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isDarkMode ? Colors.red.shade700 : Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: request['id'] != null
                              ? () => _updateVerificationStatus(request['id'], 'approved')
                              : null,
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isDarkMode ? Colors.green.shade700 : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard({
    required String title,
    String? imageUrl,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey[300]!,
        ),
      ),
      child: Stack(
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildValidImage(imageUrl),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person,
                    size: 32,
                    color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onTap,
                child: Container(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: widget.isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'all':      return Colors.grey;
      case 'pending':  return Colors.orange;
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default:         return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':  return Colors.orange;
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default:         return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':  return Icons.pending;
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      default:         return Icons.help;
    }
  }

  Future<void> _updateVerificationStatus(
    int requestId,
    String status, {
    double? discountRate,
  }) async {
    try {
      final response = await DataService.updateVerificationStatus(
        requestId.toString(),
        status,
        discountRate: discountRate?.toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['success'] == true
                ? 'Verification request $status successfully'
                : 'Error: ${response['error'] ?? 'Failed to update request'}'),
            backgroundColor: response['success'] == true ? Colors.green : Colors.red,
          ),
        );
      }

      _loadVerificationRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        return 'Unknown';
      }
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showPhotoViewer(String title, String? base64Image) {
    if (base64Image == null || base64Image.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No photo available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewerScreen(
          title: title,
          base64Image: base64Image,
        ),
      ),
    );
  }

  Widget _buildValidImage(String imageUrl) {
    try {
      String base64String = imageUrl.startsWith('data:')
          ? imageUrl.split(',')[1]
          : imageUrl;
      if (base64String.isEmpty) return _buildImagePlaceholder();

      String normalizedBase64 = base64String
          .replaceAll(RegExp(r'\s'), '')
          .replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');

      int paddingLength = (4 - (normalizedBase64.length % 4)) % 4;
      if (paddingLength > 0) normalizedBase64 += '=' * paddingLength;

      return Image.memory(
        base64.decode(normalizedBase64),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
      );
    } catch (e) {
      return _buildImagePlaceholder();
    }
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 32, color: Colors.grey[600]),
          const SizedBox(height: 4),
          Text(
            'Invalid Image',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
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

// ── Photo Viewer Screen ───────────────────────────────────────────────────────

class PhotoViewerScreen extends StatefulWidget {
  final String title;
  final String base64Image;

  const PhotoViewerScreen({
    super.key,
    required this.title,
    required this.base64Image,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  final TransformationController _transformationController = TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;

    try {
      final cleanBase64 = widget.base64Image.startsWith('data:')
          ? widget.base64Image.split(',')[1]
          : widget.base64Image;
      if (cleanBase64.isEmpty) throw Exception('Invalid base64 data');
      imageProvider = MemoryImage(base64.decode(cleanBase64));
    } catch (e) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.red),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Failed to load image', style: TextStyle(fontSize: 18)),
              SizedBox(height: 8),
              Text(
                'The image data may be corrupted',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _transformationController.value = Matrix4.identity(),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 5.0,
          boundaryMargin: const EdgeInsets.all(20),
          child: Container(
            constraints: BoxConstraints(
              minHeight: 200,
              minWidth: 200,
              maxHeight: MediaQuery.of(context).size.height - 200,
              maxWidth: MediaQuery.of(context).size.width - 40,
            ),
            child: Image(
              image: imageProvider,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.zoom_in, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Pinch to zoom • Drag to pan',
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }
}