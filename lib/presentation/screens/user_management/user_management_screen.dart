import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../data/services/user_management_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/user_model.dart';
import '../../widgets/app_scaffold.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _searchQuery = '';
  String _selectedRole = 'All';
  bool _showInactiveUsers = false;
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUsers();
    });
  }

  Future<void> _refreshUsers() async {
    final userManagementService =
        Provider.of<UserManagementService>(context, listen: false);
    await userManagementService.refreshUsers();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userManagementService = Provider.of<UserManagementService>(context);

    // Check if current user is admin
    if (authService.userRole != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'You do not have permission to access user management.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final filteredUsers = _getFilteredUsers(userManagementService.users);

    return AppScaffold(
      title: 'User Management',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Users',
          onPressed: _refreshUsers,
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Add User',
          onPressed: () => _showAddUserDialog(context),
        ),
      ],
      body: userManagementService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildUserManagementContent(
              context, userManagementService, filteredUsers),
    );
  }

  Widget _buildUserManagementContent(
      BuildContext context,
      UserManagementService userManagementService,
      List<UserModel> filteredUsers) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with statistics
          _buildHeader(userManagementService.users),

          const SizedBox(height: 24),

          // Filters and search
          _buildFiltersSection(),

          const SizedBox(height: 16),

          // Users data table
          Expanded(
            child: _buildUsersDataTable(context, filteredUsers),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(List<UserModel> allUsers) {
    final activeUsers = allUsers.where((user) => user.isActive).length;
    final inactiveUsers = allUsers.length - activeUsers;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Management',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage all system users, their roles, and permissions',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            _buildStatCard(
                'Total Users', allUsers.length.toString(), Icons.people),
            const SizedBox(width: 16),
            _buildStatCard('Active', activeUsers.toString(), Icons.check_circle,
                color: Colors.green),
            const SizedBox(width: 16),
            _buildStatCard(
                'Inactive', inactiveUsers.toString(), Icons.pause_circle,
                color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon,
      {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (color ?? Colors.blue).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (color ?? Colors.blue).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color ?? Colors.blue, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.blue,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: (color ?? Colors.blue).withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                // Search field
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search users by name, email, or role...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // Role filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Role',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ['All', ...UserRole.allRoles]
                        .map((role) => DropdownMenuItem(
                              value: role,
                              child: Text(role == 'All'
                                  ? 'All Roles'
                                  : UserRole.getRoleDisplayName(role)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value ?? 'All';
                      });
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // Show inactive users toggle
                Row(
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
                    const Text('Show Inactive'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersDataTable(BuildContext context, List<UserModel> users) {
    return Card(
      child: SingleChildScrollView(
        child: DataTable(
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          columns: [
            DataColumn(
              label: const Text('Name'),
              onSort: (columnIndex, ascending) {
                _sortUsers(users, columnIndex, ascending, (user) => user.name);
              },
            ),
            DataColumn(
              label: const Text('Email'),
              onSort: (columnIndex, ascending) {
                _sortUsers(users, columnIndex, ascending, (user) => user.email);
              },
            ),
            DataColumn(
              label: const Text('Role'),
              onSort: (columnIndex, ascending) {
                _sortUsers(users, columnIndex, ascending, (user) => user.role);
              },
            ),
            DataColumn(
              label: const Text('Status'),
              onSort: (columnIndex, ascending) {
                _sortUsers(users, columnIndex, ascending,
                    (user) => user.isActive ? 'Active' : 'Inactive');
              },
            ),
            DataColumn(
              label: const Text('Created'),
              onSort: (columnIndex, ascending) {
                _sortUsers(users, columnIndex, ascending,
                    (user) => user.createdAt.toString());
              },
            ),
            const DataColumn(label: Text('Actions')),
          ],
          rows: users.map((user) => _buildUserDataRow(context, user)).toList(),
        ),
      ),
    );
  }

  DataRow _buildUserDataRow(BuildContext context, UserModel user) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _getRoleColor(user.role),
                radius: 16,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.phoneNumber != null)
                      Text(
                        user.phoneNumber!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DataCell(
          SelectableText(
            user.email,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getRoleColor(user.role).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: _getRoleColor(user.role).withOpacity(0.3)),
            ),
            child: Text(
              UserRole.getRoleDisplayName(user.role),
              style: TextStyle(
                color: _getRoleColor(user.role),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: user.isActive ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                user.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: user.isActive ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Text(dateFormat.format(user.createdAt)),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                tooltip: 'Edit User',
                onPressed: () => _showEditUserDialog(context, user),
              ),
              IconButton(
                icon: Icon(
                  user.isActive ? Icons.pause : Icons.play_arrow,
                  size: 18,
                ),
                tooltip: user.isActive ? 'Deactivate User' : 'Activate User',
                onPressed: () => _toggleUserStatus(context, user),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                tooltip: 'Delete User',
                onPressed: () => _showDeleteUserDialog(context, user),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<UserModel> _getFilteredUsers(List<UserModel> users) {
    var filtered = users.where((user) {
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.role.toLowerCase().contains(_searchQuery.toLowerCase());

      // Role filter
      final matchesRole = _selectedRole == 'All' || user.role == _selectedRole;

      // Active/inactive filter
      final matchesStatus = _showInactiveUsers || user.isActive;

      return matchesSearch && matchesRole && matchesStatus;
    }).toList();

    return filtered;
  }

  void _sortUsers(List<UserModel> users, int columnIndex, bool ascending,
      String Function(UserModel) getValue) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      users.sort((a, b) {
        final aValue = getValue(a);
        final bValue = getValue(b);
        return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      });
    });
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.purple;
      case 'assembly':
        return Colors.blue;
      case 'finishing':
        return Colors.green;
      case 'machinery':
        return Colors.orange;
      case 'quality':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  // Dialog Functions
  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _UserFormDialog(
        title: 'Add New User',
        onSave: (name, email, password, role, phoneNumber) async {
          final userManagementService =
              Provider.of<UserManagementService>(context, listen: false);

          final result = await userManagementService.createUser(
            name: name,
            email: email,
            password: password,
            role: role,
            phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
          );

          if (context.mounted) {
            if (result.success) {
              Navigator.of(context).pop();
              _showUserCreatedDialog(context, result);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => _UserFormDialog(
        title: 'Edit User',
        user: user,
        isEdit: true,
        onSave: (name, email, _, role, phoneNumber) async {
          final userManagementService =
              Provider.of<UserManagementService>(context, listen: false);

          final updatedUser = user.copyWith(
            name: name,
            role: role,
            phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
            updatedAt: DateTime.now(),
          );

          final success = await userManagementService.updateUser(updatedUser);

          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success
                    ? 'User updated successfully'
                    : 'Failed to update user'),
                backgroundColor: success ? Colors.green : Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  void _showDeleteUserDialog(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete "${user.name}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final userManagementService =
                  Provider.of<UserManagementService>(context, listen: false);

              final success = await userManagementService.deleteUser(user.id);

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'User deleted successfully'
                        : 'Failed to delete user'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _toggleUserStatus(BuildContext context, UserModel user) async {
    final userManagementService =
        Provider.of<UserManagementService>(context, listen: false);

    final success = await userManagementService.toggleUserStatus(user.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'User status updated successfully'
              : 'Failed to update user status'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showUserCreatedDialog(BuildContext context, UserCreateResult result) {
    if (result.credentials == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('User Created Successfully'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The user has been created successfully. Please share these login credentials with the user:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Login Credentials:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Email: ',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      Expanded(
                        child: SelectableText(
                          result.credentials!.email,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: result.credentials!.email));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Email copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Password: ',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      Expanded(
                        child: SelectableText(
                          result.credentials!.password,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text: result.credentials!.password));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Password copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'The user can now log into the system using these credentials.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// User Form Dialog Widget
class _UserFormDialog extends StatefulWidget {
  final String title;
  final UserModel? user;
  final bool isEdit;
  final Function(String name, String email, String password, String role,
      String phoneNumber) onSave;

  const _UserFormDialog({
    required this.title,
    required this.onSave,
    this.user,
    this.isEdit = false,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _phoneController;
  late String _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _passwordController = TextEditingController();
    _phoneController =
        TextEditingController(text: widget.user?.phoneNumber ?? '');
    _selectedRole = widget.user?.role ?? UserRole.user;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                enabled:
                    !widget.isEdit, // Don't allow email changes in edit mode
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              if (!widget.isEdit) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: UserRole.allRoles
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(UserRole.getRoleDisplayName(role)),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value ?? UserRole.user;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.isEdit ? 'Save Changes' : 'Create User'),
        ),
      ],
    );
  }

  void _handleSave() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      await widget.onSave(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _selectedRole,
        _phoneController.text.trim(),
      );

      setState(() {
        _isLoading = false;
      });
    }
  }
}
