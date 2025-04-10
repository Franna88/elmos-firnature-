import 'package:flutter/material.dart';
import '../../data/models/sop_model.dart';
import 'dart:convert';

class SOPViewer extends StatefulWidget {
  final SOP sop;
  final bool showFullDetails;
  final VoidCallback? onPrint;

  const SOPViewer({
    super.key,
    required this.sop,
    this.showFullDetails = true,
    this.onPrint,
  });

  @override
  State<SOPViewer> createState() => _SOPViewerState();
}

class _SOPViewerState extends State<SOPViewer> {
  int _selectedStepIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // SOP Header
        _buildHeader(context),

        // Main content with side navigation
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left navigation bar for steps
              _buildStepNavigation(context),

              // Main content area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current step details
                      if (widget.sop.steps.isNotEmpty)
                        _buildCurrentStepCard(
                            context,
                            widget.sop.steps[_selectedStepIndex],
                            _selectedStepIndex)
                      else
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'No steps have been added to this SOP.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),

                      // Only show these sections if full details are requested
                      if (widget.showFullDetails) ...[
                        const SizedBox(height: 24),

                        // Tools section
                        if (widget.sop.tools.isNotEmpty)
                          _buildToolsSection(context),

                        const SizedBox(height: 24),

                        // Safety requirements section
                        if (widget.sop.safetyRequirements.isNotEmpty)
                          _buildSafetyRequirementsSection(context),

                        const SizedBox(height: 24),

                        // Cautions section
                        if (widget.sop.cautions.isNotEmpty)
                          _buildCautionsSection(context),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.sop.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Row(
                  children: [
                    // Added View Info button
                    TextButton.icon(
                      onPressed: () => _showSOPInfoDialog(context),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('View Info'),
                    ),
                    if (widget.onPrint != null)
                      IconButton(
                        onPressed: widget.onPrint,
                        icon: const Icon(Icons.print),
                        tooltip: 'Print SOP',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.sop.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  // New method to show SOP info in a dialog
  void _showSOPInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.sop.title} - Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Department', widget.sop.department, Icons.business),
            const SizedBox(height: 12),
            _buildInfoRow('Revision', widget.sop.revisionNumber.toString(),
                Icons.history),
            const SizedBox(height: 12),
            _buildInfoRow('Created', _formatDate(widget.sop.createdAt),
                Icons.calendar_today),
            const SizedBox(height: 12),
            _buildInfoRow('Last Updated', _formatDate(widget.sop.updatedAt),
                Icons.update),
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

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.blueGrey,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepNavigation(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Steps',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.sop.steps.length,
              itemBuilder: (context, index) {
                final step = widget.sop.steps[index];
                final isSelected = index == _selectedStepIndex;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 2.0),
                  child: Material(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedStepIndex = index;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              foregroundColor: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                              child: Text('${index + 1}'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                step.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepCard(BuildContext context, SOPStep step, int index) {
    return Card(
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
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ),
              ],
            ),
          ),
          // New modern table-like layout for the step content
          Padding(
            padding: const EdgeInsets.all(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column - Image (if available)
                  if (step.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 150,
                        child: _buildStepImage(step.imageUrl!, context),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],

                  // Middle column - Instructions and help notes
                  Expanded(
                    flex: 3,
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
                                const Icon(Icons.info_outline,
                                    color: Colors.amber),
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
                        if (step.assignedTo != null ||
                            step.estimatedTime != null) ...[
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

                  // Right column - Tools and hazards
                  if (step.stepTools.isNotEmpty ||
                      step.stepHazards.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    const VerticalDivider(),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Step Tools Section
                          if (step.stepTools.isNotEmpty) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.build,
                                    color: Colors.blue, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Tools Needed:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: step.stepTools
                                            .map((tool) => Chip(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  label: Text(tool,
                                                      style: const TextStyle(
                                                          fontSize: 12)),
                                                  backgroundColor:
                                                      Colors.blue.shade50,
                                                ))
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (step.stepHazards.isNotEmpty)
                              const SizedBox(height: 16),
                          ],

                          // Step Hazards Section
                          if (step.stepHazards.isNotEmpty) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning,
                                    color: Colors.orange, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Hazards:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: step.stepHazards
                                            .map((hazard) => Chip(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  label: Text(hazard,
                                                      style: const TextStyle(
                                                          fontSize: 12)),
                                                  backgroundColor:
                                                      Colors.orange.shade50,
                                                ))
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tools and Equipment',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < widget.sop.tools.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.build, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(widget.sop.tools[i])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyRequirementsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Safety Requirements',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < widget.sop.safetyRequirements.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.security, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text(widget.sop.safetyRequirements[i])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCautionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cautions and Limitations',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < widget.sop.cautions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.warning,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(child: Text(widget.sop.cautions[i])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(
      BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(value),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildStepImage(String imageUrl, BuildContext context) {
    // Check if this is a data URL
    if (imageUrl.startsWith('data:image/')) {
      try {
        final bytes = base64Decode(imageUrl.split(',')[1]);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          height: 180,
          errorBuilder: (context, error, stackTrace) => _buildImageError(),
        );
      } catch (e) {
        return _buildImageError();
      }
    }
    // Check if this is an asset image
    else if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        height: 180,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
      );
    }
    // Otherwise, assume it's a network image
    else {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        height: 180,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
      );
    }
  }

  Widget _buildImageError() {
    return SizedBox(
      height: 120,
      width: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 8),
            const Text(
              'Image could not be loaded',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
