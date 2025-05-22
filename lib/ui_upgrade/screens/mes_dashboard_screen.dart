import 'package:flutter/material.dart';
import '../design_system/colors/app_colors.dart';
import '../design_system/typography/app_text_styles.dart';
import '../design_system/components/app_card.dart';
import '../design_system/components/app_button.dart';
import '../design_system/components/app_messages.dart';
import '../design_system/components/app_tooltip.dart';
import '../design_system/components/app_modal.dart';

/// MES Dashboard Screen displays key manufacturing metrics and status information.
class MESDashboardScreen extends StatefulWidget {
  const MESDashboardScreen({Key? key}) : super(key: key);

  @override
  State<MESDashboardScreen> createState() => _MESDashboardScreenState();
}

class _MESDashboardScreenState extends State<MESDashboardScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate loading data
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });
  }

  void _showMachineDetailsModal(
      BuildContext context, String machineId, String machineName) {
    AppModal.show(
      context: context,
      title: 'Machine Details: $machineName',
      headerIcon: Icons.precision_manufacturing,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Machine ID', machineId),
          _buildDetailRow('Status', 'Active'),
          _buildDetailRow('Uptime', '98.7%'),
          _buildDetailRow('Last Maintenance', '2023-05-15'),
          _buildDetailRow('Next Maintenance', '2023-08-15'),
          _buildDetailRow('Current Operator', 'John Smith'),
          _buildDetailRow('Current Job', 'WO-2023-0587'),
          const SizedBox(height: 16),
          const AppMessage(
            type: MessageType.info,
            title: 'Maintenance Reminder',
            message:
                'Scheduled maintenance is due in 30 days. Please plan accordingly.',
          ),
        ],
      ),
      actions: [
        AppButton(
          label: 'View History',
          variant: ButtonVariant.secondary,
          onPressed: () {},
        ),
        AppButton(
          label: 'Close',
          variant: ButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MES Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
            tooltip: 'Dashboard Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummarySection(),
                  const SizedBox(height: 24),
                  _buildMachineStatusSection(),
                  const SizedBox(height: 24),
                  _buildProductionMetricsSection(),
                  const SizedBox(height: 24),
                  _buildRecentWorkOrdersSection(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Production Summary',
              style: AppTextStyles.h2,
            ),
            const SizedBox(width: 8),
            InfoTooltip(
              message: 'Overview of today\'s production metrics',
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildSummaryCard(
              'Total Production',
              '1,250 units',
              Icons.inventory,
              AppColors.primary,
            ),
            _buildSummaryCard(
              'On-Time Delivery',
              '98.2%',
              Icons.access_time,
              AppColors.success,
            ),
            _buildSummaryCard(
              'Quality Rate',
              '99.5%',
              Icons.verified,
              AppColors.accent,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return AppCard(
      variant: CardVariant.elevated,
      padding: const EdgeInsets.all(16),
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 40,
            color: color,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.labelLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMachineStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Machine Status',
              style: AppTextStyles.h2,
            ),
            AppButton(
              label: 'View All',
              variant: ButtonVariant.tertiary,
              trailingIcon: Icons.arrow_forward,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildMachineStatusCard(
                  'M001', 'CNC Mill #1', AppColors.statusActive, 'Active'),
              _buildMachineStatusCard(
                  'M002', 'CNC Mill #2', AppColors.statusActive, 'Active'),
              _buildMachineStatusCard(
                  'M003', 'Lathe #1', AppColors.statusIdle, 'Idle'),
              _buildMachineStatusCard(
                  'M004', 'Assembly #1', AppColors.statusActive, 'Active'),
              _buildMachineStatusCard(
                  'M005', 'Packaging #1', AppColors.statusDown, 'Down'),
              _buildMachineStatusCard('M006', 'Inspection #1',
                  AppColors.statusMaintenance, 'Maintenance'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMachineStatusCard(
      String id, String name, Color statusColor, String status) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: AppCard(
        variant: CardVariant.flat,
        width: 200,
        padding: const EdgeInsets.all(16),
        onTap: () => _showMachineDetailsModal(context, id, name),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status,
                  style: AppTextStyles.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              id,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Production Metrics',
          style: AppTextStyles.h2,
        ),
        const SizedBox(height: 16),
        AppCard(
          variant: CardVariant.elevated,
          padding: const EdgeInsets.all(16),
          content: Column(
            children: [
              _buildMetricRow('Efficiency', 0.92),
              _buildMetricRow('Utilization', 0.87),
              _buildMetricRow('Throughput', 0.95),
              _buildMetricRow('Quality', 0.99),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTextStyles.labelLarge,
              ),
              Text(
                '${(value * 100).toStringAsFixed(1)}%',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: value,
            backgroundColor: AppColors.grey100,
            valueColor: AlwaysStoppedAnimation<Color>(_getColorForValue(value)),
          ),
        ],
      ),
    );
  }

  Color _getColorForValue(double value) {
    if (value >= 0.9) {
      return AppColors.success;
    } else if (value >= 0.7) {
      return AppColors.accent;
    } else {
      return AppColors.error;
    }
  }

  Widget _buildRecentWorkOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Work Orders',
              style: AppTextStyles.h2,
            ),
            AppButton(
              label: 'View All',
              variant: ButtonVariant.tertiary,
              trailingIcon: Icons.arrow_forward,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          variant: CardVariant.flat,
          padding: EdgeInsets.zero,
          content: Column(
            children: [
              _buildWorkOrderRow(
                'WO-2023-0587',
                'Cabinet Assembly',
                'In Progress',
                AppColors.info,
              ),
              const Divider(height: 1),
              _buildWorkOrderRow(
                'WO-2023-0586',
                'Table Legs (x4)',
                'Completed',
                AppColors.success,
              ),
              const Divider(height: 1),
              _buildWorkOrderRow(
                'WO-2023-0585',
                'Chair Frame',
                'Quality Check',
                AppColors.warning,
              ),
              const Divider(height: 1),
              _buildWorkOrderRow(
                'WO-2023-0584',
                'Bookshelf',
                'Delayed',
                AppColors.error,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkOrderRow(
      String id, String name, String status, Color statusColor) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Icon(
              Icons.chevron_right,
              color: AppColors.grey300,
            ),
          ],
        ),
      ),
    );
  }
}
