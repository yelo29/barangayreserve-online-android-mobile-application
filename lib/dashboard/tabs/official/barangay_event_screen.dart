import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/facility_model.dart';

class BarangayEventScreen extends StatefulWidget {
  final Facility facility;
  final DateTime? selectedDate;

  const BarangayEventScreen({
    super.key,
    required this.facility,
    this.selectedDate,
  });

  @override
  State<BarangayEventScreen> createState() => _BarangayEventScreenState();
}

class _BarangayEventScreenState extends State<BarangayEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _eventDescriptionController = TextEditingController();
  
  DateTime? _selectedDate;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _eventDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      setState(() {
        _errorMessage = 'Please select an event date';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create event data
      final Map<String, dynamic> eventData = {
        'facilityId': widget.facility.id,
        'facilityName': widget.facility.name,
        'eventName': _eventNameController.text.trim(),
        'eventDescription': _eventDescriptionController.text.trim(),
        'eventDate': DateFormat.yMMMMd('en_US').format(_selectedDate!),
        'eventDateTimestamp': Timestamp.fromDate(_selectedDate!),
        'createdBy': 'Barangay Official', // This would come from current user
        'createdAt': Timestamp.now(),
        'type': 'barangay_event',
      };

      // Save to Firestore
      final String? eventId = await _firestoreService.createBarangayEvent(eventData);
      if (eventId == null) {
        throw Exception('Failed to create barangay event');
      }

      // Show success message and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barangay event created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error creating event: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
      appBar: AppBar(
        title: Text('Create Barangay Event'),
        backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Facility Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDarkMode ? Colors.grey.shade600 : Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Facility: ${widget.facility.name}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.blue.shade300 : Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This event will block the selected date from public booking',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Event Details
              Text(
                'Event Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _eventNameController,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Event Name',
                  hintText: 'Enter event name',
                  labelStyle: TextStyle(color: isDarkMode ? Colors.grey.shade400 : Colors.black87),
                  hintStyle: TextStyle(color: isDarkMode ? Colors.grey.shade500 : Colors.grey),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event, color: isDarkMode ? Colors.grey.shade400 : Colors.black87),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter event name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _eventDescriptionController,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Event Description',
                  hintText: 'Describe the event',
                  labelStyle: TextStyle(color: isDarkMode ? Colors.grey.shade400 : Colors.black87),
                  hintStyle: TextStyle(color: isDarkMode ? Colors.grey.shade500 : Colors.grey),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description, color: isDarkMode ? Colors.grey.shade400 : Colors.black87),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter event description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Date Selection
              Text(
                'Event Date',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _selectDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: isDarkMode ? Colors.blue.shade300 : Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDate != null
                              ? DateFormat.yMMMMd('en_US').format(_selectedDate!)
                              : 'Select event date',
                          style: TextStyle(
                            color: _selectedDate != null
                                ? (isDarkMode ? Colors.white : Colors.black87)
                                : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                            fontWeight: _selectedDate != null
                                ? FontWeight.normal
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Warning Message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.orange.shade900 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDarkMode ? Colors.orange.shade700 : Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: isDarkMode ? Colors.orange.shade300 : Colors.orange.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This event will block the selected date from resident booking and will appear as green on the calendar.',
                        style: TextStyle(
                          color: isDarkMode ? Colors.orange.shade300 : Colors.orange.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.red.shade900 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDarkMode ? Colors.red.shade700 : Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: isDarkMode ? Colors.red.shade300 : Colors.red.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: isDarkMode ? Colors.red.shade300 : Colors.red.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Create Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? Colors.blue.shade700 : Colors.blue,
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Creating...'),
                          ],
                        )
                      : const Text(
                          'Create Event',
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
