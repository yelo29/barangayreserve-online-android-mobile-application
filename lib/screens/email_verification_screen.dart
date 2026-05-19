import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import 'resident_login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  
  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6, 
    (index) => TextEditingController()
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  int _resendTimer = 0;
  
  @override
  void initState() {
    super.initState();
    _saveOTPState(); // Save state when entering OTP screen
    _loadPersistentOTPState();
    // Auto-focus first OTP field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }
  
  Future<void> _loadPersistentOTPState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingEmail = prefs.getString('pending_email_verification');
      final otpStartTime = prefs.getString('otp_start_time');
      
      if (pendingEmail == widget.email && otpStartTime != null) {
        final startTime = DateTime.parse(otpStartTime!);
        final elapsed = DateTime.now().difference(startTime);
        
        // If more than 10 minutes have passed, clear the state
        if (elapsed.inMinutes > 10) {
          await _clearOTPState();
        } else {
          // Show recovery message
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showRecoveryDialog();
            });
          }
        }
      }
    } catch (e) {
      print('❌ Error loading persistent OTP state: $e');
    }
  }
  
  Future<void> _saveOTPState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_email_verification', widget.email);
      await prefs.setString('otp_start_time', DateTime.now().toIso8601String());
    } catch (e) {
      print('❌ Error saving OTP state: $e');
    }
  }
  
  Future<void> _clearOTPState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_email_verification');
      await prefs.remove('otp_start_time');
    } catch (e) {
      print('❌ Error clearing OTP state: $e');
    }
  }
  
  void _showRecoveryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verification In Progress'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You have an ongoing email verification.'),
            const SizedBox(height: 8),
            const Text('Recovery Options:'),
            const SizedBox(height: 4),
            const Text('1. Check your email for the OTP code'),
            const Text('2. Request a new code if needed'),
            const Text('3. Complete verification to access your account'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
  
  void _onOTPChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      // Move to next field
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Move to previous field on backspace
      _focusNodes[index - 1].requestFocus();
    }
  }
  
  String _getOTPCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }
  
  Future<void> _verifyOTP() async {
    final otpCode = _getOTPCode();
    
    if (otpCode.length != 6) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final result = await ApiService.verifyEmailOTP(widget.email, otpCode);
      
      if (result['success']) {
        await _clearOTPState(); // Clear persistent state on success
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
          
          // Redirect to login screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const ResidentLoginScreen()
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = result['message'] ?? 'Verification failed';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
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
  
  Future<void> _resendOTP() async {
    if (_resendTimer > 0) return;
    
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });
    
    try {
      final result = await ApiService.resendOTP(widget.email);
      
      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
          
          // Clear OTP fields and focus first
          for (var controller in _otpControllers) {
            controller.clear();
          }
          _focusNodes[0].requestFocus();
          
          // Start resend timer
          _startResendTimer();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = result['message'] ?? 'Failed to resend code';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to resend code. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }
  
  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
    });
    
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
        return true;
      }
      return false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    
    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog before allowing back navigation
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave Verification?'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your email is not verified yet.'),
                const SizedBox(height: 8),
                const Text('If you leave this screen:'),
                const SizedBox(height: 4),
                const Text('• You will need to request a new OTP code'),
                const Text('• You cannot log in without email verification'),
                const SizedBox(height: 8),
                const Text('Are you sure you want to go back?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Leave Anyway'),
              ),
            ],
          ),
        );
        
        return shouldPop ?? false;
      },
      child: Scaffold(
        backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.blue[50],
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                
                // Header
                Icon(
                  Icons.email_outlined,
                  size: 80,
                  color: isDarkMode ? Colors.blue.shade300 : Colors.blue[600],
                ),
                
                const SizedBox(height: 24),
                
                Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.blue[900],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'We sent a 6-digit verification code to:\n${widget.email}',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 50,
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _focusNodes[index].hasFocus 
                              ? (isDarkMode ? Colors.blue.shade400 : Colors.blue[600]!) 
                              : (isDarkMode ? Colors.grey.shade600 : Colors.grey[300]!),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                      ),
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(1),
                        ],
                        onChanged: (value) => _onOTPChanged(index, value),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                        ),
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: 32),
                
                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.red.shade900 : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDarkMode ? Colors.red.shade700 : Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: isDarkMode ? Colors.red.shade300 : Colors.red[600], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: isDarkMode ? Colors.red.shade300 : Colors.red[600]),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Verify Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? Colors.blue.shade700 : Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                            Text('Verifying...'),
                          ],
                        )
                      : const Text(
                          'Verify Email',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                
                const SizedBox(height: 16),
                
                // Resend Code
                TextButton(
                  onPressed: (_isResending || _resendTimer > 0) ? null : _resendOTP,
                  child: _isResending
                      ? const Text('Sending...')
                      : _resendTimer > 0
                          ? Text('Resend code in $_resendTimer seconds')
                          : const Text('Resend code'),
                ),
                
                const SizedBox(height: 24),
                
                // Back to Login
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ResidentLoginScreen()
                      ),
                    );
                  },
                  child: Text(
                    'Back to Login',
                    style: TextStyle(color: isDarkMode ? Colors.blue.shade300 : Colors.blue[600]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
