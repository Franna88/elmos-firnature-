import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/category_service.dart';
import '../../../data/models/category_model.dart' as models;
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final categoryService = Provider.of<CategoryService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // User profile section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'User Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(authService.userName ?? 'User'),
            subtitle: Text(authService.userEmail ?? 'user@example.com'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // Edit profile
                _showEditProfileDialog();
              },
            ),
          ),
          const Divider(),

          // Category Management Section - NEW
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Category Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Text('SOP Categories',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Category'),
                  onPressed: () {
                    _showAddCategoryDialog(context);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: (categoryService.categories.isEmpty)
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No categories defined yet.'),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemCount: categoryService.categories.length,
                      itemBuilder: (context, index) {
                        final category = categoryService.categories[index];
                        return ListTile(
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _getCategoryColor(category.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(category.name),
                          subtitle: category.description != null
                              ? Text(category.description!,
                                  maxLines: 1, overflow: TextOverflow.ellipsis)
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                tooltip: 'Edit Category',
                                onPressed: () {
                                  _showEditCategoryDialog(context, category);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    size: 20, color: Colors.red),
                                tooltip: 'Delete Category',
                                onPressed: () {
                                  _showDeleteCategoryDialog(context, category);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          const Divider(),

          // Appearance section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme'),
            value: _darkMode,
            onChanged: (value) {
              setState(() {
                _darkMode = value;
              });
              // In a real app, this would update the theme
            },
          ),
          const Divider(),

          // Notifications section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle:
                const Text('Receive notifications for updates and changes'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              // In a real app, this would update notification settings
            },
          ),
          const Divider(),

          // Developer Tools section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Developer Tools',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('Base64 Image Upload Test'),
            subtitle:
                const Text('Test uploading base64 images to Firebase Storage'),
            leading: const Icon(Icons.image),
            onTap: () {
              context.go('/image-upload-test');
            },
          ),
          const Divider(),

          // About section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About SOP Management System'),
            onTap: () {
              // Show about dialog
              _showAboutDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            onTap: () {
              // Show help dialog
              _showHelpDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            onTap: () {
              // Show privacy policy
              launchUrl(
                Uri.parse('YOUR_PRIVACY_POLICY_URL_HERE'),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            onTap: () {
              // Show terms of service
            },
          ),
          const Divider(),

          // Account section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              // Show confirmation dialog
              final confirm = await _showLogoutConfirmationDialog();
              if (confirm && mounted) {
                await authService.logout();
                if (mounted) {
                  context.go('/login');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(
      text: Provider.of<AuthService>(context, listen: false).userName,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter your name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Update profile
              // In a real app, this would update the user's profile
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About SOP Management System'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SOP Management System',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            SizedBox(height: 16),
            Text(
              'A comprehensive platform for creating, managing, and customizing Standard Operating Procedures (SOPs) for businesses of all sizes.',
            ),
            SizedBox(height: 16),
            Text('© 2025 SOP Management System'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need help with the SOP Management System?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text('Contact our support team:'),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.email, size: 16),
                SizedBox(width: 8),
                Text('support@sopmanagement.com'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, size: 16),
                SizedBox(width: 8),
                Text('+1 (555) 123-4567'),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Our support team is available Monday through Friday, 9 AM to 5 PM EST.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showLogoutConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // New method to handle color strings from the database
  Color _getCategoryColor(String? colorString) {
    if (colorString == null || !colorString.startsWith('#')) {
      return Colors.grey; // Default color
    }

    try {
      // Parse hex color string (e.g., "#FF0000" for red)
      String hex = colorString.replaceFirst('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex'; // Add alpha if not present
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey; // Return default if parsing fails
    }
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'Enter category name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Enter category description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Color:'),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    // Show color picker here if you have a color picker package
                    // For simplicity, we'll just use a fixed color
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final categoryService =
                    Provider.of<CategoryService>(context, listen: false);

                // Convert color to hex string
                final colorHex =
                    '#${selectedColor.value.toRadixString(16).substring(2)}';

                await categoryService.createCategory(
                  nameController.text,
                  description: descriptionController.text.isNotEmpty
                      ? descriptionController.text
                      : null,
                  color: colorHex,
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Category added successfully')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Category name is required')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, models.Category category) {
    final nameController = TextEditingController(text: category.name);
    final descriptionController =
        TextEditingController(text: category.description ?? '');
    Color selectedColor = _getCategoryColor(category.color);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'Enter category name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Enter category description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Color:'),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    // Show color picker here if you have a color picker package
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final categoryService =
                    Provider.of<CategoryService>(context, listen: false);

                // Convert color to hex string
                final colorHex =
                    '#${selectedColor.value.toRadixString(16).substring(2)}';

                // Create updated category with same ID
                final updatedCategory = models.Category(
                  id: category.id,
                  name: nameController.text,
                  description: descriptionController.text.isNotEmpty
                      ? descriptionController.text
                      : null,
                  color: colorHex,
                  createdAt: category.createdAt,
                );

                await categoryService.updateCategory(updatedCategory);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Category updated successfully')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Category name is required')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCategoryDialog(
      BuildContext context, models.Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
            'Are you sure you want to delete "${category.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              final categoryService =
                  Provider.of<CategoryService>(context, listen: false);
              await categoryService.deleteCategory(category.id);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Category deleted successfully')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
