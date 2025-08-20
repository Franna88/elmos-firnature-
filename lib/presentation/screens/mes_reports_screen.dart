import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    _tabController = TabController(length: 3, vsync: this);
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

      // Load processes, items and production records
      await Future.wait([
        mesService.fetchProcesses(),
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
                Tab(icon: Icon(Icons.settings), text: 'Process'),
                Tab(icon: Icon(Icons.inventory), text: 'Item'),
                Tab(icon: Icon(Icons.timeline), text: 'Actions'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProcessTab(),
                _buildItemTab(),
                _buildActionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Process Tab - Shows list of processes and detailed view with Date-Item-Finished QTY-Prod Time
  Widget _buildProcessTab() {
    return Consumer<MESService>(
      builder: (context, mesService, child) {
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final processes = mesService.processes;
        if (processes.isEmpty) {
          return _buildEmptyState(
            Icons.settings,
            'No Processes Found',
            'No MES processes are available.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: processes.length,
          itemBuilder: (context, index) {
            final process = processes[index];
            return _buildProcessCard(process, mesService);
          },
        );
      },
    );
  }

  Widget _buildProcessCard(dynamic process, MESService mesService) {
    // Calculate process statistics
    final processRecords = mesService.productionRecords.where((record) {
      final item = mesService.items.firstWhere(
        (item) => item.id == record.itemId,
        orElse: () => MESItem(
          id: 'unknown',
          name: 'Unknown',
          processId: '',
          estimatedTimeInMinutes: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return item.processId == process.id;
    }).toList();

    final totalItems = processRecords.fold(
        0, (sum, record) => sum + record.itemCompletionRecords.length);
    final totalProdTime = processRecords.fold(
        0, (sum, record) => sum + record.totalProductionTimeSeconds);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primaryBlue.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showProcessDetails(process, mesService),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Process Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.settings,
                  color: AppColors.primaryBlue,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),

              // Process Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      process.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (process.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        process.description!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildQuickMetric(
                          'Items',
                          '$totalItems',
                          AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 16),
                        _buildQuickMetric(
                          'Production Time',
                          _formatSeconds(totalProdTime),
                          AppColors.greenAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Item Tab - Shows list of items and detailed view with Date-Finished QTY-Ave Time per item
  Widget _buildItemTab() {
    return Consumer<MESService>(
      builder: (context, mesService, child) {
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = mesService.items;
        if (items.isEmpty) {
          return _buildEmptyState(
            Icons.inventory,
            'No Items Found',
            'No MES items are available.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildItemCard(item, mesService);
          },
        );
      },
    );
  }

  Widget _buildItemCard(dynamic item, MESService mesService) {
    // Calculate item statistics
    final itemRecords = mesService.productionRecords
        .where((record) => record.itemId == item.id)
        .toList();

    final totalCompleted = itemRecords.fold(
        0, (sum, record) => sum + record.itemCompletionRecords.length);
    final totalProdTime = itemRecords.fold(
        0, (sum, record) => sum + record.totalProductionTimeSeconds);
    final avgTimePerItem =
        totalCompleted > 0 ? totalProdTime / totalCompleted : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primaryBlue.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showItemDetails(item, mesService),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Item Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory,
                  color: AppColors.primaryBlue,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),

              // Item Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (item.category != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Category: ${item.category}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildQuickMetric(
                          'Completed',
                          '$totalCompleted',
                          AppColors.greenAccent,
                        ),
                        const SizedBox(width: 16),
                        _buildQuickMetric(
                          'Avg Time',
                          avgTimePerItem > 0
                              ? _formatSeconds(avgTimePerItem.round())
                              : '0m',
                          AppColors.orangeAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 24,
              ),
            ],
          ),
        ),
      ),
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

    // Calculate interruption time with fallback
    int totalInterruptionSeconds = record.totalInterruptionTimeSeconds;
    if (totalInterruptionSeconds == 0 && record.interruptions.isNotEmpty) {
      // Fallback: calculate from individual interruptions
      totalInterruptionSeconds =
          record.interruptions.fold(0, (sum, interruption) {
        int duration = interruption.durationSeconds;
        if (duration == 0 && interruption.endTime != null) {
          duration = interruption.endTime!
              .difference(interruption.startTime)
              .inSeconds;
        }
        return sum + duration;
      });
    }
    final interruptionTime = Duration(seconds: totalInterruptionSeconds);

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

  // Actions Tab - Shows list of actions and detailed view with Date-Total time-User-Process
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
            return _buildActionTypeCard(actionName, actions, mesService);
          },
        );
      },
    );
  }

  Widget _buildActionTypeCard(
      String actionName, List<MESInterruption> actions, MESService mesService) {
    final totalDuration =
        actions.fold(0, (sum, action) => sum + action.durationSeconds);
    final actionColor = _getActionColor(actionName);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: actionColor.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showActionDetails(actionName, actions, mesService),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Action Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: actionColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getActionIcon(actionName),
                  color: actionColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),

              // Action Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actionName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${actions.length} occurrences',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildQuickMetric(
                          'Total Time',
                          _formatSeconds(totalDuration),
                          actionColor,
                        ),
                        const SizedBox(width: 16),
                        _buildQuickMetric(
                          'Average',
                          _formatSeconds(
                              (totalDuration / actions.length).round()),
                          Colors.grey[600]!,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 24,
              ),
            ],
          ),
        ),
      ),
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
              Icon(Icons.show_chart, size: 48, color: Colors.grey),
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
                'Start production to see daily averages',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate daily item data with item names and dates
    final dailyItemData = _calculateDailyItemAverages(records);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Production Analysis',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Daily Average Time Per Item Line Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart, color: Colors.blue[600], size: 20),
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
                  'Track average completion time by item and date',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: _buildDailyItemLineChart(dailyItemData),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, Map<String, dynamic>> _calculateDailyItemAverages(
      List<MESProductionRecord> records) {
    final dailyData = <String, Map<String, dynamic>>{};

    // Group by date and item
    for (final record in records) {
      final date = DateFormat('MM/dd').format(record.startTime);

      // Get item name - need to fetch from service
      // For now we'll use a placeholder that works with the structure
      for (final itemRecord in record.itemCompletionRecords) {
        final key = '$date'; // Simplified key for now

        if (!dailyData.containsKey(key)) {
          dailyData[key] = {
            'date': date,
            'itemName': 'Production Item', // Placeholder
            'totalTime': 0,
            'totalCompleted': 0,
            'averageTime': 0.0,
          };
        }

        dailyData[key]!['totalTime'] =
            (dailyData[key]!['totalTime'] as int) + itemRecord.durationSeconds;
        dailyData[key]!['totalCompleted'] =
            (dailyData[key]!['totalCompleted'] as int) + 1;
      }
    }

    // Calculate averages
    for (final entry in dailyData.entries) {
      final totalCompleted = entry.value['totalCompleted'] as int;
      final totalTime = entry.value['totalTime'] as int;

      if (totalCompleted > 0) {
        entry.value['averageTime'] = totalTime / totalCompleted;
      }
    }

    return dailyData;
  }

  Widget _buildDailyItemLineChart(Map<String, Map<String, dynamic>> dailyData) {
    if (dailyData.isEmpty) {
      return const Center(
        child: Text(
          'No daily data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Sort data by date
    final sortedEntries = dailyData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final maxTime = sortedEntries.fold<double>(0, (max, entry) {
      final avgTime = entry.value['averageTime'] as double;
      return avgTime > max ? avgTime : max;
    });

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Simple line chart representation
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Chart header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Max: ${_formatSeconds(maxTime.round())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Min: ${_formatSeconds(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Data points
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: sortedEntries.map((entry) {
                      final date = entry.value['date'] as String;
                      final avgTime = entry.value['averageTime'] as double;
                      final height =
                          maxTime > 0 ? (avgTime / maxTime) * 120 : 0.0;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Time value
                              Text(
                                _formatSeconds(avgTime.round()),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Visual bar (representing line point)
                              Container(
                                width: 8,
                                height: height,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Date label
                              Text(
                                date,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Data summary
          Wrap(
            children: sortedEntries.take(5).map((entry) {
              final date = entry.value['date'] as String;
              final avgTime = entry.value['averageTime'] as double;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$date: ${_formatSeconds(avgTime.round())}',
                  style: const TextStyle(fontSize: 10),
                ),
              );
            }).toList(),
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

  void _showProcessDetails(dynamic process, MESService mesService) {
    final processRecords = mesService.productionRecords.where((record) {
      final item = mesService.items.firstWhere(
        (item) => item.id == record.itemId,
        orElse: () => MESItem(
          id: 'unknown',
          name: 'Unknown',
          processId: '',
          estimatedTimeInMinutes: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return item.processId == process.id;
    }).toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 900,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.settings, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Process Details - ${process.name}',
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

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Production Records',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Headers
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                                flex: 2,
                                child: Text('Date',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            Expanded(
                                flex: 3,
                                child: Text('Item',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            Expanded(
                                flex: 2,
                                child: Text('Finished QTY',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            Expanded(
                                flex: 2,
                                child: Text('Prod Time',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),

                      // Records
                      ...processRecords.map((record) {
                        final item = mesService.items.firstWhere(
                          (item) => item.id == record.itemId,
                          orElse: () => MESItem(
                            id: 'unknown',
                            name: 'Unknown',
                            processId: '',
                            estimatedTimeInMinutes: 0,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: Colors.grey[200]!)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(DateFormat('MM/dd/yyyy')
                                    .format(record.startTime)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(item.name),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                    '${record.itemCompletionRecords.length}'),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(_formatSeconds(
                                    record.totalProductionTimeSeconds)),
                              ),
                            ],
                          ),
                        );
                      }),
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

  void _showActionDetails(
      String actionName, List<dynamic> actions, MESService mesService) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 1000,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getActionColor(actionName),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_getActionIcon(actionName), color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Action Details - $actionName',
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

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Action History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Headers
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                                flex: 2,
                                child: Text('Date',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            Expanded(
                                flex: 2,
                                child: Text('Total Time',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            Expanded(
                                flex: 2,
                                child: Text('User',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            Expanded(
                                flex: 3,
                                child: Text('Process',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),

                      // Group actions by date/session and aggregate data
                      ...actions.map((action) {
                        // Find the production record this action belongs to
                        MESProductionRecord? productionRecord;
                        try {
                          productionRecord =
                              mesService.productionRecords.firstWhere(
                            (record) => record.interruptions.contains(action),
                          );
                        } catch (e) {
                          productionRecord = null;
                        }

                        String? processName;
                        if (productionRecord != null) {
                          try {
                            final item = mesService.items.firstWhere(
                              (item) => item.id == productionRecord!.itemId,
                            );
                            final process = mesService.processes.firstWhere(
                              (proc) => proc.id == item.processId,
                            );
                            processName = process.name;
                          } catch (e) {
                            processName = 'Unknown Process';
                          }
                        } else {
                          processName = 'Unknown Process';
                        }

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: Colors.grey[200]!)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(DateFormat('MM/dd/yyyy')
                                    .format(action.startTime)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                    _formatSeconds(action.durationSeconds)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                    productionRecord?.userName ?? 'Unknown'),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(processName),
                              ),
                            ],
                          ),
                        );
                      }),
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

  void _showItemDetails(dynamic item, MESService mesService) {
    final itemRecords = mesService.productionRecords
        .where((record) => record.itemId == item.id)
        .toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 900,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Item Details - ${item.name}',
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

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Production History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Headers
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                                flex: 2,
                                child: Text('Date',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            Expanded(
                                flex: 2,
                                child: Text('Finished QTY',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            Expanded(
                                flex: 3,
                                child: Text('Ave Time per Item',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),

                      // Records
                      ...itemRecords.map((record) {
                        final completedCount =
                            record.itemCompletionRecords.length;
                        final avgTime = completedCount > 0
                            ? record.totalProductionTimeSeconds / completedCount
                            : 0.0;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: Colors.grey[200]!)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(DateFormat('MM/dd/yyyy')
                                    .format(record.startTime)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('$completedCount'),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(_formatSeconds(avgTime.round())),
                              ),
                            ],
                          ),
                        );
                      }),
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

    // Calculate total action time from all interruptions
    // If stored duration is 0, calculate from start/end times as fallback
    final totalActionTime = record.interruptions.fold(0, (sum, interruption) {
      int duration = interruption.durationSeconds;
      // Fallback: calculate from timestamps if duration is 0
      if (duration == 0 && interruption.endTime != null) {
        duration =
            interruption.endTime!.difference(interruption.startTime).inSeconds;
      }
      return sum + duration;
    });

    // Calculate average time per item from item completion records
    // If item records don't have durations, calculate from total production time
    double avgTimePerItem = 0.0;
    if (itemsCompleted > 0) {
      final totalItemTime = record.itemCompletionRecords
          .fold(0, (sum, item) => sum + item.durationSeconds);

      if (totalItemTime > 0) {
        avgTimePerItem = totalItemTime / itemsCompleted;
      } else {
        // Fallback: use total production time divided by items completed
        avgTimePerItem = record.totalProductionTimeSeconds / itemsCompleted;
      }
    }

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
                    _formatSeconds(totalActionTime),
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
                    avgTimePerItem > 0
                        ? _formatSeconds(avgTimePerItem.round())
                        : '0m',
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
    // Calculate duration with fallback
    int duration = action.durationSeconds;
    if (duration == 0 && action.endTime != null) {
      duration = action.endTime!.difference(action.startTime).inSeconds;
    }

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
                _formatSeconds(duration),
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
