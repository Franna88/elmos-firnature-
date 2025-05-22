import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../design_system/responsive/responsive_layout.dart';

/// Settings Screen
///
/// Implements application settings configuration with responsive layouts
/// for desktop, mobile, and tablet platforms.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings state
  bool _darkMode = false;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _soundEnabled = true;
  double _textSize = 1.0; // 1.0 = default, 0.8 = small, 1.2 = large
  String _selectedLanguage = 'English';
  String _selectedTheme = 'System Default';

  // Options
  final List<String> _languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese'
  ];
  final List<String> _themes = [
    'System Default',
    'Light',
    'Dark',
    'Blue',
    'Green'
  ];

  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;

  void _saveSettings() {
    setState(() {
      _isLoading = true;
      _successMessage = null;
      _errorMessage = null;
    });

    // Simulate saving settings
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
        _successMessage = 'Settings saved successfully';
      });

      // Hide success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: appTheme.typography.headingSmall),
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
            _buildStatusMessages(appTheme),
            const SizedBox(height: 16),
            _buildSettingsSections(appTheme, isMobile: true),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Save Settings',
                        style: appTheme.typography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
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
                _buildStatusMessages(appTheme),
                const SizedBox(height: 24),
                _buildSettingsSections(appTheme, isMobile: false),
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 32,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Save Settings',
                            style: appTheme.typography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Application Settings',
                        style: appTheme.typography.headingLarge,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 32,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.save),
                                const SizedBox(width: 8),
                                Text(
                                  'Save Settings',
                                  style: appTheme.typography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStatusMessages(appTheme),
                const SizedBox(height: 24),
                _buildSettingsSections(appTheme, isMobile: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMessages(AppTheme appTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSettingsSections(AppTheme appTheme, {required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Appearance Settings
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
                  'Appearance',
                  style: appTheme.typography.headingMedium,
                ),
                const SizedBox(height: 24),

                // Theme Selector
                ResponsiveLayout(
                  mobile: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme',
                        style: appTheme.typography.subtitle1,
                      ),
                      const SizedBox(height: 8),
                      _buildThemeDropdown(appTheme),
                    ],
                  ),
                  tablet: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          'Theme',
                          style: appTheme.typography.subtitle1,
                        ),
                      ),
                      Expanded(
                        child: _buildThemeDropdown(appTheme),
                      ),
                    ],
                  ),
                  desktop: Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: Text(
                          'Theme',
                          style: appTheme.typography.subtitle1,
                        ),
                      ),
                      Expanded(
                        child: _buildThemeDropdown(appTheme),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Dark Mode Toggle
                _buildSwitchOption(
                  appTheme,
                  title: 'Dark Mode',
                  subtitle: 'Enable dark theme throughout the application',
                  value: _darkMode,
                  onChanged: (value) {
                    setState(() {
                      _darkMode = value;
                    });
                  },
                  isMobile: isMobile,
                ),
                const SizedBox(height: 16),

                // Text Size Slider
                ResponsiveLayout(
                  mobile: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Text Size',
                        style: appTheme.typography.subtitle1,
                      ),
                      const SizedBox(height: 8),
                      _buildTextSizeSlider(appTheme),
                    ],
                  ),
                  tablet: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          'Text Size',
                          style: appTheme.typography.subtitle1,
                        ),
                      ),
                      Expanded(
                        child: _buildTextSizeSlider(appTheme),
                      ),
                    ],
                  ),
                  desktop: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: Text(
                          'Text Size',
                          style: appTheme.typography.subtitle1,
                        ),
                      ),
                      Expanded(
                        child: _buildTextSizeSlider(appTheme),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Language Settings
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
                  'Language',
                  style: appTheme.typography.headingMedium,
                ),
                const SizedBox(height: 24),

                // Language Selector
                ResponsiveLayout(
                  mobile: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Application Language',
                        style: appTheme.typography.subtitle1,
                      ),
                      const SizedBox(height: 8),
                      _buildLanguageDropdown(appTheme),
                    ],
                  ),
                  tablet: Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: Text(
                          'Application Language',
                          style: appTheme.typography.subtitle1,
                        ),
                      ),
                      Expanded(
                        child: _buildLanguageDropdown(appTheme),
                      ),
                    ],
                  ),
                  desktop: Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: Text(
                          'Application Language',
                          style: appTheme.typography.subtitle1,
                        ),
                      ),
                      Expanded(
                        child: _buildLanguageDropdown(appTheme),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Notification Settings
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
                  'Notifications',
                  style: appTheme.typography.headingMedium,
                ),
                const SizedBox(height: 24),

                // Email Notifications
                _buildSwitchOption(
                  appTheme,
                  title: 'Email Notifications',
                  subtitle: 'Receive notifications via email',
                  value: _emailNotifications,
                  onChanged: (value) {
                    setState(() {
                      _emailNotifications = value;
                    });
                  },
                  isMobile: isMobile,
                ),
                const SizedBox(height: 16),

                // Push Notifications
                _buildSwitchOption(
                  appTheme,
                  title: 'Push Notifications',
                  subtitle: 'Receive notifications on your device',
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() {
                      _pushNotifications = value;
                    });
                  },
                  isMobile: isMobile,
                ),
                const SizedBox(height: 16),

                // Sound
                _buildSwitchOption(
                  appTheme,
                  title: 'Sound',
                  subtitle: 'Play sound for notifications',
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() {
                      _soundEnabled = value;
                    });
                  },
                  isMobile: isMobile,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Advanced Settings
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
                  'Advanced',
                  style: appTheme.typography.headingMedium,
                ),
                const SizedBox(height: 24),

                // Data Management
                ListTile(
                  leading: Icon(
                    Icons.storage_outlined,
                    color: appTheme.colors.primaryColor,
                  ),
                  title: Text(
                    'Data Management',
                    style: appTheme.typography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Manage cached data and storage usage',
                    style: appTheme.typography.bodyMedium,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to data management settings
                  },
                ),
                const Divider(),

                // Export Settings
                ListTile(
                  leading: Icon(
                    Icons.upload_file_outlined,
                    color: appTheme.colors.primaryColor,
                  ),
                  title: Text(
                    'Export Settings',
                    style: appTheme.typography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Export your settings to a file',
                    style: appTheme.typography.bodyMedium,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Handle settings export
                  },
                ),
                const Divider(),

                // Reset Settings
                ListTile(
                  leading: Icon(
                    Icons.restore_outlined,
                    color: appTheme.colors.warningColor,
                  ),
                  title: Text(
                    'Reset to Default',
                    style: appTheme.typography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Reset all settings to default values',
                    style: appTheme.typography.bodyMedium,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Show reset confirmation dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Reset Settings?'),
                        content: const Text(
                          'This will reset all settings to their default values. This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // Reset settings
                              setState(() {
                                _darkMode = false;
                                _emailNotifications = true;
                                _pushNotifications = true;
                                _soundEnabled = true;
                                _textSize = 1.0;
                                _selectedLanguage = 'English';
                                _selectedTheme = 'System Default';
                              });
                            },
                            child: Text(
                              'Reset',
                              style: TextStyle(
                                color: appTheme.colors.errorColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchOption(
    AppTheme appTheme, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isMobile,
  }) {
    if (isMobile) {
      return SwitchListTile(
        title: Text(
          title,
          style: appTheme.typography.bodyLarge.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: appTheme.typography.bodyMedium,
        ),
        value: value,
        onChanged: onChanged,
        activeColor: appTheme.colors.primaryColor,
      );
    } else {
      return Row(
        children: [
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: appTheme.typography.subtitle1,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: appTheme.typography.bodyMedium.copyWith(
                    color: appTheme.colors.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: appTheme.colors.primaryColor,
          ),
        ],
      );
    }
  }

  Widget _buildTextSizeSlider(AppTheme appTheme) {
    return Column(
      children: [
        Slider(
          value: _textSize,
          min: 0.8,
          max: 1.2,
          divisions: 4,
          label: _getTextSizeLabel(),
          onChanged: (value) {
            setState(() {
              _textSize = value;
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Smaller',
              style: appTheme.typography.bodySmall,
            ),
            Text(
              'Default',
              style: appTheme.typography.bodySmall,
            ),
            Text(
              'Larger',
              style: appTheme.typography.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  String _getTextSizeLabel() {
    if (_textSize <= 0.8) return 'Small';
    if (_textSize <= 0.9) return 'Medium Small';
    if (_textSize <= 1.1) return 'Medium';
    if (_textSize <= 1.2) return 'Medium Large';
    return 'Large';
  }

  Widget _buildThemeDropdown(AppTheme appTheme) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      value: _selectedTheme,
      items: _themes.map((theme) {
        return DropdownMenuItem<String>(
          value: theme,
          child: Text(theme),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedTheme = value!;
          // Update dark mode based on theme selection
          if (value == 'Dark') {
            _darkMode = true;
          } else if (value == 'Light') {
            _darkMode = false;
          }
        });
      },
    );
  }

  Widget _buildLanguageDropdown(AppTheme appTheme) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      value: _selectedLanguage,
      items: _languages.map((language) {
        return DropdownMenuItem<String>(
          value: language,
          child: Text(language),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedLanguage = value!;
        });
      },
    );
  }
}
