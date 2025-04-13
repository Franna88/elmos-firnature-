import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../../data/services/sop_service.dart';
import '../../../data/models/sop_model.dart';

class MobileSOPViewerScreen extends StatefulWidget {
  final String sopId;

  const MobileSOPViewerScreen({super.key, required this.sopId});

  @override
  State<MobileSOPViewerScreen> createState() => _MobileSOPViewerScreenState();
}

class _MobileSOPViewerScreenState extends State<MobileSOPViewerScreen> {
  late SOP _sop;
  bool _isLoading = true;
  int _currentStepIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadSOP();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSOP() async {
    setState(() {
      _isLoading = true;
    });

    final sopService = Provider.of<SOPService>(context, listen: false);

    try {
      final sop = await sopService.getSopById(widget.sopId);
      if (sop != null) {
        setState(() {
          _sop = sop;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SOP not found')),
          );
          context.go('/mobile/sops');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading SOP: $e')),
        );
        context.go('/mobile/sops');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/mobile/sops'),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_sop.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mobile/sops'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showSOPInfoDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentStepIndex + 1) / _sop.steps.length,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary),
          ),

          // Step counter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Step ${_currentStepIndex + 1} of ${_sop.steps.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _sop.steps.length,
              onPageChanged: (index) {
                setState(() {
                  _currentStepIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final step = _sop.steps[index];
                return _buildStepCard(step, index + 1);
              },
            ),
          ),

          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentStepIndex > 0
                      ? () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                    disabledBackgroundColor: Colors.grey[200],
                    disabledForegroundColor: Colors.grey[400],
                  ),
                ),
                _currentStepIndex == _sop.steps.length - 1
                    ? ElevatedButton.icon(
                        onPressed: () {
                          // Show completion message and return to SOPs screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('SOP completed successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          context.go('/mobile/sops');
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _currentStepIndex < _sop.steps.length - 1
                            ? () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[200],
                          disabledForegroundColor: Colors.grey[400],
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(SOPStep step, int stepNumber) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$stepNumber",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Step image
          if (step.imageUrl != null && step.imageUrl!.isNotEmpty)
            Container(
              width: double.infinity,
              height: 200,
              margin: const EdgeInsets.only(bottom: 16),
              child: _buildImage(step.imageUrl!),
            ),

          // Step instruction
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              step.instruction,
              style: const TextStyle(fontSize: 16),
            ),
          ),

          const SizedBox(height: 16),

          // Help note (if any)
          if (step.helpNote != null && step.helpNote!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.helpNote!,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Tools and Hazards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (step.stepTools.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Tools",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: step.stepTools.map((tool) {
                          return Chip(
                            label: Text(tool),
                            backgroundColor: Colors.blue[50],
                            side: BorderSide(color: Colors.blue[200]!),
                            labelStyle: TextStyle(color: Colors.blue[800]),
                            padding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              if (step.stepTools.isNotEmpty && step.stepHazards.isNotEmpty)
                const SizedBox(width: 16),
              if (step.stepHazards.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Hazards",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: step.stepHazards.map((hazard) {
                          return Chip(
                            label: Text(hazard),
                            backgroundColor: Colors.red[50],
                            side: BorderSide(color: Colors.red[200]!),
                            labelStyle: TextStyle(color: Colors.red[800]),
                            padding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if ((step.assignedTo != null && step.assignedTo!.isNotEmpty) ||
              step.estimatedTime != null) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (step.assignedTo != null && step.assignedTo!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Assigned: ${step.assignedTo}",
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                if (step.estimatedTime != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.timer,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${step.estimatedTime} min",
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    // Check if this is a data URL
    if (imageUrl.startsWith('data:image/')) {
      try {
        final data = imageUrl.split(',')[1];
        final bytes = base64Decode(data);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildImageError(),
          ),
        );
      } catch (e) {
        debugPrint('Error displaying data URL image: $e');
        return _buildImageError();
      }
    }
    // Check if this is an asset image
    else if (imageUrl.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildImageError(),
        ),
      );
    }
    // Otherwise, assume it's a network image
    else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildImageError(),
        ),
      );
    }
  }

  Widget _buildImageError() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'Image could not be loaded',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showSOPInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SOP Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Title', _sop.title),
              _buildInfoRow('Description', _sop.description),
              _buildInfoRow('Category', _sop.categoryName ?? 'Uncategorized'),
              _buildInfoRow('Revision', _sop.revisionNumber.toString()),
              _buildInfoRow('Created By', _sop.createdBy),
              _buildInfoRow('Created', _formatDate(_sop.createdAt)),
              _buildInfoRow('Last Updated', _formatDate(_sop.updatedAt)),
              const Divider(),
              const Text(
                'Required Tools:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _sop.tools.map((tool) {
                  return Chip(
                    label: Text(tool),
                    backgroundColor: Colors.blue[50],
                    labelStyle:
                        TextStyle(fontSize: 12, color: Colors.blue[800]),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Text(
                'Safety Requirements:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _sop.safetyRequirements.map((safety) {
                  return Chip(
                    label: Text(safety),
                    backgroundColor: Colors.red[50],
                    labelStyle: TextStyle(fontSize: 12, color: Colors.red[800]),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cautions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _sop.cautions.map((caution) {
                  return Chip(
                    label: Text(caution),
                    backgroundColor: Colors.amber[50],
                    labelStyle:
                        TextStyle(fontSize: 12, color: Colors.amber[800]),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
