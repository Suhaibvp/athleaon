import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'complete_profile_screen.dart';
import 'student/student_dashboard.dart';
import 'instructor/instructor_dashboard.dart';
import 'email_verification_screen.dart';
class AuthScreen extends StatefulWidget {
  final String role; // Student, Instructor, Guest, or DTM Owner
  
  const AuthScreen({
    super.key,
    required this.role,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Auth Service
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  
  // Login form controllers
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  
  // Signup form controllers
  final TextEditingController _signupFirstNameController = TextEditingController();
  final TextEditingController _signupLastNameController = TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupDobController = TextEditingController();
  final TextEditingController _signupPasswordController = TextEditingController();
  final TextEditingController _signupConfirmPasswordController = TextEditingController();
  
  String? _selectedState;
  String? _selectedLanguage;
  
  final List<String> _states = ['California', 'Texas', 'New York', 'Florida', 'Illinois'];
  final List<String> _languages = ['English', 'Spanish', 'French', 'German', 'Hindi'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupFirstNameController.dispose();
    _signupLastNameController.dispose();
    _signupEmailController.dispose();
    _signupDobController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            
            // Logo
            const Text(
              'ATHLEON',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD32F2F),
                letterSpacing: 6,
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFD32F2F),
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.5),
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Log in'),
                  Tab(text: 'Sign up'),
                ],
              ),
            ),
            
            // Tab Bar View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginForm(),
                  _buildSignupForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          
          // Email field
          _buildTextField(
            controller: _loginEmailController,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          
          const SizedBox(height: 20),
          
          // Password field
          _buildTextField(
            controller: _loginPasswordController,
            label: 'Password',
            isPassword: true,
          ),
          
          const SizedBox(height: 12),
          
          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _handleForgotPassword,
              child: const Text(
                'Forgot your password?',
                style: TextStyle(
                  color: Color(0xFFD32F2F),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Login button
          ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Log in',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          
          const SizedBox(height: 20),
          
          // Create new account
          Center(
            child: TextButton(
              onPressed: () {
                _tabController.animateTo(1); // Switch to signup tab
              },
              child: Text(
                'Create new account',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Or continue with
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Or continue with',
                  style: TextStyle(
                    color: const Color(0xFFD32F2F),
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Social login buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialButton(Icons.g_mobiledata, 'Google'),
              const SizedBox(width: 16),
              _buildSocialButton(Icons.facebook, 'Facebook'),
              const SizedBox(width: 16),
              _buildSocialButton(Icons.apple, 'Apple'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignupForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          
          // First and Last Name row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _signupFirstNameController,
                  label: 'First Name',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _signupLastNameController,
                  label: 'Last Name',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Email and DOB row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _signupEmailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _signupDobController,
                  label: 'Date of Birth',
                  keyboardType: TextInputType.datetime,
                  hintText: 'MM/DD/YYYY',
                  onTap: () => _selectDate(context),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // State and Language row
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'State',
                  value: _selectedState,
                  items: _states,
                  onChanged: (value) {
                    setState(() {
                      _selectedState = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  label: 'Languages',
                  value: _selectedLanguage,
                  items: _languages,
                  onChanged: (value) {
                    setState(() {
                      _selectedLanguage = value;
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Password and Confirm Password row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _signupPasswordController,
                  label: 'Password',
                  isPassword: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _signupConfirmPasswordController,
                  label: 'Confirm Password',
                  isPassword: true,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // Sign up button
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSignup,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Sign up',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          
          const SizedBox(height: 20),
          
          // Already have an account
          Center(
            child: TextButton(
              onPressed: () {
                _tabController.animateTo(0); // Switch to login tab
              },
              child: Text(
                'Already have an account?',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Or continue with
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Or continue with',
                  style: TextStyle(
                    color: const Color(0xFFD32F2F),
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Social login buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialButton(Icons.g_mobiledata, 'Google'),
              const SizedBox(width: 16),
              _buildSocialButton(Icons.facebook, 'Facebook'),
              const SizedBox(width: 16),
              _buildSocialButton(Icons.apple, 'Apple'),
            ],
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? hintText,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          onTap: onTap,
          readOnly: onTap != null,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFD32F2F),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white.withOpacity(0.5),
          ),
          dropdownColor: const Color(0xFF2A2A2A),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String platform) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: IconButton(
        icon: Icon(icon, size: 28),
        color: Colors.white.withOpacity(0.7),
        onPressed: _isLoading
            ? null
            : () {
                if (platform == 'Google') {
                  _handleGoogleSignIn();
                } else {
                  _showMessage('$platform login coming soon');
                }
              },
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD32F2F),
              surface: Color(0xFF2A2A2A),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _signupDobController.text = 
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
  }

  // Firebase Authentication Methods

void _handleLogin() async {
  final email = _loginEmailController.text.trim();
  final password = _loginPasswordController.text.trim();
  
  if (email.isEmpty || password.isEmpty) {
    _showMessage('Please fill in all fields');
    return;
  }
  
  setState(() => _isLoading = true);
  
  try {
    UserCredential? userCredential = await _authService.signInWithEmail(
      email: email,
      password: password,
      requestedRole: widget.role,
    );
    
    if (userCredential != null && mounted) {
      // Check if email is verified
      if (!userCredential.user!.emailVerified) {
        // Email not verified, show verification screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(role: widget.role),
          ),
        );
        return;
      }
      
      _showMessage('Login successful!');
      _navigateToRoleHome();
    }
  } catch (e) {
    if (mounted) {
      _showMessage(e.toString());
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}


// Update _handleSignup method with role validation:
void _handleSignup() async {
  final firstName = _signupFirstNameController.text.trim();
  final lastName = _signupLastNameController.text.trim();
  final email = _signupEmailController.text.trim();
  final dob = _signupDobController.text.trim();
  final password = _signupPasswordController.text.trim();
  final confirmPassword = _signupConfirmPasswordController.text.trim();
  
  if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || 
      dob.isEmpty || password.isEmpty || confirmPassword.isEmpty ||
      _selectedState == null || _selectedLanguage == null) {
    _showMessage('Please fill in all fields');
    return;
  }
  
  if (password != confirmPassword) {
    _showMessage('Passwords do not match');
    return;
  }
  
  if (password.length < 6) {
    _showMessage('Password must be at least 6 characters');
    return;
  }
  
  setState(() => _isLoading = true);
  
  try {
    // Create account (verification email sent automatically)
    UserCredential? userCredential = await _authService.signUpWithEmail(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      role: widget.role,
      dateOfBirth: dob,
      state: _selectedState!,
      language: _selectedLanguage!,
    );
    
    if (userCredential != null && mounted) {
      // Show success message
      _showMessage('Verification email sent! Please check your inbox.');
      
      // Navigate to verification screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EmailVerificationScreen(role: widget.role),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      _showMessage(e.toString());
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}




void _handleGoogleSignIn() async {
  setState(() => _isLoading = true);
  
  try {
    UserCredential? userCredential = await _authService.signInWithGoogle(
      role: widget.role, // Will be validated
    );
    
    if (userCredential != null && mounted) {
      // Check if profile is complete
      bool isComplete = await _authService.isProfileComplete(
        userCredential.user!.uid,
      );
      
      if (isComplete) {
        _showMessage('Google sign in successful!');
        _navigateToRoleHome();
      } else {
        _showMessage('Please complete your profile');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CompleteProfileScreen(role: widget.role),
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      // Show error dialog for role mismatch
      if (e.toString().contains('already registered as')) {
        _showRoleMismatchDialog(e.toString());
      } else {
        _showMessage(e.toString());
      }
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}


  void _handleForgotPassword() async {
    final email = _loginEmailController.text.trim();
    
    if (email.isEmpty) {
      _showMessage('Please enter your email address');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await _authService.resetPassword(email);
      _showMessage('Password reset email sent!');
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

// Update _navigateToRoleHome() method:
void _navigateToRoleHome() {
  switch (widget.role) {
    case 'Student':
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const StudentDashboard(),
        ),
      );
      break;
    case 'Instructor':
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const InstructorDashboard(),
        ),
      );
      break;
    case 'Guest':
      _showMessage('Guest Mode coming soon');
      break;
    default:
      break;
  }
}

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2A2A2A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  void _showRoleMismatchDialog(String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: const Text(
        'Account Role Mismatch',
        style: TextStyle(color: Colors.white),
      ),
      content: Text(
        message,
        style: TextStyle(color: Colors.white.withOpacity(0.8)),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.pop(context); // Go back to role selection
          },
          child: const Text(
            'Go Back',
            style: TextStyle(color: Color(0xFFD32F2F)),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
          },
          child: const Text(
            'Try Different Email',
            style: TextStyle(color: Color(0xFFD32F2F)),
          ),
        ),
      ],
    ),
  );
}
}
