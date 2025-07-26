import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/services/mes_service.dart';
import '../../data/models/mes_production_record_model.dart';
import '../../data/models/mes_item_model.dart';
import '../widgets/app_scaffold.dart';
import '../../core/theme/app_theme.dart';

class MESReportsScreen extends StatefulWidget {
  const MESReportsScreen({super.key});

  @override
  State<MESReportsScreen> createState() => _MESReportsScreenState();
}

class _MESReportsScreenState extends State<MESReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedUserId = 'All';
  String _selectedItemId = 'All';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final mesService = Provider.of<MESService>(context, listen: false);

      // Load items and production records
      await Future.wait([
        mesService.fetchItems(),
        mesService.fetchProductionRecords(
          userId: _selectedUserId == 'All' ? null : _selectedUserId,
          itemId: _selectedItemId == 'All' ? null : _selectedItemId,
          startDate: _startDate,
          endDate: _endDate,
        ),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
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
    return AppScaffold(
      title: 'MES Production Reports',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
        IconButton(
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filters',
          onPressed: _showFiltersDialog,
        ),
      ],
      body: Column(
        children: [
          // Search bar matching SOP design
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search production records...',
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

          // Tab bar
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryBlue,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: AppColors.primaryBlue,
              tabs: const [
                Tab(icon: Icon(Icons.list), text: 'Records'),
                Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
                Tab(icon: Icon(Icons.timeline), text: 'Actions'),
                Tab(icon: Icon(Icons.people), text: 'Workers'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecordsTab(),
                _buildAnalyticsTab(),
                _buildActionsTab(),
                _buildWorkersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsTab() {
    return Consumer<MESService>(
      builder: (context, mesService, child) {
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final allRecords = mesService.productionRecords;
        final filteredRecords = _filterRecords(allRecords);

        if (filteredRecords.isEmpty) {
          return _buildEmptyState(
            Icons.inbox,
            'No Records Found',
            'No production records match your criteria.',
          );
        }

        return Column(
          children: [
            // Date filter bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 20, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  const Text(
                    'Filter by Date:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectStartDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_month,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('MMM dd, yyyy')
                                        .format(_startDate),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child:
                              Text('to', style: TextStyle(color: Colors.grey)),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: _selectEndDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_month,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(_endDate),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Apply'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

            // Records list
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredRecords.length,
                  itemBuilder: (context, index) {
                    final record = filteredRecords[index];
                    final item = _getItemForRecord(mesService, record);
                    return _buildRecordListItem(record, item);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Widget _buildRecordListItem(MESProductionRecord record, MESItem item) {
    final startTime = DateFormat('HH:mm').format(record.startTime);
    final endTime = record.endTime != null
        ? DateFormat('HH:mm').format(record.endTime!)
        : 'In Progress';
    final date = DateFormat('MMM dd, yyyy').format(record.startTime);

    final productionTime = Duration(seconds: record.totalProductionTimeSeconds);
    final interruptionTime =
        Duration(seconds: record.totalInterruptionTimeSeconds);
    final totalTime = productionTime + interruptionTime;

    final efficiency = totalTime.inSeconds > 0
        ? (productionTime.inSeconds / totalTime.inSeconds * 100)
        : 0.0;

    Color statusColor =
        record.isCompleted ? AppColors.greenAccent : AppColors.primaryBlue;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showRecordDetails(record, item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(width: 16),

              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            record.isCompleted ? 'Complete' : 'In Progress',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Worker and time info
                    Row(
                      children: [
                        Icon(Icons.person, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          record.userName,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '$startTime - $endTime',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          date,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Metrics row
                    Row(
                      children: [
                        _buildQuickMetric(
                            'Production',
                            _formatDuration(productionTime),
                            AppColors.greenAccent),
                        const SizedBox(width: 12),
                        _buildQuickMetric(
                            'Actions',
                            _formatDuration(interruptionTime),
                            AppColors.orangeAccent),
                        const SizedBox(width: 12),
                        _buildQuickMetric(
                            'Items',
                            '${record.itemCompletionRecords.length}',
                            AppColors.primaryBlue),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: efficiency >= 80
                                ? AppColors.greenAccent.withOpacity(0.1)
                                : AppColors.orangeAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${efficiency.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: efficiency >= 80
                                  ? AppColors.greenAccent
                                  : AppColors.orangeAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow indicator
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordCard(MESProductionRecord record, MESItem item) {
    final startTime = DateFormat('MMM dd, HH:mm').format(record.startTime);
    final duration = record.endTime != null
        ? record.endTime!.difference(record.startTime)
        : DateTime.now().difference(record.startTime);

    final productionTime = Duration(seconds: record.totalProductionTimeSeconds);
    final interruptionTime =
        Duration(seconds: record.totalInterruptionTimeSeconds);

    // Determine status color
    Color statusColor =
        record.isCompleted ? AppColors.greenAccent : AppColors.primaryBlue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showRecordDetails(record, item),
        child: Column(
          children: [
            // Header with status color
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    record.isCompleted ? Icons.check_circle : Icons.pending,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      record.isCompleted ? 'Complete' : 'In Progress',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Basic info row
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        record.userName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        startTime,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Time metrics
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeMetric(
                          'Production',
                          _formatDuration(productionTime),
                          AppColors.greenAccent,
                          Icons.trending_up,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimeMetric(
                          'Actions',
                          _formatDuration(interruptionTime),
                          AppColors.orangeAccent,
                          Icons.pause_circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimeMetric(
                          'Items',
                          '${record.itemCompletionRecords.length}',
                          AppColors.primaryBlue,
                          Icons.inventory,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeMetric(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return Consumer<MESService>(
      builder: (context, mesService, child) {
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = _filterRecords(mesService.productionRecords);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAnalyticsSummary(records),
              const SizedBox(height: 24),
              _buildProductivityChart(records),
              const SizedBox(height: 24),
              _buildItemAnalysis(records, mesService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionsTab() {
    return Consumer<MESService>(
      builder: (context, mesService, child) {
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = _filterRecords(mesService.productionRecords);
        final allInterruptions = <MESInterruption>[];

        for (final record in records) {
          allInterruptions.addAll(record.interruptions);
        }

        if (allInterruptions.isEmpty) {
          return _buildEmptyState(
            Icons.timeline,
            'No Actions Recorded',
            'No worker actions have been recorded yet.',
          );
        }

        // Group by action type
        final actionGroups = <String, List<MESInterruption>>{};
        for (final interruption in allInterruptions) {
          actionGroups
              .putIfAbsent(interruption.typeName, () => [])
              .add(interruption);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: actionGroups.length,
          itemBuilder: (context, index) {
            final actionName = actionGroups.keys.elementAt(index);
            final actions = actionGroups[actionName]!;
            return _buildActionGroupCard(actionName, actions);
          },
        );
      },
    );
  }

  Widget _buildActionGroupCard(
      String actionName, List<MESInterruption> actions) {
    final totalDuration =
        actions.fold(0, (sum, action) => sum + action.durationSeconds);
    final averageDuration = totalDuration / actions.length;

    // Determine color based on action type
    Color actionColor = _getActionColor(actionName);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: actionColor.withOpacity(0.3)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: actionColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getActionIcon(actionName), color: actionColor, size: 20),
        ),
        title: Text(
          actionName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
            '${actions.length} occurrences • ${_formatSeconds(totalDuration)} total'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildActionMetric(
                        'Total Time',
                        _formatSeconds(totalDuration),
                        actionColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionMetric(
                        'Average',
                        _formatSeconds(averageDuration.round()),
                        actionColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionMetric(
                        'Count',
                        '${actions.length}',
                        actionColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...actions
                    .take(5)
                    .map((action) => _buildActionInstance(action)),
                if (actions.length > 5)
                  TextButton(
                    onPressed: () => _showAllActions(actionName, actions),
                    child: Text('View all ${actions.length} instances'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionInstance(MESInterruption action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getActionColor(action.typeName),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            DateFormat('MMM dd, HH:mm').format(action.startTime),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const Spacer(),
          Text(
            _formatSeconds(action.durationSeconds),
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkersTab() {
    return Consumer<MESService>(
      builder: (context, mesService, child) {
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = _filterRecords(mesService.productionRecords);
        final workerStats = _calculateWorkerStats(records);

        if (workerStats.isEmpty) {
          return _buildEmptyState(
            Icons.people,
            'No Worker Data',
            'No worker statistics available for the selected period.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: workerStats.length,
          itemBuilder: (context, index) {
            final workerName = workerStats.keys.elementAt(index);
            final stats = workerStats[workerName]!;
            return _buildWorkerCard(workerName, stats);
          },
        );
      },
    );
  }

  Widget _buildWorkerCard(String workerName, Map<String, dynamic> stats) {
    final itemsCompleted = stats['itemsCompleted'] as int;
    final productionTime = Duration(seconds: stats['productionTime'] as int);
    final actionTime = Duration(seconds: stats['actionTime'] as int);
    final efficiency = stats['efficiency'] as double;

    Color efficiencyColor = efficiency >= 80
        ? AppColors.greenAccent
        : efficiency >= 60
            ? AppColors.orangeAccent
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                  child: Text(
                    workerName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$itemsCompleted items completed',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: efficiencyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: efficiencyColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${efficiency.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: efficiencyColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTimeMetric(
                    'Production',
                    _formatDuration(productionTime),
                    AppColors.greenAccent,
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeMetric(
                    'Actions',
                    _formatDuration(actionTime),
                    AppColors.orangeAccent,
                    Icons.pause_circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods

  List<MESProductionRecord> _filterRecords(List<MESProductionRecord> records) {
    final filteredRecords = records.where((record) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!record.userName.toLowerCase().contains(query) &&
            !_getItemForRecord(
                    Provider.of<MESService>(context, listen: false), record)
                .name
                .toLowerCase()
                .contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sort by start time - newest first (most recent at the top)
    filteredRecords.sort((a, b) => b.startTime.compareTo(a.startTime));

    return filteredRecords;
  }

  MESItem _getItemForRecord(MESService mesService, MESProductionRecord record) {
    return mesService.items.firstWhere(
      (item) => item.id == record.itemId,
      orElse: () => MESItem(
        id: 'unknown',
        name: 'Unknown Item',
        processId: 'unknown',
        estimatedTimeInMinutes: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatSeconds(int seconds) {
    final duration = Duration(seconds: seconds);
    return _formatDuration(duration);
  }

  Color _getActionColor(String actionName) {
    final name = actionName.toLowerCase();
    if (name.contains('break')) return const Color(0xFF795548);
    if (name.contains('maintenance')) return const Color(0xFFFF9800);
    if (name.contains('prep')) return const Color(0xFF2196F3);
    if (name.contains('material')) return const Color(0xFF4CAF50);
    if (name.contains('training')) return const Color(0xFF9C27B0);
    return Colors.grey[600]!;
  }

  IconData _getActionIcon(String actionName) {
    final name = actionName.toLowerCase();
    if (name.contains('break')) return Icons.coffee;
    if (name.contains('maintenance')) return Icons.build;
    if (name.contains('prep')) return Icons.assignment;
    if (name.contains('material')) return Icons.inventory;
    if (name.contains('training')) return Icons.school;
    return Icons.pause_circle;
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSummary(List<MESProductionRecord> records) {
    final totalItems = records.fold(
        0, (sum, record) => sum + record.itemCompletionRecords.length);
    final totalProductionTime = records.fold(
        0, (sum, record) => sum + record.totalProductionTimeSeconds);
    final totalActionTime = records.fold(
        0, (sum, record) => sum + record.totalInterruptionTimeSeconds);
    final totalTime = totalProductionTime + totalActionTime;
    final efficiency =
        totalTime > 0 ? (totalProductionTime / totalTime * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Summary',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Items Produced',
                '$totalItems',
                Icons.inventory,
                AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Efficiency',
                '${efficiency.toStringAsFixed(1)}%',
                Icons.trending_up,
                efficiency >= 80
                    ? AppColors.greenAccent
                    : AppColors.orangeAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Production Time',
                _formatSeconds(totalProductionTime),
                Icons.schedule,
                AppColors.greenAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Action Time',
                _formatSeconds(totalActionTime),
                Icons.pause_circle,
                AppColors.orangeAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductivityChart(List<MESProductionRecord> records) {
    // For now, show a placeholder - can be enhanced with actual charts
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Productivity Chart',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            Text(
              'Chart visualization coming soon',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemAnalysis(
      List<MESProductionRecord> records, MESService mesService) {
    final itemStats = <String, Map<String, int>>{};

    for (final record in records) {
      final item = _getItemForRecord(mesService, record);
      if (!itemStats.containsKey(item.name)) {
        itemStats[item.name] = {'count': 0, 'time': 0};
      }
      itemStats[item.name]!['count'] =
          itemStats[item.name]!['count']! + record.itemCompletionRecords.length;
      itemStats[item.name]!['time'] =
          itemStats[item.name]!['time']! + record.totalProductionTimeSeconds;
    }

    final sortedItems = itemStats.entries.toList()
      ..sort((a, b) => b.value['count']!.compareTo(a.value['count']!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Items',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...sortedItems.take(5).map((entry) {
          final itemName = entry.key;
          final count = entry.value['count']!;
          final time = entry.value['time']!;
          final avgTime = count > 0 ? time ~/ count : 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(itemName),
              subtitle: Text('Avg: ${_formatSeconds(avgTime)} per item'),
              trailing: Text(
                _formatSeconds(time),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
      ],
    );
  }

  Map<String, Map<String, dynamic>> _calculateWorkerStats(
      List<MESProductionRecord> records) {
    final workerStats = <String, Map<String, dynamic>>{};

    for (final record in records) {
      if (!workerStats.containsKey(record.userName)) {
        workerStats[record.userName] = {
          'itemsCompleted': 0,
          'productionTime': 0,
          'actionTime': 0,
          'efficiency': 0.0,
        };
      }

      final stats = workerStats[record.userName]!;
      stats['itemsCompleted'] += record.itemCompletionRecords.length;
      stats['productionTime'] += record.totalProductionTimeSeconds;
      stats['actionTime'] += record.totalInterruptionTimeSeconds;

      final totalTime = stats['productionTime'] + stats['actionTime'];
      stats['efficiency'] =
          totalTime > 0 ? (stats['productionTime'] / totalTime * 100) : 0.0;
    }

    return workerStats;
  }

  void _showFiltersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Reports'),
        content: const Text('Filters dialog coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRecordDetails(MESProductionRecord record, MESItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Production Details',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Item', item.name),
                      _buildDetailRow('Worker', record.userName),
                      _buildDetailRow(
                          'Start Time',
                          DateFormat('yyyy-MM-dd HH:mm')
                              .format(record.startTime)),
                      if (record.endTime != null)
                        _buildDetailRow(
                            'End Time',
                            DateFormat('yyyy-MM-dd HH:mm')
                                .format(record.endTime!)),
                      _buildDetailRow('Status',
                          record.isCompleted ? 'Completed' : 'In Progress'),
                      const SizedBox(height: 24),
                      const Text(
                        'Time Breakdown',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Production Time',
                          _formatSeconds(record.totalProductionTimeSeconds)),
                      _buildDetailRow('Action Time',
                          _formatSeconds(record.totalInterruptionTimeSeconds)),
                      _buildDetailRow('Items Completed',
                          '${record.itemCompletionRecords.length}'),
                      if (record.interruptions.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Actions Taken',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ...record.interruptions.map((action) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _getActionColor(action.typeName),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(action.typeName)),
                                  Text(_formatSeconds(action.durationSeconds)),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showAllActions(String actionName, List<MESInterruption> actions) {
    // Implementation for showing all action instances
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('All $actionName Actions'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: ListView.builder(
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return ListTile(
                title: Text(
                    DateFormat('MMM dd, yyyy HH:mm').format(action.startTime)),
                subtitle:
                    Text('Duration: ${_formatSeconds(action.durationSeconds)}'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
