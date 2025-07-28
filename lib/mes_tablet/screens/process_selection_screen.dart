import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../../data/services/mes_service.dart';
import '../../data/models/mes_process_model.dart';
import '../../core/theme/app_theme.dart';

class ProcessSelectionScreen extends StatefulWidget {
  final User? initialUser;

  const ProcessSelectionScreen({Key? key, this.initialUser}) : super(key: key);

  @override
  State<ProcessSelectionScreen> createState() => _ProcessSelectionScreenState();
}

class _ProcessSelectionScreenState extends State<ProcessSelectionScreen> {
  bool _isLoading = false;
  User? _user;
  List<MESProcess> _processes = [];

  @override
  void initState() {
    super.initState();
    // If initialUser is provided, use it right away
    _user = widget.initialUser;
    _loadProcesses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If initialUser wasn't provided, try to get it from route arguments
    if (_user == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is User) {
        _user = args;
      }
    }
  }

  Future<void> _loadProcesses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final mesService = Provider.of<MESService>(context, listen: false);
      final processes = await mesService.fetchProcesses(onlyActive: true);

      // Debug: Print process information
      print(
          '🔍 PROCESS SELECTION: Fetched ${processes.length} active processes');
      for (final process in processes) {
        print(
            '  📋 Process: ${process.name} (ID: ${process.id}, Active: ${process.isActive})');
      }

      // Show all active processes (they can still be used even without items)
      // Note: Items will be loaded when the process is selected
      setState(() {
        _processes = processes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading processes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Make sure we have a user
    if (_user == null) {
      // Navigate back to login if we somehow don't have a user
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, ${_user!.name}'),
            Text(
              'Select Your Process',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProcesses,
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_processes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_tree,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Processes Available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please contact your supervisor to activate processes.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade500,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadProcesses,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Responsive layout for different screen sizes
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1200 ? 3 : (screenWidth > 800 ? 2 : 1);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header information
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_tree,
                      color: AppColors.primaryBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Select Manufacturing Process',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the process you will be working on today. This will determine which items are available for production.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Process count
          Text(
            '${_processes.length} Available Process${_processes.length != 1 ? 'es' : ''}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 16),

          // Process grid
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 1.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _processes.length,
              itemBuilder: (context, index) {
                final process = _processes[index];
                return _buildProcessCard(process);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessCard(MESProcess process) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _selectProcess(process),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Process icon with setup indicator
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Icon(
                      Icons.account_tree,
                      size: 32,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  if (process.requiresSetup)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.build,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Process name
              Text(
                process.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Process description
              if (process.description != null)
                Text(
                  process.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),

              // Process info chips
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  if (process.stationName != null)
                    _buildInfoChip(
                      Icons.location_on,
                      process.stationName!,
                      Colors.green,
                    ),
                  if (process.requiresSetup)
                    _buildInfoChip(
                      Icons.build,
                      'Setup Required',
                      Colors.blue,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectProcess(MESProcess process) async {
    // Show loading while navigating
    setState(() {
      _isLoading = true;
    });

    try {
      // Navigate to item selection with the selected process and user
      Navigator.pushNamed(
        context,
        '/item_selection',
        arguments: {
          'user': _user!,
          'process': process,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error navigating: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
