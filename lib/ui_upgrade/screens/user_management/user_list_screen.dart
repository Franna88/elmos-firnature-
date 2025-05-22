import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../design_system/responsive/responsive_layout.dart';

/// User data model
class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String department;
  final DateTime lastLogin;
  final bool isActive;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.department,
    required this.lastLogin,
    required this.isActive,
  });

  String get fullName => '$firstName $lastName';
}

/// User List Screen
///
/// Displays a list of users with filtering and searching capabilities.
/// Implements responsive layouts for desktop, mobile, and tablet platforms.
class UserListScreen extends StatefulWidget {
  const UserListScreen({Key? key}) : super(key: key);

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedRole = 'All Roles';
  String _selectedDepartment = 'All Departments';
  bool _showInactiveUsers = false;

  // Sample data for demonstration
  final List<User> _users = [
    User(
      id: 'U001',
      firstName: 'John',
      lastName: 'Smith',
      email: 'john.smith@elmos.com',
      role: 'Admin',
      department: 'IT',
      lastLogin: DateTime(2023, 10, 15, 9, 30),
      isActive: true,
    ),
    User(
      id: 'U002',
      firstName: 'Emma',
      lastName: 'Johnson',
      email: 'emma.johnson@elmos.com',
      role: 'Manager',
      department: 'Production',
      lastLogin: DateTime(2023, 10, 14, 8, 15),
      isActive: true,
    ),
    User(
      id: 'U003',
      firstName: 'Michael',
      lastName: 'Brown',
      email: 'michael.brown@elmos.com',
      role: 'Supervisor',
      department: 'Quality Control',
      lastLogin: DateTime(2023, 10, 13, 10, 45),
      isActive: true,
    ),
    User(
      id: 'U004',
      firstName: 'Sarah',
      lastName: 'Davis',
      email: 'sarah.davis@elmos.com',
      role: 'Manager',
      department: 'HR',
      lastLogin: DateTime(2023, 10, 10, 14, 20),
      isActive: true,
    ),
    User(
      id: 'U005',
      firstName: 'David',
      lastName: 'Wilson',
      email: 'david.wilson@elmos.com',
      role: 'Operator',
      department: 'Production',
      lastLogin: DateTime(2023, 10, 12, 7, 30),
      isActive: false,
    ),
    User(
      id: 'U006',
      firstName: 'Lisa',
      lastName: 'Martinez',
      email: 'lisa.martinez@elmos.com',
      role: 'Supervisor',
      department: 'Logistics',
      lastLogin: DateTime(2023, 10, 11, 16, 10),
      isActive: true,
    ),
    User(
      id: 'U007',
      firstName: 'Robert',
      lastName: 'Taylor',
      email: 'robert.taylor@elmos.com',
      role: 'Operator',
      department: 'Production',
      lastLogin: DateTime(2023, 10, 9, 12, 45),
      isActive: true,
    ),
    User(
      id: 'U008',
      firstName: 'Jennifer',
      lastName: 'Anderson',
      email: 'jennifer.anderson@elmos.com',
      role: 'Manager',
      department: 'Finance',
      lastLogin: DateTime(2023, 10, 8, 9, 15),
      isActive: true,
    ),
    User(
      id: 'U009',
      firstName: 'Thomas',
      lastName: 'Clark',
      email: 'thomas.clark@elmos.com',
      role: 'Operator',
      department: 'Maintenance',
      lastLogin: DateTime(2023, 10, 5, 8, 30),
      isActive: false,
    ),
    User(
      id: 'U010',
      firstName: 'Amanda',
      lastName: 'Lewis',
      email: 'amanda.lewis@elmos.com',
      role: 'Admin',
      department: 'IT',
      lastLogin: DateTime(2023, 10, 15, 11, 20),
      isActive: true,
    ),
  ];

  List<String> get _roles {
    final roles = _users.map((user) => user.role).toSet().toList();
    roles.sort();
    return ['All Roles', ...roles];
  }

  List<String> get _departments {
    final departments = _users.map((user) => user.department).toSet().toList();
    departments.sort();
    return ['All Departments', ...departments];
  }

  List<User> get _filteredUsers {
    return _users.where((user) {
      // Apply department filter
      if (_selectedDepartment != 'All Departments' &&
          user.department != _selectedDepartment) {
        return false;
      }

      // Apply role filter
      if (_selectedRole != 'All Roles' && user.role != _selectedRole) {
        return false;
      }

      // Apply active/inactive filter
      if (!_showInactiveUsers && !user.isActive) {
        return false;
      }

      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return user.fullName.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            user.id.toLowerCase().contains(query);
      }

      return true;
    }).toList();
  }

  void _onUserTap(User user) {
    // Navigate to user details screen
    Navigator.pushNamed(
      context,
      '/user-details',
      arguments: user.id,
    );
  }

  void _createNewUser() {
    // Navigate to user creation screen
    Navigator.pushNamed(context, '/user-create');
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('User Management', style: appTheme.typography.headingSmall),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section with title and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Users',
                  style: appTheme.typography.headingLarge,
                ),
                ElevatedButton.icon(
                  onPressed: _createNewUser,
                  icon: const Icon(Icons.add),
                  label: const Text('Create New User'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters and search section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filters', style: appTheme.typography.subtitle1),
                    const SizedBox(height: 16),
                    ResponsiveLayout(
                      mobile: Column(
                        children: [
                          _buildSearchField(),
                          const SizedBox(height: 16),
                          _buildRoleFilter(),
                          const SizedBox(height: 16),
                          _buildDepartmentFilter(),
                          const SizedBox(height: 16),
                          _buildShowInactiveToggle(appTheme),
                        ],
                      ),
                      tablet: Column(
                        children: [
                          _buildSearchField(),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildRoleFilter()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildDepartmentFilter()),
                              const SizedBox(width: 16),
                              _buildShowInactiveToggle(appTheme),
                            ],
                          ),
                        ],
                      ),
                      desktop: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(flex: 2, child: _buildSearchField()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildRoleFilter()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildDepartmentFilter()),
                              const SizedBox(width: 16),
                              _buildShowInactiveToggle(appTheme),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Results count
            Text(
              '${_filteredUsers.length} users found',
              style: appTheme.typography.caption,
            ),
            const SizedBox(height: 8),

            // Data table
            Expanded(
              child: AppDataTable<User>(
                columns: [
                  AppDataColumn<User>(
                    label: const Text('ID'),
                    onSort: (a, b) => a.id.compareTo(b.id),
                  ),
                  AppDataColumn<User>(
                    label: const Text('Name'),
                    onSort: (a, b) => a.fullName.compareTo(b.fullName),
                  ),
                  AppDataColumn<User>(
                    label: const Text('Email'),
                    onSort: (a, b) => a.email.compareTo(b.email),
                  ),
                  AppDataColumn<User>(
                    label: const Text('Role'),
                    onSort: (a, b) => a.role.compareTo(b.role),
                  ),
                  AppDataColumn<User>(
                    label: const Text('Department'),
                    onSort: (a, b) => a.department.compareTo(b.department),
                  ),
                  AppDataColumn<User>(
                    label: const Text('Last Login'),
                    onSort: (a, b) => a.lastLogin.compareTo(b.lastLogin),
                  ),
                  AppDataColumn<User>(
                    label: const Text('Status'),
                    onSort: (a, b) =>
                        a.isActive.toString().compareTo(b.isActive.toString()),
                  ),
                  AppDataColumn<User>(
                    label: const Text('Actions'),
                  ),
                ],
                data: _filteredUsers,
                rowBuilder: (user, index) => [
                  DataCell(Text(user.id)),
                  DataCell(Text(user.fullName)),
                  DataCell(Text(user.email)),
                  DataCell(Text(user.role)),
                  DataCell(Text(user.department)),
                  DataCell(Text(_formatDateTime(user.lastLogin))),
                  DataCell(_buildStatusChip(user.isActive, appTheme)),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility),
                        tooltip: 'View',
                        onPressed: () => _onUserTap(user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit',
                        onPressed: () {
                          // Navigate to edit screen
                          Navigator.pushNamed(
                            context,
                            '/user-edit',
                            arguments: user.id,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () {
                          // Show delete confirmation
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete User?'),
                              content: Text(
                                'Are you sure you want to delete ${user.fullName}? This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    // Delete user logic would go here
                                    setState(() {
                                      // Simulate deletion
                                      // In a real app, you would call an API
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'User ${user.fullName} deleted'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Delete',
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
                  )),
                ],
                onRowTap: _onUserTap,
                isLoading: _isLoading,
                initialSortColumnIndex: 0,
                initialSortAscending: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: const InputDecoration(
        hintText: 'Search users...',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildRoleFilter() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Role',
        border: OutlineInputBorder(),
      ),
      value: _selectedRole,
      items: _roles.map((role) {
        return DropdownMenuItem<String>(
          value: role,
          child: Text(role),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedRole = value!;
        });
      },
    );
  }

  Widget _buildDepartmentFilter() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Department',
        border: OutlineInputBorder(),
      ),
      value: _selectedDepartment,
      items: _departments.map((department) {
        return DropdownMenuItem<String>(
          value: department,
          child: Text(department),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedDepartment = value!;
        });
      },
    );
  }

  Widget _buildShowInactiveToggle(AppTheme appTheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: _showInactiveUsers,
          onChanged: (value) {
            setState(() {
              _showInactiveUsers = value ?? false;
            });
          },
        ),
        Text(
          'Show Inactive',
          style: appTheme.typography.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildStatusChip(bool isActive, AppTheme appTheme) {
    final Color chipColor;
    final Color textColor;
    final String label;

    if (isActive) {
      chipColor = appTheme.colors.successColor;
      textColor = Colors.white;
      label = 'Active';
    } else {
      chipColor = appTheme.colors.grey300Color;
      textColor = appTheme.colors.textPrimaryColor;
      label = 'Inactive';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: appTheme.typography.labelSmall.copyWith(color: textColor),
      ),
    );
  }
}
