import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../design_system/responsive/responsive_layout.dart';

/// Password Reset Screen
///
/// Implements the password reset functionality with responsive layouts
/// for desktop, mobile, and tablet platforms.
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({Key? key}) : super(key: key);

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _resetEmailSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handlePasswordReset() {
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

    // Simulate password reset email sending
    Future.delayed(const Duration(seconds: 2), () {
      if (_emailController.text.contains('@')) {
        // Successful password reset initiation
        setState(() {
          _resetEmailSent = true;
          _isLoading = false;
        });
      } else {
        // Failed password reset initiation
        setState(() {
          _errorMessage =
              'Unable to send reset email. Please check your email address.';
          _isLoading = false;
        });
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
        title: Text('Password Reset', style: appTheme.typography.headingSmall),
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
            const SizedBox(height: 40),
            _buildLogo(appTheme),
            const SizedBox(height: 40),
            _resetEmailSent
                ? _buildSuccessMessage(appTheme)
                : _buildPasswordResetForm(appTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout(AppTheme appTheme) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                _buildLogo(appTheme),
                const SizedBox(height: 60),
                _resetEmailSent
                    ? _buildSuccessMessage(appTheme)
                    : _buildPasswordResetForm(appTheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(AppTheme appTheme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildLogo(appTheme),
                const SizedBox(height: 40),
                _resetEmailSent
                    ? _buildSuccessMessage(appTheme)
                    : _buildPasswordResetForm(appTheme),
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildPasswordResetForm(AppTheme appTheme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reset Your Password',
            style: appTheme.typography.headingMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Enter your email address and we\'ll send you instructions to reset your password.',
            style: appTheme.typography.bodyMedium.copyWith(
              color: appTheme.colors.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

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
          const SizedBox(height: 32),

          // Reset Password button
          ElevatedButton(
            onPressed: _isLoading ? null : _handlePasswordReset,
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
                    'Reset Password',
                    style: appTheme.typography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          // Back to login link
          Center(
            child: TextButton.icon(
              onPressed: _handleBackToLogin,
              icon: const Icon(Icons.arrow_back),
              label: Text(
                'Back to Login',
                style: appTheme.typography.bodyMedium.copyWith(
                  color: appTheme.colors.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage(AppTheme appTheme) {
    return Column(
      children: [
        Icon(
          Icons.check_circle_outline,
          color: appTheme.colors.successColor,
          size: 72,
        ),
        const SizedBox(height: 24),
        Text(
          'Check Your Email',
          style: appTheme.typography.headingMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'We\'ve sent password reset instructions to:',
          style: appTheme.typography.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _emailController.text,
          style: appTheme.typography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          'Please check your email and follow the instructions to reset your password.',
          style: appTheme.typography.bodyMedium.copyWith(
            color: appTheme.colors.textSecondaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: _handleBackToLogin,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            side: BorderSide(color: appTheme.colors.primaryColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Back to Login',
            style: appTheme.typography.bodyMedium.copyWith(
              color: appTheme.colors.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
