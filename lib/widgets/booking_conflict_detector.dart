import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auto_refresh_service.dart';
import '../services/api_service.dart';
import '../services/auth_api_service.dart';

/// Widget that handles real-time booking conflict detection
class BookingConflictDetector extends StatefulWidget {
  final int facilityId;
  final String date;
  final String timeslot;
  final String userEmail;
  final Widget child;
  final VoidCallback? onConflictDetected;
  final VoidCallback? onConflictResolved;

  const BookingConflictDetector({
    Key? key,
    required this.facilityId,
    required this.date,
    required this.timeslot,
    required this.userEmail,
    required this.child,
    this.onConflictDetected,
    this.onConflictResolved,
  }) : super(key: key);

  @override
  State<BookingConflictDetector> createState() => _BookingConflictDetectorState();
}

class _BookingConflictDetectorState extends State<BookingConflictDetector> {
  late StreamSubscription _conflictSubscription;
  Timer? _conflictCheckTimer;
  bool _isChecking = false;
  bool _hasConflict = false;

  @override
  void initState() {
    super.initState();
    
    // Listen to conflict notifications
    _conflictSubscription = AutoRefreshService.instance.conflictStream.listen(
      _handleConflictNotification,
    );
    
    // Start periodic conflict checking
    _startConflictChecking();
  }

  @override
  void dispose() {
    _conflictSubscription.cancel();
    _conflictCheckTimer?.cancel();
    super.dispose();
  }

  void _startConflictChecking() {
    // Check for conflicts every 5 seconds
    _conflictCheckTimer = Timer.periodic(Duration(seconds: 5), (_) {
      if (mounted) {
        _checkForConflicts();
      }
    });
    
    // Also check immediately
    _checkForConflicts();
  }

  Future<void> _checkForConflicts() async {
    if (_isChecking) return;
    
    setState(() {
      _isChecking = true;
    });

    try {
      final conflictData = {
        'facility_id': widget.facilityId,
        'date': widget.date,
        'timeslot': widget.timeslot,
        'user_email': widget.userEmail,
      };

      final result = await ApiService.checkBookingConflict(conflictData);
      
      if (mounted) {
        if (result['success'] == true && result['has_conflict'] == true) {
          if (!_hasConflict) {
            // Conflict detected
            setState(() {
              _hasConflict = true;
            });
            _showConflictDialog(result['conflict_info']);
            widget.onConflictDetected?.call();
          }
        } else {
          if (_hasConflict) {
            // Conflict resolved
            setState(() {
              _hasConflict = false;
            });
            widget.onConflictResolved?.call();
          }
        }
      }
    } catch (e) {
      print('❌ Error checking conflicts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  void _handleConflictNotification(Map<String, dynamic> conflictNotification) {
    // Check if this notification applies to current widget
    if (conflictNotification['facility_id'] == widget.facilityId &&
        conflictNotification['date'] == widget.date &&
        conflictNotification['timeslot'] == widget.timeslot) {
      
      // Check if current user is not the one who booked
      if (conflictNotification['exclude_user'] != widget.userEmail) {
        if (mounted) {
          setState(() {
            _hasConflict = true;
          });
          _showConflictDialog(conflictNotification);
          widget.onConflictDetected?.call();
        }
      }
    }
  }

  void _showConflictDialog(Map<String, dynamic> conflictInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Booking Conflict'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conflictInfo['message'] ?? 'This time slot is no longer available.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              if (conflictInfo['user_email'] != null)
                Text(
                  'Booked by: ${conflictInfo['user_email']}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              if (conflictInfo['created_at'] != null)
                Text(
                  'Time: ${_formatDateTime(conflictInfo['created_at'])}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Auto-refresh the booking form
                widget.onConflictDetected?.call();
              },
              child: Text('Choose Different Time'),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isChecking)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Checking...',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
        if (_hasConflict)
          Positioned.fill(
            child: Container(
              color: Colors.red.withOpacity(0.1),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Time Slot Unavailable',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        _checkForConflicts();
                      },
                      child: Text('Check Again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
