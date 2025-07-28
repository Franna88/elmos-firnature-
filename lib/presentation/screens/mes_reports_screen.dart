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
    _tabController = TabController(length: 5, vsync: this);
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
                Tab(icon: Icon(Icons.analytics), text: 'Analyze'),
                Tab(icon: Icon(Icons.inventory), text: 'Items'),
                Tab(icon: Icon(Icons.timeline), text: 'Actions'),
                Tab(icon: Icon(Icons.people), text: 'Workers'),
                Tab(icon: Icon(Icons.factory), text: 'Factory'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAnalyticsTab(),
                _buildItemsTab(), // Renamed from Records
                _buildActionsTab(),
                _buildWorkersTab(),
                _buildFactoryTab(), // New tab
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTab() {
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
    if (records.isEmpty) {
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
                'No Production Data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(
                'Start production to see productivity metrics',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate daily average time per item data
    final dailyAverageTimeData = _calculateDailyAverageTimePerItem(records);
    final itemProductivity = _calculateItemProductivity(records);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Productivity Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Daily Average Time Per Item
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Daily Average Time Per Item',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Month: ${DateTime.now().month}/${DateTime.now().year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _buildDailyAverageTimeChart(dailyAverageTimeData),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Item Production Efficiency
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed, color: Colors.green[600], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Item Production Efficiency',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _buildItemEfficiencyChart(itemProductivity),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Productivity Metrics Summary
        _buildProductivityMetrics(records, itemProductivity),
      ],
    );
  }

  Map<int, Map<String, dynamic>> _calculateDailyAverageTimePerItem(
      List<MESProductionRecord> records) {
    final dailyData = <int, Map<String, dynamic>>{};
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    // Filter records for current month only
    final monthlyRecords = records.where((record) {
      return record.startTime.isAfter(currentMonth) &&
          record.startTime.isBefore(nextMonth);
    }).toList();

    // Group records by day of month
    for (final record in monthlyRecords) {
      final dayOfMonth = record.startTime.day;

      if (!dailyData.containsKey(dayOfMonth)) {
        dailyData[dayOfMonth] = {
          'totalCompleted': 0,
          'totalTime': 0,
          'averageTimePerItem': 0.0,
        };
      }

      // Add completed items and their time
      final completedItemsCount = record.itemCompletionRecords.length;
      dailyData[dayOfMonth]!['totalCompleted'] =
          (dailyData[dayOfMonth]!['totalCompleted'] as int) +
              completedItemsCount;

      // Calculate total time for completed items
      int totalItemTime = 0;
      for (final itemRecord in record.itemCompletionRecords) {
        totalItemTime += itemRecord.durationSeconds;
      }

      dailyData[dayOfMonth]!['totalTime'] =
          (dailyData[dayOfMonth]!['totalTime'] as int) + totalItemTime;
    }

    // Calculate average time per item for each day
    for (final entry in dailyData.entries) {
      final totalCompleted = entry.value['totalCompleted'] as int;
      final totalTime = entry.value['totalTime'] as int;

      if (totalCompleted > 0) {
        entry.value['averageTimePerItem'] = totalTime / totalCompleted;
      }
    }

    return dailyData;
  }

  Map<String, Map<String, dynamic>> _calculateItemProductivity(
      List<MESProductionRecord> records) {
    final itemData = <String, Map<String, dynamic>>{};

    for (final record in records) {
      // Get item name - you may need to adjust this based on your item retrieval logic
      final itemName =
          record.itemId; // Simplified - replace with actual item name lookup

      if (!itemData.containsKey(itemName)) {
        itemData[itemName] = {
          'totalCompleted': 0,
          'totalTime': 0,
          'avgTimePerItem': 0.0,
          'efficiency': 0.0,
        };
      }

      itemData[itemName]!['totalCompleted'] =
          (itemData[itemName]!['totalCompleted'] as int) +
              record.itemCompletionRecords.length;
      itemData[itemName]!['totalTime'] =
          (itemData[itemName]!['totalTime'] as int) +
              record.totalProductionTimeSeconds;
    }

    // Calculate averages and efficiency
    for (final entry in itemData.entries) {
      final totalCompleted = entry.value['totalCompleted'] as int;
      final totalTime = entry.value['totalTime'] as int;

      if (totalCompleted > 0) {
        entry.value['avgTimePerItem'] = totalTime / totalCompleted;
        entry.value['efficiency'] =
            totalCompleted / (totalTime / 3600); // items per hour
      }
    }

    return itemData;
  }

  Widget _buildDailyAverageTimeChart(Map<int, Map<String, dynamic>> dailyData) {
    if (dailyData.isEmpty) {
      return const Center(
        child: Text('No daily production data available'),
      );
    }

    // Sort days by day number
    final sortedEntries = dailyData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Find max average time for scaling
    final maxAverageTime = sortedEntries.isEmpty
        ? 0.0
        : sortedEntries
            .map((e) => e.value['averageTimePerItem'] as double)
            .reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        // Chart
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: sortedEntries.map((entry) {
              final dayOfMonth = entry.key;
              final averageTime = entry.value['averageTimePerItem'] as double;
              final totalCompleted = entry.value['totalCompleted'] as int;
              final barHeight = maxAverageTime > 0
                  ? (averageTime / maxAverageTime) * 140
                  : 0.0;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Average time label
                      Text(
                        _formatSeconds(averageTime.round()),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Bar
                      Container(
                        width: double.infinity,
                        height: barHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.blue[400]!,
                              Colors.blue[600]!,
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Day of month label
                      Text(
                        dayOfMonth.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // Items count label
                      Text(
                        '$totalCompleted items',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Legend/Summary
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'Total Items',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    sortedEntries
                        .fold<int>(
                            0,
                            (sum, entry) =>
                                sum + (entry.value['totalCompleted'] as int))
                        .toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.grey[300],
              ),
              Column(
                children: [
                  Text(
                    'Avg. Time',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    sortedEntries.isNotEmpty
                        ? _formatSeconds((sortedEntries
                                    .map((e) =>
                                        e.value['averageTimePerItem'] as double)
                                    .reduce((a, b) => a + b) /
                                sortedEntries.length)
                            .round())
                        : '0s',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemEfficiencyChart(Map<String, Map<String, dynamic>> itemData) {
    if (itemData.isEmpty) {
      return const Center(
        child: Text('No item efficiency data available'),
      );
    }

    final sortedItems = itemData.entries.toList()
      ..sort((a, b) => (b.value['totalCompleted'] as int)
          .compareTo(a.value['totalCompleted'] as int));

    final topItems = sortedItems.take(6).toList(); // Show top 6 items
    final maxCompleted = topItems.first.value['totalCompleted'] as int;

    return Column(
      children: topItems.map((entry) {
        final itemName = entry.key;
        final totalCompleted = entry.value['totalCompleted'] as int;
        final avgTime = entry.value['avgTimePerItem'] as double;
        final efficiency = entry.value['efficiency'] as double;
        final percentage =
            maxCompleted > 0 ? totalCompleted / maxCompleted : 0.0;

        // Color based on efficiency
        Color barColor = Colors.green;
        if (efficiency < 1.0) {
          barColor = Colors.orange;
        } else if (efficiency < 0.5) {
          barColor = Colors.red;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      itemName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: barColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$totalCompleted items',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: barColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${efficiency.toStringAsFixed(1)}/h',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percentage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductivityMetrics(List<MESProductionRecord> records,
      Map<String, Map<String, dynamic>> itemData) {
    // Calculate overall metrics
    final totalItemsCompleted = records.fold(
        0, (sum, record) => sum + record.itemCompletionRecords.length);
    final totalProductionTime = records.fold(
        0, (sum, record) => sum + record.totalProductionTimeSeconds);
    final overallEfficiency = totalProductionTime > 0
        ? (totalItemsCompleted / (totalProductionTime / 3600))
        : 0.0;

    // Calculate best and worst performing items
    final sortedByEfficiency = itemData.entries.toList()
      ..sort((a, b) => (b.value['efficiency'] as double)
          .compareTo(a.value['efficiency'] as double));

    final bestItem =
        sortedByEfficiency.isNotEmpty ? sortedByEfficiency.first : null;
    final worstItem =
        sortedByEfficiency.length > 1 ? sortedByEfficiency.last : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple[600], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Productivity Metrics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Items',
                    totalItemsCompleted.toString(),
                    Icons.inventory,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Overall Rate',
                    '${overallEfficiency.toStringAsFixed(1)}/hour',
                    Icons.speed,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Production Time',
                    _formatSeconds(totalProductionTime),
                    Icons.access_time,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            if (bestItem != null && worstItem != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceCard(
                      'Best Performer',
                      bestItem.key,
                      '${(bestItem.value['efficiency'] as double).toStringAsFixed(1)}/h',
                      Colors.green,
                      Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPerformanceCard(
                      'Needs Improvement',
                      worstItem.key,
                      '${(worstItem.value['efficiency'] as double).toStringAsFixed(1)}/h',
                      Colors.orange,
                      Icons.trending_down,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
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

  Widget _buildPerformanceCard(
      String label, String itemName, String rate, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            itemName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            rate,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
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
          'Items & Quantities Completed',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Chart showing item quantities
        if (sortedItems.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Completed Quantities by Item',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildItemQuantityChart(sortedItems),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Detailed list
        const Text(
          'Detailed Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...sortedItems.take(10).map((entry) {
          final itemName = entry.key;
          final count = entry.value['count']!;
          final time = entry.value['time']!;
          final avgTime = count > 0 ? time ~/ count : 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              title: Text(
                itemName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Avg: ${_formatSeconds(avgTime)} per item'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total: ${_formatSeconds(time)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '$count items',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildItemQuantityChart(
      List<MapEntry<String, Map<String, int>>> sortedItems) {
    final maxCount = sortedItems.first.value['count']!;
    final displayItems = sortedItems.take(8).toList(); // Show top 8 items

    return Column(
      children: displayItems.map((entry) {
        final itemName = entry.key;
        final count = entry.value['count']!;
        final percentage = maxCount > 0 ? (count / maxCount) : 0.0;

        // Generate color based on item position
        final colors = [
          const Color(0xFF2196F3), // Blue
          const Color(0xFF4CAF50), // Green
          const Color(0xFFFF9800), // Orange
          const Color(0xFF9C27B0), // Purple
          const Color(0xFFF44336), // Red
          const Color(0xFF00BCD4), // Cyan
          const Color(0xFFFFEB3B), // Yellow
          const Color(0xFF795548), // Brown
        ];
        final color = colors[displayItems.indexOf(entry) % colors.length];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      itemName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Text(
                      '$count items',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percentage,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.8), color],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
          width: 800,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            children: [
              // Header
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
                        'Production Details - ${item.name}',
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
                      // Details Section
                      _buildDetailsSection(record, item),
                      const SizedBox(height: 24),

                      // Time Breakdown Section
                      _buildTimeBreakdownSection(record),
                      const SizedBox(height: 24),

                      // Actions Section with timestamps
                      if (record.interruptions.isNotEmpty) ...[
                        _buildActionsSection(record),
                        const SizedBox(height: 24),
                      ],

                      // Activity Timeline Section
                      _buildActivityTimelineSection(record),
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

  // Enhanced Production Details section builders
  Widget _buildDetailsSection(MESProductionRecord record, MESItem item) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                const Text(
                  'Session Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildDetailRow('Item', item.name),
                      _buildDetailRow('Worker', record.userName),
                      _buildDetailRow('Status',
                          record.isCompleted ? 'Completed' : 'In Progress'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _buildDetailRow(
                          'Start Time',
                          DateFormat('yyyy-MM-dd HH:mm:ss')
                              .format(record.startTime)),
                      if (record.endTime != null)
                        _buildDetailRow(
                            'End Time',
                            DateFormat('yyyy-MM-dd HH:mm:ss')
                                .format(record.endTime!)),
                      _buildDetailRow('Total Duration',
                          _formatSeconds(_getTotalSessionDuration(record))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBreakdownSection(MESProductionRecord record) {
    final itemsCompleted = record.itemCompletionRecords.length;
    final avgTimePerItem = itemsCompleted > 0
        ? record.itemCompletionRecords
                .fold(0, (sum, item) => sum + item.durationSeconds) /
            itemsCompleted
        : 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer, color: AppColors.greenAccent),
                const SizedBox(width: 8),
                const Text(
                  'Time Breakdown',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTimeBreakdownCard(
                    'Production Time',
                    _formatSeconds(record.totalProductionTimeSeconds),
                    Icons.build,
                    AppColors.greenAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeBreakdownCard(
                    'Action Time',
                    _formatSeconds(record.totalInterruptionTimeSeconds),
                    Icons.pause,
                    AppColors.orangeAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeBreakdownCard(
                    'Items Completed',
                    '$itemsCompleted',
                    Icons.check_circle,
                    AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeBreakdownCard(
                    'Avg per Item',
                    _formatSeconds(avgTimePerItem.round()),
                    Icons.speed,
                    AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBreakdownCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
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

  Widget _buildActionsSection(MESProductionRecord record) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline, color: AppColors.orangeAccent),
                const SizedBox(width: 8),
                const Text(
                  'Actions Taken',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...record.interruptions
                .map((action) => _buildActionDetailCard(action)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionDetailCard(MESInterruption action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getActionColor(action.typeName).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: _getActionColor(action.typeName).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getActionColor(action.typeName),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.typeName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _formatSeconds(action.durationSeconds),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getActionColor(action.typeName),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Start: ${DateFormat('HH:mm:ss').format(action.startTime)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              if (action.endTime != null)
                Expanded(
                  child: Text(
                    'End: ${DateFormat('HH:mm:ss').format(action.endTime!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
          if (action.notes != null && action.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Notes: ${action.notes}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityTimelineSection(MESProductionRecord record) {
    final activities = _buildActivityTimeline(record);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                const Text(
                  'Activity Timeline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  final isLast = index == activities.length - 1;

                  return _buildTimelineItem(activity, isLast);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(ActivityTimelineItem activity, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: activity.color,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      activity.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('HH:mm:ss').format(activity.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (activity.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    activity.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<ActivityTimelineItem> _buildActivityTimeline(
      MESProductionRecord record) {
    final activities = <ActivityTimelineItem>[];

    // Add session start
    activities.add(ActivityTimelineItem(
      timestamp: record.startTime,
      title: 'Session Started',
      description: 'Production session began',
      color: AppColors.greenAccent,
    ));

    // Add interruptions/actions
    for (final interruption in record.interruptions) {
      activities.add(ActivityTimelineItem(
        timestamp: interruption.startTime,
        title: '${interruption.typeName} Started',
        description: interruption.notes ?? 'Action began',
        color: _getActionColor(interruption.typeName),
      ));

      if (interruption.endTime != null) {
        activities.add(ActivityTimelineItem(
          timestamp: interruption.endTime!,
          title: '${interruption.typeName} Ended',
          description:
              'Duration: ${_formatSeconds(interruption.durationSeconds)}',
          color: _getActionColor(interruption.typeName),
        ));
      }
    }

    // Add item completions
    for (final itemRecord in record.itemCompletionRecords) {
      activities.add(ActivityTimelineItem(
        timestamp: itemRecord.endTime,
        title: 'Item ${itemRecord.itemNumber} Completed',
        description:
            'Production time: ${_formatSeconds(itemRecord.durationSeconds)}',
        color: AppColors.primaryBlue,
      ));
    }

    // Add session end
    if (record.endTime != null) {
      activities.add(ActivityTimelineItem(
        timestamp: record.endTime!,
        title: 'Session Completed',
        description: 'Production session ended',
        color: AppColors.greenAccent,
      ));
    }

    // Sort by timestamp
    activities.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return activities;
  }

  int _getTotalSessionDuration(MESProductionRecord record) {
    if (record.endTime != null) {
      return record.endTime!.difference(record.startTime).inSeconds;
    }
    return DateTime.now().difference(record.startTime).inSeconds;
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

  Widget _buildFactoryTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.factory,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Factory Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Factory-wide analytics and insights coming soon...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Activity Timeline Item class
class ActivityTimelineItem {
  final DateTime timestamp;
  final String title;
  final String description;
  final Color color;

  ActivityTimelineItem({
    required this.timestamp,
    required this.title,
    required this.description,
    required this.color,
  });
}
