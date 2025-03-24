import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/models/sop_model.dart';

class SOPsScreen extends StatefulWidget {
  const SOPsScreen({super.key});

  @override
  State<SOPsScreen> createState() => _SOPsScreenState();
}

class _SOPsScreenState extends State<SOPsScreen> {
  String _searchQuery = '';
  String _selectedDepartment = 'All';
  
  @override
  Widget build(BuildContext context) {
    final sopService = Provider.of<SOPService>(context);
    
    // Filter SOPs based on search query and department
    List<SOP> filteredSOPs = sopService.searchSOPs(_searchQuery);
    if (_selectedDepartment != 'All') {
      filteredSOPs = filteredSOPs
          .where((sop) => sop.department == _selectedDepartment)
          .toList();
    }
    
    // Get unique departments for filter dropdown
    final departments = ['All', ...sopService.sops
        .map((sop) => sop.department)
        .toSet()
        ];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My SOPs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // Show help dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('SOPs Help'),
                  content: const Text(
                    'Standard Operating Procedures (SOPs) document the standard processes '
                    'for your organization. Here you can view, edit, and manage all your SOPs '
                    'in one place.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search SOPs...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedDepartment,
                    items: departments.map((department) {
                      return DropdownMenuItem<String>(
                        value: department,
                        child: Text(department),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedDepartment = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // SOPs list
          Expanded(
            child: filteredSOPs.isEmpty
                ? const Center(
                    child: Text('No SOPs found.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredSOPs.length,
                    itemBuilder: (context, index) {
                      final sop = filteredSOPs[index];
                      return _buildSOPCard(context, sop);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/editor/new');
        },
        backgroundColor: const Color(0xffB21E1E),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildSOPCard(BuildContext context, SOP sop) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SOP header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sop.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Department: ${sop.department} • Rev: ${sop.revisionNumber}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Last updated: ${_formatDate(sop.updatedAt)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // SOP content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sop.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.visibility),
                      label: const Text('View'),
                      onPressed: () {
                        context.go('/editor/${sop.id}');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff17A2B8),
                        side: const BorderSide(color: Color(0xff17A2B8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () {
                        context.go('/editor/${sop.id}');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff6F42C1),
                        side: const BorderSide(color: Color(0xff6F42C1)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
} 