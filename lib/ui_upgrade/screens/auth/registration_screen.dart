import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../design_system/responsive/responsive_layout.dart';

/// User Registration Screen
///
/// Implements the user registration functionality with responsive layouts
/// for desktop, mobile, and tablet platforms.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegistration() {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    // Validate form
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Check terms acceptance
    if (!_acceptTerms) {
      setState(() {
        _errorMessage =
            'You must accept the Terms of Service and Privacy Policy.';
        _isLoading = false;
      });
      return;
    }

    // Simulate registration process
    Future.delayed(const Duration(seconds: 2), () {
      if (_emailController.text.contains('@elmos.com')) {
        // Email already exists error
        setState(() {
          _errorMessage =
              'This email is already registered. Please use a different email or login.';
          _isLoading = false;
        });
      } else {
        // Successful registration
        Navigator.pushReplacementNamed(
          context,
          '/dashboard',
        );
      }
    });
  }

  void _handleBackToLogin() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Create Account', style: appTheme.typography.headingSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBackToLogin,
        ),
      ),
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(appTheme),
        tablet: _buildTabletLayout(appTheme),
        desktop: _buildDesktopLayout(appTheme),
      ),
    );
  }

  Widget _buildMobileLayout(AppTheme appTheme) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            _buildLogo(appTheme),
            const SizedBox(height: 32),
            _buildRegistrationForm(appTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout(AppTheme appTheme) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                _buildLogo(appTheme),
                const SizedBox(height: 40),
                _buildRegistrationForm(appTheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(AppTheme appTheme) {
    return Row(
      children: [
        // Left side with brand imagery (1/2 of screen)
        Expanded(
          child: Container(
            color: appTheme.colors.primaryColor,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Company logo - white version for dark background
                Image.asset(
                  'assets/images/elmos_logo_white.png',
                  width: 240,
                  height: 80,
                  // If asset is not available, use a placeholder
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 240,
                      height: 80,
                      color: appTheme.colors.primaryLightColor,
                      child: Center(
                        child: Text(
                          'ELMOS FURNITURE',
                          style: appTheme.typography.headingLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Text(
                  'Join Our Platform',
                  style: appTheme.typography.headingMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 400,
                  child: Text(
                    'Create an account to access our furniture manufacturing management system',
                    textAlign: TextAlign.center,
                    style: appTheme.typography.bodyLarge.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right side with registration form (1/2 of screen)
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create an Account',
                      style: appTheme.typography.headingLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fill in your details to get started',
                      style: appTheme.typography.bodyLarge.copyWith(
                        color: appTheme.colors.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildRegistrationForm(appTheme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo(AppTheme appTheme) {
    return Center(
      child: Image.asset(
        'assets/images/elmos_logo.png',
        width: 180,
        height: 60,
        // If asset is not available, use a placeholder
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 180,
            height: 60,
            color: appTheme.colors.surfaceColor,
            child: Center(
              child: Text(
                'ELMOS FURNITURE',
                style: appTheme.typography.headingMedium.copyWith(
                  color: appTheme.colors.primaryColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRegistrationForm(AppTheme appTheme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error message (if any)
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: appTheme.colors.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: appTheme.colors.errorColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: appTheme.colors.errorColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: appTheme.typography.bodyMedium.copyWith(
                        color: appTheme.colors.errorColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Name fields (in a row for larger screens)
          ResponsiveLayout(
            mobile: Column(
              children: [
                _buildFirstNameField(),
                const SizedBox(height: 16),
                _buildLastNameField(),
              ],
            ),
            tablet: Row(
              children: [
                Expanded(child: _buildFirstNameField()),
                const SizedBox(width: 16),
                Expanded(child: _buildLastNameField()),
              ],
            ),
            desktop: Row(
              children: [
                Expanded(child: _buildFirstNameField()),
                const SizedBox(width: 16),
                Expanded(child: _buildLastNameField()),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Email field
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email address',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Create a password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              if (!RegExp(r'[A-Z]').hasMatch(value)) {
                return 'Password must contain at least one uppercase letter';
              }
              if (!RegExp(r'[0-9]').hasMatch(value)) {
                return 'Password must contain at least one number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              hintText: 'Confirm your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Terms and Conditions checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acceptTerms,
                onChanged: (value) {
                  setState(() {
                    _acceptTerms = value ?? false;
                  });
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text.rich(
                    TextSpan(
                      text: 'I agree to the ',
                      style: appTheme.typography.bodySmall,
                      children: [
                        TextSpan(
                          text: 'Terms of Service',
                          style: appTheme.typography.bodySmall.copyWith(
                            color: appTheme.colors.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                          // Add GestureDetector for Terms of Service
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: appTheme.typography.bodySmall.copyWith(
                            color: appTheme.colors.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                          // Add GestureDetector for Privacy Policy
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Create Account button
          ElevatedButton(
            onPressed: _isLoading ? null : _handleRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.colors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Create Account',
                    style: appTheme.typography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          // Already have an account link
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account?',
                  style: appTheme.typography.bodyMedium.copyWith(
                    color: appTheme.colors.textSecondaryColor,
                  ),
                ),
                TextButton(
                  onPressed: _handleBackToLogin,
                  child: Text(
                    'Sign In',
                    style: appTheme.typography.bodyMedium.copyWith(
                      color: appTheme.colors.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstNameField() {
    return TextFormField(
      controller: _firstNameController,
      decoration: InputDecoration(
        labelText: 'First Name',
        hintText: 'Enter your first name',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your first name';
        }
        return null;
      },
    );
  }

  Widget _buildLastNameField() {
    return TextFormField(
      controller: _lastNameController,
      decoration: InputDecoration(
        labelText: 'Last Name',
        hintText: 'Enter your last name',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your last name';
        }
        return null;
      },
    );
  }
}
