import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../design_system/responsive/responsive_layout.dart';

/// User Profile Screen
///
/// Displays and allows editing of user profile information.
/// Implements responsive layouts for desktop, mobile, and tablet platforms.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;

  // User profile data
  final _firstNameController = TextEditingController(text: 'John');
  final _lastNameController = TextEditingController(text: 'Smith');
  final _emailController = TextEditingController(text: 'john.smith@elmos.com');
  final _phoneController = TextEditingController(text: '(555) 123-4567');
  final _jobTitleController = TextEditingController(text: 'Production Manager');
  final _departmentController = TextEditingController(text: 'Manufacturing');
  String _selectedRole = 'Manager';
  final List<String> _availableRoles = [
    'Admin',
    'Manager',
    'Supervisor',
    'Operator'
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      _successMessage = null;
      _errorMessage = null;
    });
  }

  void _saveProfile() {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isLoading = true;
    });

    // Validate form
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Simulate profile save
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
        _isEditing = false;
        _successMessage = 'Profile updated successfully';
      });
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _errorMessage = null;
      _successMessage = null;

      // Reset controllers to original values if needed
      // This would typically fetch the latest data from a repository
    });
  }

  void _changePassword() {
    // Navigate to change password screen or show dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: const Text('This feature is not implemented yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('My Profile', style: appTheme.typography.headingSmall),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // Show help dialog
            },
            tooltip: 'Help',
          ),
        ],
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(appTheme),
            const SizedBox(height: 24),
            _buildProfileForm(appTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout(AppTheme appTheme) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(appTheme),
                const SizedBox(height: 32),
                _buildProfileForm(appTheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(AppTheme appTheme) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Profile sidebar
                SizedBox(
                  width: 300,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          _buildProfileAvatar(appTheme, size: 120),
                          const SizedBox(height: 24),
                          Text(
                            '${_firstNameController.text} ${_lastNameController.text}',
                            style: appTheme.typography.headingMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _jobTitleController.text,
                            style: appTheme.typography.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _departmentController.text,
                            style: appTheme.typography.bodyMedium.copyWith(
                              color: appTheme.colors.textSecondaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          // Quick links or stats
                          _buildSidebarItem(
                            appTheme,
                            icon: Icons.assignment,
                            title: 'SOPs Created',
                            value: '24',
                          ),
                          _buildSidebarItem(
                            appTheme,
                            icon: Icons.check_circle,
                            title: 'SOPs Completed',
                            value: '128',
                          ),
                          _buildSidebarItem(
                            appTheme,
                            icon: Icons.access_time,
                            title: 'Last Login',
                            value: 'Today, 9:45 AM',
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _changePassword,
                            icon: const Icon(Icons.lock_outline),
                            label: const Text('Change Password'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // Right side - Profile form
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Profile Information',
                                    style: appTheme.typography.headingMedium,
                                  ),
                                  _isEditing
                                      ? Row(
                                          children: [
                                            TextButton.icon(
                                              onPressed: _cancelEdit,
                                              icon: const Icon(Icons.close),
                                              label: const Text('Cancel'),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: _isLoading
                                                  ? null
                                                  : _saveProfile,
                                              icon: _isLoading
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                Color>(
                                                          Colors.white,
                                                        ),
                                                      ),
                                                    )
                                                  : const Icon(Icons.save),
                                              label: const Text('Save'),
                                            ),
                                          ],
                                        )
                                      : ElevatedButton.icon(
                                          onPressed: _toggleEditMode,
                                          icon: const Icon(Icons.edit),
                                          label: const Text('Edit Profile'),
                                        ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _buildProfileForm(appTheme),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Additional sections could be added here
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Settings',
                                style: appTheme.typography.headingMedium,
                              ),
                              const SizedBox(height: 24),
                              ListTile(
                                leading:
                                    const Icon(Icons.notifications_outlined),
                                title: const Text('Notification Preferences'),
                                subtitle: const Text(
                                    'Manage email and app notifications'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  // Navigate to notification settings
                                },
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.language_outlined),
                                title: const Text('Language Settings'),
                                subtitle: const Text(
                                    'Change your preferred language'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  // Navigate to language settings
                                },
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.lock_outline),
                                title: const Text('Security Settings'),
                                subtitle: const Text(
                                    'Update password and security options'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _changePassword,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    AppTheme appTheme, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: appTheme.colors.textSecondaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: appTheme.typography.bodyMedium.copyWith(
                color: appTheme.colors.textSecondaryColor,
              ),
            ),
          ),
          Text(
            value,
            style: appTheme.typography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(AppTheme appTheme) {
    return Column(
      children: [
        // Status messages
        if (_successMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: appTheme.colors.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: appTheme.colors.successColor),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: appTheme.colors.successColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _successMessage!,
                    style: appTheme.typography.bodyMedium.copyWith(
                      color: appTheme.colors.successColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

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

        // Header with user info and actions
        Row(
          children: [
            _buildProfileAvatar(appTheme),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_firstNameController.text} ${_lastNameController.text}',
                    style: appTheme.typography.headingMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _jobTitleController.text,
                    style: appTheme.typography.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _emailController.text,
                    style: appTheme.typography.bodyMedium.copyWith(
                      color: appTheme.colors.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            if (ResponsiveLayout.isMobileOrTablet(context))
              _isEditing
                  ? Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Cancel',
                          onPressed: _cancelEdit,
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveProfile,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: const Text('Save'),
                        ),
                      ],
                    )
                  : ElevatedButton.icon(
                      onPressed: _toggleEditMode,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileAvatar(AppTheme appTheme, {double size = 80}) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: appTheme.colors.primaryColor.withOpacity(0.2),
      child: Text(
        '${_firstNameController.text[0]}${_lastNameController.text[0]}',
        style: TextStyle(
          fontSize: size / 3,
          fontWeight: FontWeight.bold,
          color: appTheme.colors.primaryColor,
        ),
      ),
    );
  }

  Widget _buildProfileForm(AppTheme appTheme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ResponsiveLayout.isDesktop(context) ||
              ResponsiveLayout.isLargeDesktop(context))
            Text(
              'Personal Information',
              style: appTheme.typography.subtitle1,
            ),
          if (ResponsiveLayout.isDesktop(context) ||
              ResponsiveLayout.isLargeDesktop(context))
            const SizedBox(height: 16),

          // Name fields (in a row for tablet/desktop)
          ResponsiveLayout(
            mobile: Column(
              children: [
                _buildTextField(
                  controller: _firstNameController,
                  label: 'First Name',
                  readOnly: !_isEditing,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  readOnly: !_isEditing,
                ),
              ],
            ),
            tablet: Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _firstNameController,
                    label: 'First Name',
                    readOnly: !_isEditing,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    readOnly: !_isEditing,
                  ),
                ),
              ],
            ),
            desktop: Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _firstNameController,
                    label: 'First Name',
                    readOnly: !_isEditing,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    readOnly: !_isEditing,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Contact information
          if (ResponsiveLayout.isDesktop(context) ||
              ResponsiveLayout.isLargeDesktop(context)) ...[
            const SizedBox(height: 8),
            Text(
              'Contact Information',
              style: appTheme.typography.subtitle1,
            ),
            const SizedBox(height: 16),
          ],

          _buildTextField(
            controller: _emailController,
            label: 'Email',
            readOnly: true, // Email is typically not editable
            prefixIcon: Icons.email_outlined,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            readOnly: !_isEditing,
            prefixIcon: Icons.phone_outlined,
          ),
          const SizedBox(height: 24),

          // Job information
          if (ResponsiveLayout.isDesktop(context) ||
              ResponsiveLayout.isLargeDesktop(context)) ...[
            const SizedBox(height: 8),
            Text(
              'Job Information',
              style: appTheme.typography.subtitle1,
            ),
            const SizedBox(height: 16),
          ],

          ResponsiveLayout(
            mobile: Column(
              children: [
                _buildTextField(
                  controller: _jobTitleController,
                  label: 'Job Title',
                  readOnly: !_isEditing,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _departmentController,
                  label: 'Department',
                  readOnly: !_isEditing,
                ),
              ],
            ),
            tablet: Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _jobTitleController,
                    label: 'Job Title',
                    readOnly: !_isEditing,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _departmentController,
                    label: 'Department',
                    readOnly: !_isEditing,
                  ),
                ),
              ],
            ),
            desktop: Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _jobTitleController,
                    label: 'Job Title',
                    readOnly: !_isEditing,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _departmentController,
                    label: 'Department',
                    readOnly: !_isEditing,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Role dropdown
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabled: _isEditing,
            ),
            value: _selectedRole,
            items: _availableRoles.map((role) {
              return DropdownMenuItem<String>(
                value: role,
                child: Text(role),
              );
            }).toList(),
            onChanged: _isEditing
                ? (value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  }
                : null,
          ),

          // Mobile/tablet save button (bottom of form)
          if (ResponsiveLayout.isMobileOrTablet(context) && _isEditing) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Save Profile'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool readOnly,
    IconData? prefixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
      readOnly: readOnly,
      validator: validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          },
    );
  }
}
