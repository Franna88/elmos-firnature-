import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../design_system/responsive/responsive_layout.dart';

/// Login Screen
///
/// Implements the responsive login interface for the Elmos Furniture application.
/// Provides authentication functionality across desktop, mobile, and tablet platforms.
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
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

    // Simulate login process
    Future.delayed(const Duration(seconds: 2), () {
      if (_emailController.text == 'admin@elmos.com' &&
          _passwordController.text == 'password') {
        // Successful login
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        // Failed login
        setState(() {
          _errorMessage = 'Invalid email or password. Please try again.';
          _isLoading = false;
        });
      }
    });
  }

  void _handleForgotPassword() {
    Navigator.pushNamed(context, '/password-reset');
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppTheme.of(context);

    return Scaffold(
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
            const SizedBox(height: 40),
            _buildLogo(appTheme),
            const SizedBox(height: 40),
            _buildLoginForm(appTheme),
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
                const SizedBox(height: 60),
                _buildLogo(appTheme),
                const SizedBox(height: 60),
                _buildLoginForm(appTheme),
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
                  'Premium Furniture Manufacturing',
                  style: appTheme.typography.headingMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 400,
                  child: Text(
                    'Your complete solution for furniture production management',
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

        // Right side with login form (1/2 of screen)
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back',
                      style: appTheme.typography.headingLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please sign in to continue',
                      style: appTheme.typography.bodyLarge.copyWith(
                        color: appTheme.colors.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildLoginForm(appTheme),
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
        width: 200,
        height: 70,
        // If asset is not available, use a placeholder
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 200,
            height: 70,
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

  Widget _buildLoginForm(AppTheme appTheme) {
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

          // Email field
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
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
          const SizedBox(height: 24),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
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
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Remember me and Forgot password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                  ),
                  Text(
                    'Remember me',
                    style: appTheme.typography.bodyMedium,
                  ),
                ],
              ),
              TextButton(
                onPressed: _handleForgotPassword,
                child: Text(
                  'Forgot Password?',
                  style: appTheme.typography.bodyMedium.copyWith(
                    color: appTheme.colors.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Login button
          ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
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
                    'Sign In',
                    style: appTheme.typography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          // Register option
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Don\'t have an account?',
                  style: appTheme.typography.bodyMedium.copyWith(
                    color: appTheme.colors.textSecondaryColor,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: Text(
                    'Register Now',
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
}
