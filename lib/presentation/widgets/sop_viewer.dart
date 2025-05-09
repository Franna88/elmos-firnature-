import 'package:flutter/material.dart';
import '../../data/models/sop_model.dart';
import 'dart:convert';
import '../../data/services/qr_code_service.dart';
import 'package:provider/provider.dart';
import '../../data/services/sop_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SOPViewer extends StatefulWidget {
  final SOP sop;
  final bool showFullDetails;
  final VoidCallback? onPrint;
  final VoidCallback? onDownloadQRCode;

  const SOPViewer({
    super.key,
    required this.sop,
    this.showFullDetails = true,
    this.onPrint,
    this.onDownloadQRCode,
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

                        // Custom sections
                        if (widget.sop.customSectionContent.isNotEmpty) ...[
                          for (final entry
                              in widget.sop.customSectionContent.entries)
                            if (entry.value.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              _buildCustomSection(
                                  context, entry.key, entry.value),
                            ],
                        ],
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
                    // Add Play Video button if SOP has a YouTube URL
                    if (widget.sop.youtubeUrl != null &&
                        widget.sop.youtubeUrl!.isNotEmpty)
                      TextButton.icon(
                        onPressed: _launchYoutubeVideo,
                        icon: const Icon(Icons.play_circle_fill,
                            color: Colors.red),
                        label: const Text(
                          'Play Video',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
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
                    if (widget.onDownloadQRCode != null)
                      IconButton(
                        onPressed: widget.onDownloadQRCode,
                        icon: const Icon(Icons.qr_code_2),
                        tooltip: 'Download QR Code',
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

  // Method to launch YouTube video URL
  Future<void> _launchYoutubeVideo() async {
    if (widget.sop.youtubeUrl != null && widget.sop.youtubeUrl!.isNotEmpty) {
      final Uri url = Uri.parse(widget.sop.youtubeUrl!);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        // Handle error
      }
    }
  }

  // New method to show SOP info in a dialog
  void _showSOPInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.sop.title} - Information'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Category', widget.sop.categoryName ?? 'Unknown',
                  Icons.business),
              const SizedBox(height: 12),
              _buildInfoRow('Revision', widget.sop.revisionNumber.toString(),
                  Icons.history),
              const SizedBox(height: 12),
              _buildInfoRow('Created', _formatDate(widget.sop.createdAt),
                  Icons.calendar_today),
              const SizedBox(height: 12),
              _buildInfoRow('Last Updated', _formatDate(widget.sop.updatedAt),
                  Icons.update),

              // Display YouTube video information if available
              if (widget.sop.youtubeUrl != null &&
                  widget.sop.youtubeUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.videocam, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    const Text(
                      'Video Tutorial Available',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (widget.sop.youtubeUrl != null &&
              widget.sop.youtubeUrl!.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _launchYoutubeVideo();
              },
              icon: const Icon(Icons.play_circle_outline, color: Colors.red),
              label: const Text(
                'Watch Video',
                style: TextStyle(color: Colors.red),
              ),
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
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 220,
                            child: _buildStepImage(step.imageUrl!, context),
                          ),
                        ),
                        Positioned(
                          top: 5,
                          right: 5,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.fullscreen,
                                  color: Colors.white, size: 20),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'View full image',
                              onPressed: () {
                                // Show full-size image dialog
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    insetPadding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AppBar(
                                          title: Text(step.title),
                                          leading: IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                          ),
                                        ),
                                        Flexible(
                                          child: InteractiveViewer(
                                            boundaryMargin:
                                                const EdgeInsets.all(20),
                                            minScale: 0.5,
                                            maxScale: 4,
                                            child: _buildFullScreenImage(
                                                step.imageUrl!, context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
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
          height: 250,
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
        height: 250,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
      );
    }
    // Otherwise, assume it's a network image
    else {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        height: 250,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
      );
    }
  }

  Widget _buildFullScreenImage(String imageUrl, BuildContext context) {
    // Check if this is a data URL
    if (imageUrl.startsWith('data:image/')) {
      try {
        final bytes = base64Decode(imageUrl.split(',')[1]);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
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
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
      );
    }
    // Otherwise, assume it's a network image
    else {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    }
  }

  Widget _buildImageError() {
    return SizedBox(
      height: 200,
      width: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Image could not be loaded',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // Build QR code section
  Widget _buildQRCodeSection(BuildContext context) {
    final sopService = Provider.of<SOPService>(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code, color: Color(0xFFBB2222)),
                    const SizedBox(width: 8),
                    Text('SOP QR Code',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  tooltip: 'Learn how to use this QR code',
                  onPressed: () {
                    // Show help information
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFBB2222)),
                            SizedBox(width: 8),
                            Text('Using SOP QR Codes'),
                          ],
                        ),
                        content: const SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QR codes enable quick access to SOPs on mobile devices:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('1.'),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Print this QR code and attach it to relevant equipment, workstations, or materials.',
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('2.'),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Team members can scan it with the Elmo\'s Furniture mobile app.',
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('3.'),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'The app immediately opens this specific SOP, showing all steps and details.',
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Benefits:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        'Instant access to procedures without searching'),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.check_circle, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        'Ensures team members follow correct procedures'),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.update, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        'Always shows the latest version of the SOP'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Scan this QR code with the Elmo\'s Furniture mobile app to instantly access this SOP on a mobile device.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  // Display QR code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: sopService.qrCodeService
                        .generateQRWidget(widget.sop.id, size: 200),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SOP ID: ${widget.sop.id}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add a new method to build custom sections
  Widget _buildCustomSection(
      BuildContext context, String sectionName, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.article,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(items[i])),
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
}
