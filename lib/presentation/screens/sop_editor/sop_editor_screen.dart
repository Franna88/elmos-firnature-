import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/models/sop_model.dart';

class SOPEditorScreen extends StatefulWidget {
  final String sopId;

  const SOPEditorScreen({super.key, required this.sopId});

  @override
  State<SOPEditorScreen> createState() => _SOPEditorScreenState();
}

class _SOPEditorScreenState extends State<SOPEditorScreen> {
  late SOP _sop;
  bool _isLoading = true;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _departmentController;
  
  @override
  void initState() {
    super.initState();
    _loadSOP();
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _departmentController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSOP() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final sopService = Provider.of<SOPService>(context, listen: false);
      
      if (widget.sopId == 'new') {
        // Schedule the creation of a new SOP after the current build phase is complete
        // This prevents the "setState during build" error
        Future.microtask(() async {
          final newSop = await sopService.createSop(
            'New SOP',
            'Description of the new SOP',
            'Department',
          );
          
          if (mounted) {
            setState(() {
              _sop = newSop;
              // Initialize controllers
              _titleController = TextEditingController(text: _sop.title);
              _descriptionController = TextEditingController(text: _sop.description);
              _departmentController = TextEditingController(text: _sop.department);
              _isLoading = false;
              _isEditing = true;
            });
          }
        });
        return; // Exit early, the microtask will handle the rest
      } else {
        // Load existing SOP
        final existingSop = sopService.getSopById(widget.sopId);
        if (existingSop == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('SOP not found')),
            );
            context.go('/');
            return;
          }
        }
        _sop = existingSop!;
      }
      
      // Initialize controllers
      _titleController = TextEditingController(text: _sop.title);
      _descriptionController = TextEditingController(text: _sop.description);
      _departmentController = TextEditingController(text: _sop.department);
      
      setState(() {
        _isLoading = false;
        _isEditing = widget.sopId == 'new';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading SOP: $e')),
        );
        context.go('/');
      }
    }
  }
  
  Future<void> _saveSOP() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final sopService = Provider.of<SOPService>(context, listen: false);
        
        // Update SOP with form values
        final updatedSop = _sop.copyWith(
          title: _titleController.text,
          description: _descriptionController.text,
          department: _departmentController.text,
          updatedAt: DateTime.now(),
        );
        
        await sopService.updateSop(updatedSop);
        
        setState(() {
          _sop = updatedSop;
          _isLoading = false;
          _isEditing = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SOP saved successfully')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving SOP: $e')),
          );
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isLoading ? const Text('Loading...') : Text(_isEditing ? 'Edit SOP' : _sop.title),
        actions: [
          if (!_isLoading) // Only show these actions when not loading
            IconButton(
              icon: Icon(_isEditing ? Icons.save : Icons.edit),
              onPressed: () {
                if (_isEditing) {
                  _saveSOP();
                } else {
                  setState(() {
                    _isEditing = true;
                  });
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: _isLoading
                ? null
                : () {
                    // Show QR code dialog
                    _showQRCodeDialog(context);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _isLoading
                ? null
                : () {
                    // Print functionality
                  },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export_pdf') {
                // Export to PDF
              } else if (value == 'export_word') {
                // Export to Word
              } else if (value == 'delete') {
                _confirmDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_pdf',
                child: Text('Export as PDF'),
              ),
              const PopupMenuItem(
                value: 'export_word',
                child: Text('Export as Word'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete SOP'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildSOPEditor(),
    );
  }
  
  Widget _buildSOPEditor() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Toolbar for editing steps
          if (_isEditing)
            Container(
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Step'),
                    onPressed: () {
                      // Add new step
                      _showAddStepDialog();
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_box),
                    label: const Text('Add Tool'),
                    onPressed: () {
                      // Add tool
                      _showAddItemDialog('Tool', (item) {
                        setState(() {
                          final updatedTools = List<String>.from(_sop.tools)..add(item);
                          _sop = _sop.copyWith(tools: updatedTools);
                        });
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.security),
                    label: const Text('Add Safety Requirement'),
                    onPressed: () {
                      // Add safety requirement
                      _showAddItemDialog('Safety Requirement', (item) {
                        setState(() {
                          final updatedSafety = List<String>.from(_sop.safetyRequirements)..add(item);
                          _sop = _sop.copyWith(safetyRequirements: updatedSafety);
                        });
                      });
                    },
                  ),
                ],
              ),
            ),
          
          // SOP content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic information section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Basic Information',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          _isEditing
                              ? TextFormField(
                                  controller: _titleController,
                                  decoration: const InputDecoration(
                                    labelText: 'Title',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a title';
                                    }
                                    return null;
                                  },
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Title:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(_sop.title),
                                  ],
                                ),
                          const SizedBox(height: 16),
                          _isEditing
                              ? TextFormField(
                                  controller: _descriptionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Description',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 3,
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Description:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(_sop.description),
                                  ],
                                ),
                          const SizedBox(height: 16),
                          _isEditing
                              ? TextFormField(
                                  controller: _departmentController,
                                  decoration: const InputDecoration(
                                    labelText: 'Department',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a department';
                                    }
                                    return null;
                                  },
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Department:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(_sop.department),
                                  ],
                                ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Revision:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(_sop.revisionNumber.toString()),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Created By:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(_sop.createdBy),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Created:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(_formatDate(_sop.createdAt)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Last Updated:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(_formatDate(_sop.updatedAt)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Steps section
                  Text(
                    'Steps',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _sop.steps.isEmpty
                      ? const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'No steps added yet. Add steps to complete your SOP.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _sop.steps.length,
                          itemBuilder: (context, index) {
                            final step = _sop.steps[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Theme.of(context).colorScheme.primary,
                                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                          child: Text('${index + 1}'),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            step.title,
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                        if (_isEditing)
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () {
                                              // Remove step
                                              setState(() {
                                                final updatedSteps = List<SOPStep>.from(_sop.steps)
                                                  ..removeAt(index);
                                                _sop = _sop.copyWith(steps: updatedSteps);
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step.instruction,
                                          style: Theme.of(context).textTheme.bodyLarge,
                                        ),
                                        if (step.helpNote != null) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.info_outline, color: Colors.amber),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    step.helpNote!,
                                                    style: const TextStyle(
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (step.assignedTo != null || step.estimatedTime != null) ...[
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              if (step.assignedTo != null)
                                                Chip(
                                                  avatar: const Icon(Icons.person, size: 16),
                                                  label: Text(step.assignedTo!),
                                                ),
                                              const SizedBox(width: 8),
                                              if (step.estimatedTime != null)
                                                Chip(
                                                  avatar: const Icon(Icons.timer, size: 16),
                                                  label: Text('${step.estimatedTime} min'),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 24),
                  
                  // Tools section
                  Text(
                    'Tools and Equipment',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _sop.tools.isEmpty
                          ? const Center(
                              child: Text(
                                'No tools or equipment specified.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int i = 0; i < _sop.tools.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.build, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(_sop.tools[i])),
                                        if (_isEditing)
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 16),
                                            onPressed: () {
                                              setState(() {
                                                final updatedTools = List<String>.from(_sop.tools)
                                                  ..removeAt(i);
                                                _sop = _sop.copyWith(tools: updatedTools);
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Safety requirements section
                  Text(
                    'Safety Requirements',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _sop.safetyRequirements.isEmpty
                          ? const Center(
                              child: Text(
                                'No safety requirements specified.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int i = 0; i < _sop.safetyRequirements.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.security, size: 16, color: Colors.red),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(_sop.safetyRequirements[i])),
                                        if (_isEditing)
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 16),
                                            onPressed: () {
                                              setState(() {
                                                final updatedSafety = List<String>.from(_sop.safetyRequirements)
                                                  ..removeAt(i);
                                                _sop = _sop.copyWith(safetyRequirements: updatedSafety);
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Cautions section
                  Text(
                    'Cautions and Limitations',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _sop.cautions.isEmpty
                          ? const Center(
                              child: Text(
                                'No cautions or limitations specified.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int i = 0; i < _sop.cautions.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning, size: 16, color: Colors.orange),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(_sop.cautions[i])),
                                        if (_isEditing)
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 16),
                                            onPressed: () {
                                              setState(() {
                                                final updatedCautions = List<String>.from(_sop.cautions)
                                                  ..removeAt(i);
                                                _sop = _sop.copyWith(cautions: updatedCautions);
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showAddStepDialog() {
    final titleController = TextEditingController();
    final instructionController = TextEditingController();
    final helpNoteController = TextEditingController();
    final assignedToController = TextEditingController();
    final estimatedTimeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Step'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Step Title',
                  hintText: 'Enter a title for this step',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: instructionController,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  hintText: 'Enter detailed instructions for this step',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: helpNoteController,
                decoration: const InputDecoration(
                  labelText: 'Help Note (Optional)',
                  hintText: 'Enter any additional notes or tips',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: assignedToController,
                decoration: const InputDecoration(
                  labelText: 'Assigned To (Optional)',
                  hintText: 'Enter who should perform this step',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: estimatedTimeController,
                decoration: const InputDecoration(
                  labelText: 'Estimated Time (Minutes, Optional)',
                  hintText: 'Enter estimated time to complete',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && instructionController.text.isNotEmpty) {
                final newStep = SOPStep(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleController.text,
                  instruction: instructionController.text,
                  helpNote: helpNoteController.text.isNotEmpty ? helpNoteController.text : null,
                  assignedTo: assignedToController.text.isNotEmpty ? assignedToController.text : null,
                  estimatedTime: estimatedTimeController.text.isNotEmpty
                      ? int.tryParse(estimatedTimeController.text)
                      : null,
                );
                
                setState(() {
                  final updatedSteps = List<SOPStep>.from(_sop.steps)..add(newStep);
                  _sop = _sop.copyWith(steps: updatedSteps);
                });
                
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
  
  void _showAddItemDialog(String itemType, Function(String) onAdd) {
    final itemController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $itemType'),
        content: TextField(
          controller: itemController,
          decoration: InputDecoration(
            labelText: itemType,
            hintText: 'Enter $itemType',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (itemController.text.isNotEmpty) {
                onAdd(itemController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
  
  void _showQRCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SOP QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 200,
              height: 200,
              child: Placeholder(), // Replace with actual QR code
            ),
            const SizedBox(height: 16),
            Text(
              _sop.title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Download QR code
              Navigator.pop(context);
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
  
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete SOP'),
        content: const Text(
          'Are you sure you want to delete this SOP? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                final sopService = Provider.of<SOPService>(context, listen: false);
                await sopService.deleteSop(_sop.id);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SOP deleted successfully')),
                  );
                  context.go('/');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting SOP: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 