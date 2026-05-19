import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../services/data_service.dart';
import '../services/base64_image_service.dart';

class BookingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  final bool isDarkMode;

  const BookingDetailScreen({super.key, required this.booking, this.isDarkMode = false});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  String _getSafeString(dynamic value) {
    if (value == null) return 'Not provided';
    if (value is String && value.isEmpty) return 'Not provided';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Extract receipt URL once at the beginning
    String? receiptUrl;
    if (widget.booking['receipt_base64'] != null && widget.booking['receipt_base64'].toString().isNotEmpty) {
      receiptUrl = widget.booking['receipt_base64'];
    } else if (widget.booking['receiptBase64'] != null && widget.booking['receiptBase64'].toString().isNotEmpty) {
      receiptUrl = widget.booking['receiptBase64'];
    } else if (widget.booking['receipt_image'] != null && widget.booking['receipt_image'].toString().isNotEmpty) {
      receiptUrl = widget.booking['receipt_image'];
    } else if (widget.booking['receipt_image_url'] != null && widget.booking['receipt_image_url'].toString().isNotEmpty) {
      receiptUrl = widget.booking['receipt_image_url'];
    }
    
    print('🔍 Receipt URL check:');
    print('  - receipt_base64: ${widget.booking['receipt_base64']}');
    print('  - receiptBase64: ${widget.booking['receiptBase64']}');
    print('  - receipt_image: ${widget.booking['receipt_image']}');
    print('  - receipt_image_url: ${widget.booking['receipt_image_url']}');
    print('  - Final receiptUrl: $receiptUrl');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getStatusIcon(widget.booking['status']),
                          color: _getStatusColor(widget.booking['status']),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Status: ${widget.booking['status']?.toUpperCase() ?? 'PENDING'}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(widget.booking['status']),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Booking Information
            _buildSectionCard('Booking Information', [
              _buildDetailRow('Facility', widget.booking['facility_name'] ?? widget.booking['facilityName'] ?? 'N/A'),
              _buildDetailRow('Date', widget.booking['booking_date'] ?? widget.booking['date'] ?? 'N/A'),
              _buildDetailRow('Time Slot', widget.booking['start_time'] ?? widget.booking['timeslot'] ?? widget.booking['time_slot'] ?? 'N/A'),
              _buildDetailRow('Purpose', _getSafeString(widget.booking['purpose'])),
              _buildDetailRow('Submitted Date', _formatDate(widget.booking['created_at'])),
            ]),
            
            const SizedBox(height: 16),
            
            // User Information
            _buildSectionCard('User Information', [
              _buildDetailRow('Name', widget.booking['full_name']?.isNotEmpty == true ? widget.booking['full_name'] : widget.booking['user_email'] ?? 'N/A'),
              _buildDetailRow('Email', widget.booking['user_email'] ?? 'N/A'),
              _buildDetailRow('Contact', _getSafeString(widget.booking['contact_number'])),
              _buildDetailRow('Address', widget.booking['contact_address'] ?? widget.booking['address'] ?? _getSafeString(widget.booking['address'])),
            ]),
            
            const SizedBox(height: 16),
            
            // Receipt Image
            (receiptUrl != null && receiptUrl.toString().isNotEmpty)
                ? _buildSectionCard('Payment Receipt', [
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildBase64Image(receiptUrl),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to view full size',
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.blue.shade400 : Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ])
                : _buildSectionCard('Payment Receipt', [
                    Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 48, color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              'No receipt uploaded',
                              style: TextStyle(
                                color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
            
            // Status Display
            if (widget.booking['status'] == 'pending') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.pending),
                  label: const Text('Pending Approval'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else if (widget.booking['status'] == 'approved') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Already Approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else if (widget.booking['status'] == 'rejected') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Already Rejected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    final displayValue = value?.toString() ?? 'N/A';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.pending;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.yellow;
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    try {
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
        print('🔍 DEBUG: BookingDetail - Original created_at: $dateValue');
        print('🔍 DEBUG: BookingDetail - Parsed DateTime (UTC): $date');
      } else if (dateValue is int) {
        date = DateTime.fromMillisecondsSinceEpoch(dateValue);
      } else {
        // handle timestamp objects with toDate() method
        try {
          date = (dateValue as dynamic).toDate();
        } catch (_) {
          return dateValue.toString();
        }
      }
      
      // Convert UTC to Philippines timezone (UTC+8)
      final philippinesTime = date.add(const Duration(hours: 8));
      print('🔍 DEBUG: BookingDetail - Philippines DateTime: $philippinesTime');
      final formatted = DateFormat.yMMMMd().add_jm().format(philippinesTime);
      print('🔍 DEBUG: BookingDetail - Formatted date: $formatted');
      return formatted;
    } catch (e) {
      print('🔍 DEBUG: BookingDetail - Error formatting date: $e');
      return dateValue.toString();
    }
  }

  Widget _buildBase64Image(String base64String) {
    print('🔍 DEBUG: _buildBase64Image called with: ${base64String.substring(0, base64String.length > 100 ? 100 : base64String.length)}...');
    
    // Extract pure base64 string from data URL format
    final String? pureBase64 = Base64ImageService.extractBase64(base64String);
    if (pureBase64 == null) {
      print('❌ DEBUG: Failed to extract base64 from: ${base64String.substring(0, base64String.length > 50 ? 50 : base64String.length)}...');
      return const Center(
        child: Text('Invalid image format'),
      );
    }
    
    print('✅ DEBUG: Successfully extracted base64: ${pureBase64.length} characters');
    
    return GestureDetector(
      onTap: () {
        // Show fullscreen viewer
        Uint8List bytes;
        try {
          bytes = base64Decode(pureBase64);
          print('✅ DEBUG: Successfully decoded base64 to ${bytes.length} bytes');
        } catch (e) {
          print('❌ DEBUG: Failed to decode base64: $e');
          return;
        }
        
        Navigator.push(context, MaterialPageRoute(builder: (_) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.black),
            backgroundColor: Colors.black,
            body: Center(
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          );
        }));
      },
      child: Image.memory(
        base64Decode(pureBase64),
        width: double.infinity,
        height: 200,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Text('Unable to load receipt image'),
          );
        },
      ),
    );
  }
}
