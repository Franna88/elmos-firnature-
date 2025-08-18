import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/services/production_timer_service.dart';
import '../../data/models/production_item_model.dart';
import '../../core/theme/app_theme.dart';
import 'item_selection_dialog.dart';

/// Widget that displays the production timer interface
class ProductionTimerWidget extends StatefulWidget {
  const ProductionTimerWidget({super.key});

  @override
  State<ProductionTimerWidget> createState() => _ProductionTimerWidgetState();
}

class _ProductionTimerWidgetState extends State<ProductionTimerWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ProductionTimerService>(
      builder: (context, timerService, child) {
        final size = MediaQuery.of(context).size;
        final isTablet = size.width > 600;

        return Container(
          padding: EdgeInsets.all(isTablet ? 16.0 : 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selected item display
              _buildSelectedItemDisplay(timerService, isTablet),

              const SizedBox(height: 12),

              // Timer display
              _buildTimerDisplay(timerService, isTablet),

              const SizedBox(height: 12),

              // Action buttons
              _buildActionButtons(timerService, isTablet),

              // Next button (only visible during Production)
              if (timerService.canShowNextButton) ...[
                const SizedBox(height: 8),
                _buildNextButton(timerService, isTablet),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectedItemDisplay(
      ProductionTimerService timerService, bool isTablet) {
    if (!timerService.hasSelectedItem) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Select an item to start production',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: isTablet ? 14 : 12,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => _showItemSelectionDialog(timerService),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('Select Item'),
            ),
          ],
        ),
      );
    }

    final item = timerService.selectedItem!;
    final session = timerService.currentSession;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: isTablet ? 48 : 40,
            height: isTablet ? 48 : 40,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.inventory_2,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 16 : 14,
                    color: AppColors.primaryBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Cycle: ${session?.cycleCount ?? 0} | Per Cycle: ${item.qtyPerCycle} | Finished: ${item.finishedQty}',
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showItemSelectionDialog(timerService),
            icon: const Icon(Icons.edit, color: AppColors.primaryBlue),
            iconSize: isTablet ? 20 : 18,
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay(
      ProductionTimerService timerService, bool isTablet) {
    final currentAction = timerService.currentActiveAction;
    final duration = timerService.getCurrentActionDuration();
    final durationText = ProductionTimerService.formatDuration(duration);

    Color actionColor = Colors.grey[600]!;
    String actionText = 'No Active Action';

    if (currentAction != null) {
      actionText = currentAction.displayName;
      actionColor = _getActionColor(currentAction);
    }

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: actionColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: actionColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            actionText,
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: actionColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            durationText,
            style: TextStyle(
              fontSize: isTablet ? 32 : 28,
              fontWeight: FontWeight.bold,
              color: actionColor,
              fontFamily: 'monospace',
            ),
          ),
          if (timerService.hasActiveSession) ...[
            const SizedBox(height: 4),
            Text(
              'Session: ${ProductionTimerService.formatDuration(timerService.getTotalSessionTime())}',
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      ProductionTimerService timerService, bool isTablet) {
    if (!timerService.canStartActions) {
      return const SizedBox.shrink();
    }

    final actions = TimerActionType.values;
    final currentAction = timerService.currentActiveAction;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions.map((action) {
        final isActive = currentAction == action;
        final canStart = _canStartAction(action, timerService);

        return SizedBox(
          width: isTablet ? 140 : 110,
          child: ElevatedButton(
            onPressed:
                canStart ? () => _handleActionTap(action, timerService) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isActive ? _getActionColor(action) : Colors.white,
              foregroundColor:
                  isActive ? Colors.white : _getActionColor(action),
              side: BorderSide(color: _getActionColor(action)),
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 12 : 8,
                vertical: isTablet ? 10 : 8,
              ),
              elevation: isActive ? 4 : 1,
            ),
            child: Text(
              action.displayName,
              style: TextStyle(
                fontSize: isTablet ? 13 : 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNextButton(ProductionTimerService timerService, bool isTablet) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _handleNextButton(timerService),
        icon: const Icon(Icons.skip_next),
        label: Text(
          'NEXT (+${timerService.selectedItem?.qtyPerCycle ?? 1})',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 14 : 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Color _getActionColor(TimerActionType action) {
    switch (action) {
      case TimerActionType.setup:
        return Colors.blue;
      case TimerActionType.production:
        return Colors.green;
      case TimerActionType.jobComplete:
        return Colors.orange;
      case TimerActionType.counting:
        return Colors.purple;
      case TimerActionType.shutdown:
        return Colors.red;
    }
  }

  bool _canStartAction(
      TimerActionType action, ProductionTimerService timerService) {
    // Can't start actions without an item
    if (!timerService.canStartActions) return false;

    // Can't start the same action that's already active
    if (timerService.currentActiveAction == action) return false;

    return true;
  }

  Future<void> _handleActionTap(
      TimerActionType action, ProductionTimerService timerService) async {
    try {
      // ALL actions switch immediately - NO POPUPS!
      switch (action) {
        case TimerActionType.jobComplete:
          await timerService
              .completeJob(); // This now switches to counting immediately
          break;
        case TimerActionType.shutdown:
          await timerService
              .shutdown(); // This now switches to shutdown immediately
          break;
        default:
          await timerService.startAction(action);
      }

      // Show brief feedback only
      _showSuccessSnackBar('Switched to ${action.displayName}');
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  // These methods are no longer needed - all actions switch immediately
  // Removed _handleJobComplete and _handleShutdown

  Future<void> _handleNextButton(ProductionTimerService timerService) async {
    try {
      await timerService.incrementCycle();
      _showSuccessSnackBar('Cycle incremented');
    } catch (e) {
      _showErrorSnackBar('Error incrementing cycle: $e');
    }
  }

  Future<void> _showItemSelectionDialog(
      ProductionTimerService timerService) async {
    // Only show dialog for initial item selection
    final availableItems = await timerService.loadAvailableItems();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ItemSelectionDialog(
        availableItems: availableItems,
        selectedItem: timerService.selectedItem,
        isFromJobComplete: false, // Never use the counting mode anymore
        onItemSelected: (item, qtyPerCycle, finishedQty, targetQty) async {
          try {
            // Create updated item with new quantities
            final updatedItem = item.copyWith(
              qtyPerCycle: qtyPerCycle,
              finishedQty: finishedQty,
              targetQty: targetQty,
            );

            // Select the item - this will automatically start Setup action
            await timerService.selectItem(updatedItem);
            _showSuccessSnackBar(
                'Item selected: ${item.name} - Setup started automatically');
          } catch (e) {
            _showErrorSnackBar('Error selecting item: $e');
          }
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }

  // Removed _showFinishedQtyDialog - no longer needed since actions switch immediately

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
