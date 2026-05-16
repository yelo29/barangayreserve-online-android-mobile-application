import 'package:flutter/material.dart';
import '../services/auth_api_service.dart';
import '../services/api_service.dart';

class OfficialAccountSettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  const OfficialAccountSettingsScreen({super.key, this.isDarkMode = false});

  @override
  State<OfficialAccountSettingsScreen> createState() => _OfficialAccountSettingsScreenState();
}

class _OfficialAccountSettingsScreenState extends State<OfficialAccountSettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _currentUserEmail;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use AuthApiService for current user data (already logged in)
      final userData = await AuthApiService.instance.getCurrentUser();
      if (userData != null) {
        _currentUserEmail = userData['email'];
        
        setState(() {
          _nameController.text = userData['full_name'] ?? '';
          _contactController.text = userData['contact_number'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      if (_currentUserEmail == null) {
        throw Exception('No user logged in');
      }

      // Call server API to update profile
      final profileData = {
        'email': _currentUserEmail,
        'full_name': _nameController.text.trim(),
        'contact_number': _contactController.text.trim(),
      };

      print('🔍 Updating profile on server: $profileData');
      
      final result = await ApiService.updateProfile(profileData);
      
      if (result['success'] == true) {
        // Update local AuthApiService data after successful server update
        final authApiService = AuthApiService.instance;
        await authApiService.updateCurrentUser({
          'full_name': _nameController.text.trim(),
          'contact_number': _contactController.text.trim(),
        });
        
        // Refresh user data after successful update
        await _loadUserData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.grey.shade900 : Colors.white,
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Section
            Card(
              color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Gmail Display
                    Row(
                      children: [
                        Icon(Icons.email, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gmail Address',
                                style: TextStyle(
                                  color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _currentUserEmail ?? 'Loading...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Name Update Section
                    Row(
                      children: [
                        Icon(Icons.person, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Full Name',
                                style: TextStyle(
                                  color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _nameController,
                                style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87),
                                decoration: InputDecoration(
                                  hintText: 'Enter your full name',
                                  hintStyle: TextStyle(color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Contact Number Section
                    Row(
                      children: [
                        Icon(Icons.phone, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contact Number',
                                style: TextStyle(
                                  color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _contactController,
                                style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87),
                                decoration: InputDecoration(
                                  hintText: 'Enter your contact number',
                                  hintStyle: TextStyle(color: widget.isDarkMode ? Colors.grey.shade500 : Colors.grey),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Update Profile Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUpdating ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isDarkMode ? Colors.red.shade700 : Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isUpdating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Update Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Customer Service Section
            Card(
              color: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Service Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    ListTile(
                      leading: Icon(Icons.phone, color: widget.isDarkMode ? Colors.red.shade400 : Colors.red),
                      title: Text('Your Contact Number', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87)),
                      subtitle: Text(_contactController.text.isEmpty ? 'Not set' : _contactController.text, style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600)),
                      trailing: Icon(Icons.edit, size: 16, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                      onTap: () {
                        // Focus on contact number field
                        FocusScope.of(context).requestFocus(FocusNode());
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Edit Contact Number'),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _contactController,
                                  autofocus: true,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Contact Number',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const Divider(),
                    
                    ListTile(
                      leading: const Icon(Icons.info, color: Colors.red),
                      title: const Text('Note'),
                      subtitle: Text('Residents will see your contact number for customer service inquiries', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Additional Options
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip, color: Colors.orange),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // TODO: Navigate to privacy policy
                      // For now, show basic privacy information
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
                          title: Text('Privacy Policy', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87)),
                          content: SingleChildScrollView(
                            child: Text(
                              'As barangay officials, you are entrusted with managing public services and protecting resident information under Philippine laws. This policy outlines your responsibilities and enhanced privacy standards required when accessing the Facility Reservation System.\n\n'
            '1. Information You Access & Manage\n'
            '- Employment data: position, contact, work schedule\n'
            '- Resident personal information: names, addresses, contacts\n'
            '- Verification documents: IDs, residence proofs, photos\n'
            '- Booking records: reservations, payments, usage history\n'
            '- Decision records: approvals, rejections, processing times\n'
            '- System activity: login history, actions taken, performance metrics\n'
            '\n2. Official Responsibilities under Philippine Laws\n'
            '- Process resident requests efficiently and fairly under Local Government Code\n'
            '- Safeguard all resident information with highest security under Data Privacy Act of 2012\n'
            '- Maintain accurate records of all official actions\n'
            '- Follow all privacy laws and barangay ordinances\n'
            '- Never share resident information inappropriately\n'
            '- Use system access only for official purposes\n'
            '- Comply with Anti-Red Tape Act for efficient service\n'
            '\n3. Enhanced Security Requirements\n'
            '- Role-based access: only data needed for your position\n'
            '- Multi-factor authentication for secure login\n'
            '- Complete logging of every action taken\n'
            '- Regular audits of access and activity\n'
            '- Immediate reporting of security incidents\n'
            '- Secure storage of all sensitive resident data\n'
            '\n4. Data Retention Periods under Philippine Laws\n'
            '- Employment records: During term + 7 years post-employment\n'
            '- Decision records: Permanent (barangay archival requirement under Local Government Code)\n'
            '- Access logs: 7 years for security auditing\n'
            '- Performance data: 5 years for evaluation purposes\n'
            '- Complaint records: 10 years or as legally required\n'
            '- Investigation data: 10 years for legal protection\n'
            '\n5. Your Rights & Obligations under Civil Service\n'
            '- Access your own employment and performance data\n'
            '- Request corrections to inaccurate administrative records\n'
            '- Appeal disciplinary actions or access decisions\n'
            '- Receive regular privacy and security training\n'
            '- Protect resident privacy above all else\n'
            '- Report security concerns immediately\n'
            '- Comply fully with Data Privacy Act of 2012\n'
            '- Follow Civil Service Commission regulations\n'
            '\n6. Accountability Measures\n'
            '- Regular performance reviews of privacy compliance\n'
            '- Public oversight of aggregated decision statistics\n'
            '- Legal consequences for privacy violations under Data Privacy Act\n'
            '- Quarterly access permission audits\n'
            '- Annual compliance certification required\n'
            '- Civil Service ethics standards apply\n'
            '\n7. Oversight & Support\n'
            '- Data Privacy Officer: dataprotection@barangay.gov\n'
            '- Security Team: security@barangay.gov\n'
            '- Legal Counsel: legal@barangay.gov\n'
            '- Hotline: (02) 8XXX-XXXX ext. 101\n'
            '- Municipal government quarterly compliance reports\n'
            '- Civil Service Commission annual audits\n'
            '- National Privacy Commission: privacy@npc.gov.ph\n'
            '- Department of Interior and Local Government oversight\n'
            '\n8. Legal Compliance Framework\n'
            '- Republic Act No. 10173: Data Privacy Act of 2012\n'
            '- Republic Act No. 6715: Civil Service Commission\n'
            '- Republic Act No. 9485: Anti-Red Tape Act\n'
            '- Republic Act No. 11032: Freedom of Information\n'
            '- Executive Order No. 2: Anti-Red Tape Act implementation\n'
            '- Local Government Code of 1991\n'
            '- Barangay Ordinance No. 2025-002: Official Data Management\n'
            '- Barangay Ordinance No. 2025-003: Digital Service Standards\n'
            '\n9. Policy Management\n'
            '- Annual policy review and updates\n'
            '- Mandatory privacy certification required\n'
            '- 30-day notice for significant changes\n'
            '- Official acknowledgment of policy terms\n'
            '- Continuous privacy training and improvement\n'
            '\nBy accepting an official position, you commit to protecting resident privacy under Republic Act No. 10173, maintaining highest ethical standards under Civil Service laws, and serving our community with integrity and transparency as required by the Local Government Code.\n\n'
            'Thank you for your commitment to protecting our community\'s privacy while delivering excellent public service!',
                              style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Close', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help, color: Colors.purple),
                    title: const Text('Help & Support'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // TODO: Navigate to help center
                      // For now, show basic help information
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.white,
                          title: Text('Help & Support', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87)),
                          content: SingleChildScrollView(
                            child: Text(
                              'Barangay Reserve Official App - Help & Support\n\n'
            '1. Official Dashboard Navigation\n'
            '- Bottom Navigation: Home, Calendar, Authentication, Reports, Account\n'
            '- Home Tab: Facility statistics and quick actions\n'
            '- Calendar Tab: Complete booking management\n'
            '- Authentication Tab: Process resident verifications\n'
            '- Reports Tab: View analytics and statistics\n'
            '- Account Tab: Official settings and support\n'
            '\n2. Managing Resident Bookings\n'
            '- Go to Calendar tab\n'
            '- View all booking requests (pending, approved, rejected)\n'
            '- Tap any booking to view details\n'
            '- Approve or reject based on facility availability\n'
            '- Add approval notes if needed\n'
            '- System automatically notifies residents\n'
            '\n3. Creating Official Bookings\n'
            '- Calendar tab → Tap "Add Official Booking"\n'
            '- Select facility, date, and time\n'
            '- Official bookings appear in gray (locked to residents)\n'
            '- Use for barangay events, maintenance, or official functions\n'
            '- Can override resident bookings when necessary\n'
            '\n4. Processing Verification Requests\n'
            '- Authentication tab shows pending requests\n'
            '- Tap request to view resident details\n'
            '- Tap ID photos to zoom and inspect\n'
            '- Check all documents carefully\n'
            '- Approve with correct discount (10% resident, 5% non-resident)\n'
            '- Reject with clear reason\n'
            '- System updates resident profile automatically\n'
            '\n5. Calendar Management Features\n'
            '- View all bookings by date\n'
            '- Filter by status (All, Pending, Approved, Rejected)\n'
            '- Block dates for facility maintenance\n'
            '- Export booking data for reports\n'
            '- View facility usage statistics\n'
            '\n6. Official App Functions\n'
            '- Home: Quick stats and recent activity\n'
            '- Calendar: Complete booking control\n'
            '- Authentication: Resident verification processing\n'
            '- Reports: Analytics and usage data\n'
            '- Account: Settings and official information\n'
            '\n7. App Technical Issues\n'
            '- Login problems: Use official email reset\n'
            '- Data not syncing: Check internet connection\n'
            '- Photos not loading: Update app version\n'
            '- Cannot approve bookings: Check permissions\n'
            '- System slow: Clear app cache\n'
            '- Notifications missing: Enable in phone settings\n'
            '\n8. Security Best Practices\n'
            '- Use official device only\n'
            '- Enable two-factor authentication\n'
            '- Log out after each use\n'
            '- Never share login credentials\n'
            '- Report suspicious activity immediately\n'
            '- Follow data retention schedules\n'
            '- Complete mandatory privacy training\n'
            '- Maintain audit trail compliance\n'
            '\n9. Support Contacts\n'
            '- App technical issues: official-app@barangay.gov\n'
            '- System problems: support@barangay.gov\n'
            '- Policy questions: admin@barangay.gov\n'
            '- Security concerns: security@barangay.gov\n'
            '- Hotline: 0965-669-2463 ext. 101\n'
            '- Office hours: Monday-Friday, 8:00 AM - 5:00 PM\n'
            '- Emergency IT: 0912-345-6791\n'
            '\n10. System Administrator Contact\n'
            '- For critical system errors, data corruption, or security breaches:\n'
            '- System Administrator: sysadmin@barangay.gov\n'
            '- Emergency Hotline: 0912-345-6788 (24/7)\n'
            '- Available for: System crashes, data loss, security incidents\n'
            '- Response time: Within 2 hours for critical issues\n'
            '- After hours: Emergency contact for urgent system failures\n'
            '- Report details: Error messages, screenshots, device info\n'
            '\n11. Official Resources\n'
            '- User manual: Available in barangay office\n'
            '- Training schedule: Monthly sessions\n'
            '- Policy updates: Posted on official bulletin\n'
            '- System maintenance: Every Sunday 10 PM - 12 AM\n'
            '- Backup schedule: Daily at 2 AM\n'
            '\n12. Legal & Compliance Support\n'
            '- Data Privacy Act questions: privacy@npc.gov.ph\n'
            '- Civil Service matters: csc.gov.ph\n'
            '- DILG guidance: dilg.gov.ph\n'
            '- Local government assistance: lga.gov.ph\n'
            '\n13. Frequently Asked Questions\n'
            '- Q: How do I override resident bookings?\n'
            '  A: Use official booking feature with valid reason\n'
            '- Q: What if I make a mistake in approval?\n'
            '  A: Contact resident immediately and correct the error\n'
            '- Q: How long should I keep records?\n'
            '  A: Follow retention schedule in privacy policy\n'
            '- Q: Can I access system from home?\n'
            '  A: Yes, with official authorization and security protocols\n'
            '- Q: What are my audit obligations?\n'
            '  A: Quarterly access audits and annual compliance reports\n'
            '- Q: When should I contact system administrator?\n'
            '  A: For critical system errors, security breaches, data corruption\n'
            '\nThank you for your dedication to public service and community development!',
                              style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Close', style: TextStyle(color: widget.isDarkMode ? Colors.grey.shade300 : Colors.black87)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
