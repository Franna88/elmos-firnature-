import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import '../../data/services/mes_service.dart';
import '../../data/models/mes_production_record_model.dart';
import '../../data/models/mes_item_model.dart';
import 'dart:math' as math;

class MESReportsScreen extends StatefulWidget {
  const MESReportsScreen({Key? key}) : super(key: key);

  @override
  State<MESReportsScreen> createState() => _MESReportsScreenState();
}

class _MESReportsScreenState extends State<MESReportsScreen>
    with SingleTickerProviderStateMixin {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String? _selectedItemId;
  String? _selectedUserId;
  bool _onlyCompleted = true;
  late TabController _tabController;

  // Daily summary data
  List<Map<String, dynamic>> _dailySummaries = [];
  bool _isLoadingDailySummary = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _loadDailySummaries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load MES data
  Future<void> _loadData() async {
    final mesService = Provider.of<MESService>(context, listen: false);

    // Load items
    await mesService.fetchItems();

    // Load production records with filters
    await mesService.fetchProductionRecords(
      itemId: _selectedItemId,
      userId: _selectedUserId,
      startDate: _startDate,
      endDate: _endDate,
      onlyCompleted: _onlyCompleted,
    );
  }

  // Load daily summary data
  Future<void> _loadDailySummaries() async {
    setState(() {
      _isLoadingDailySummary = true;
    });

    try {
      final mesService = Provider.of<MESService>(context, listen: false);
      final summaries = await mesService.fetchDailySummaries(
        startDate: _startDate,
        endDate: _endDate,
        userId: _selectedUserId,
      );

      setState(() {
        _dailySummaries = summaries;
        _isLoadingDailySummary = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDailySummary = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading daily summaries: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MES Production Reports',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        backgroundColor: const Color(0xFFEB281E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _loadData();
              _loadDailySummaries();
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to CSV',
            onPressed: _exportCurrentReport,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Production Records'),
            Tab(text: 'Daily Summaries'),
            Tab(text: 'Productivity Analysis'),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilters(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductionRecordsTab(),
                _buildDailySummariesTab(),
                _buildProductivityAnalysisTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final mesService = Provider.of<MESService>(context);
    final items = mesService.items.where((item) => item.isActive).toList();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Reports',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEB281E),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Start Date',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEB281E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectStartDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(_startDate),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'End Date',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEB281E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectEndDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(_endDate),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter by Item',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEB281E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        value: _selectedItemId,
                        onChanged: (value) {
                          setState(() {
                            _selectedItemId = value;
                          });
                        },
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Items'),
                          ),
                          ...items.map((item) {
                            return DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(item.name),
                            );
                          }).toList(),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter by Operator',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEB281E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _fetchOperators(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const LinearProgressIndicator();
                          }

                          final operators = snapshot.data ?? [];

                          return DropdownButtonFormField<String?>(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            value: _selectedUserId,
                            onChanged: (value) {
                              setState(() {
                                _selectedUserId = value;
                              });
                            },
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Operators'),
                              ),
                              ...operators.map((op) {
                                return DropdownMenuItem<String>(
                                  value: op['id'],
                                  child: Text(op['name']),
                                );
                              }).toList(),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _onlyCompleted,
                      onChanged: (value) {
                        setState(() {
                          _onlyCompleted = value ?? true;
                        });
                      },
                    ),
                    const Text('Show completed items only'),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('Apply Filters'),
                  onPressed: () {
                    _loadData();
                    _loadDailySummaries();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper to fetch unique operators from production records
  Future<List<Map<String, dynamic>>> _fetchOperators() async {
    final mesService = Provider.of<MESService>(context, listen: false);

    try {
      return await mesService.fetchUniqueOperators();
    } catch (e) {
      return [];
    }
  }

  // Production Records Tab
  Widget _buildProductionRecordsTab() {
    final mesService = Provider.of<MESService>(context);

    if (mesService.isLoadingProductionRecords) {
      return const Center(child: CircularProgressIndicator());
    }

    final records = mesService.productionRecords;

    if (records.isEmpty) {
      return const Center(
        child:
            Text('No production records found matching the current filters.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildSummaryCard(records),
        const SizedBox(height: 16),
        _buildRecordsTable(records, mesService),
      ],
    );
  }

  // Daily Summaries Tab
  Widget _buildDailySummariesTab() {
    if (_isLoadingDailySummary) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_dailySummaries.isEmpty) {
      return const Center(
        child: Text('No daily summaries found matching the current filters.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildDailySummaryCard(),
        const SizedBox(height: 16),
        _buildDailySummaryTable(),
      ],
    );
  }

  // Productivity Analysis Tab
  Widget _buildProductivityAnalysisTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildProductivityChart(),
        const SizedBox(height: 16),
        _buildProductivityMetrics(),
        const SizedBox(height: 16),
        _buildNonProductiveAnalysis(),
      ],
    );
  }

  // Daily Summary Card
  Widget _buildDailySummaryCard() {
    // Calculate summary statistics
    int totalItemsCompleted = 0;
    int totalProductiveTime = 0;
    int totalNonProductiveTime = 0;

    for (var summary in _dailySummaries) {
      totalItemsCompleted += summary['itemsCompleted'] as int;
      totalProductiveTime += summary['totalProductionTimeSeconds'] as int;
      totalNonProductiveTime += summary['totalNonProductiveTimeSeconds'] as int;
    }

    // Calculate productivity percentage
    final totalTime = totalProductiveTime + totalNonProductiveTime;
    final productivityPercent = totalTime > 0
        ? (totalProductiveTime / totalTime * 100).toStringAsFixed(1) + '%'
        : '0%';

    // Calculate non-productive percentage
    final nonProductivePercent = totalTime > 0
        ? (totalNonProductiveTime / totalTime * 100).toStringAsFixed(1) + '%'
        : '0%';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Production Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat(
                  'Total Days',
                  _dailySummaries.length.toString(),
                  Icons.calendar_today,
                ),
                _buildSummaryStat(
                  'Items Completed',
                  totalItemsCompleted.toString(),
                  Icons.check_circle_outline,
                ),
                _buildSummaryStat(
                  'Productive Time',
                  _formatDuration(totalProductiveTime),
                  Icons.timer,
                  color: Colors.green,
                ),
                _buildSummaryStat(
                  'Non-Productive Time',
                  _formatDuration(totalNonProductiveTime),
                  Icons.timer_off,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Add time chart
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: totalTime > 0
                                ? totalProductiveTime / totalTime
                                : 0,
                            minHeight: 24,
                            backgroundColor: Colors.red[100],
                            color: Colors.green[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green[400],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Productive: $productivityPercent',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Non-Productive: $nonProductivePercent',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
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

  // Daily Summary Table
  Widget _buildDailySummaryTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Summaries',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: MaterialStateColor.resolveWith(
                  (states) => Colors.grey.shade100,
                ),
                columns: const [
                  DataColumn(
                      label: Text(
                    'Date',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  )),
                  DataColumn(
                      label: Text(
                    'Operator',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  )),
                  DataColumn(
                      label: Text(
                    'Items Completed',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  )),
                  DataColumn(
                      label: Text(
                    'Productive Time',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  )),
                  DataColumn(
                      label: Text(
                    'Non-Productive Time',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  )),
                  DataColumn(
                      label: Text(
                    'Productivity',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  )),
                ],
                rows: _dailySummaries.map((summary) {
                  final totalTime =
                      (summary['totalProductionTimeSeconds'] as int) +
                          (summary['totalNonProductiveTimeSeconds'] as int);
                  final productivity = totalTime > 0
                      ? (summary['totalProductionTimeSeconds'] as int) /
                          totalTime *
                          100
                      : 0;

                  final date = (summary['date'] as DateTime);

                  return DataRow(
                    cells: [
                      DataCell(Text(DateFormat('yyyy-MM-dd').format(date))),
                      DataCell(Text(summary['userName'] as String)),
                      DataCell(Text(summary['itemsCompleted'].toString())),
                      DataCell(Text(_formatDuration(
                          summary['totalProductionTimeSeconds'] as int))),
                      DataCell(Text(_formatDuration(
                          summary['totalNonProductiveTimeSeconds'] as int))),
                      DataCell(
                        Row(
                          children: [
                            Container(
                              width: 60,
                              child: LinearProgressIndicator(
                                value: productivity / 100,
                                backgroundColor: Colors.grey[200],
                                color: _getProductivityColor(
                                    productivity.toDouble()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${productivity.toStringAsFixed(1)}%'),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Productivity Chart
  Widget _buildProductivityChart() {
    // Sort summaries by date
    final sortedSummaries = List<Map<String, dynamic>>.from(_dailySummaries)
      ..sort(
          (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Productivity Trends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 2.0,
              child: sortedSummaries.isEmpty
                  ? const Center(
                      child: Text('No data available for productivity chart'))
                  : _ProductivityChart(dailySummaries: sortedSummaries),
            ),
          ],
        ),
      ),
    );
  }

  // Productivity Metrics - Top Performers, Items, etc.
  Widget _buildProductivityMetrics() {
    // Process data for metrics
    final itemsProduced = <String, int>{};
    final operatorProductivity = <String, Map<String, dynamic>>{};

    // Get all production records
    final mesService = Provider.of<MESService>(context);
    final records = mesService.productionRecords;

    // Group by item and operator
    for (var record in records) {
      if (record.isCompleted) {
        // Count items
        final item = mesService.items.firstWhere(
          (i) => i.id == record.itemId,
          orElse: () => MESItem(
            id: 'unknown',
            name: 'Unknown Item',
            processId: 'unknown',
            estimatedTimeInMinutes: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        itemsProduced[item.name] = (itemsProduced[item.name] ?? 0) + 1;

        // Calculate operator metrics
        if (!operatorProductivity.containsKey(record.userName)) {
          operatorProductivity[record.userName] = {
            'itemsCompleted': 0,
            'totalProductionTime': 0,
            'totalInterruptionTime': 0,
          };
        }

        operatorProductivity[record.userName]!['itemsCompleted'] =
            (operatorProductivity[record.userName]!['itemsCompleted'] as int) +
                1;

        operatorProductivity[record.userName]!['totalProductionTime'] =
            (operatorProductivity[record.userName]!['totalProductionTime']
                    as int) +
                record.totalProductionTimeSeconds;

        operatorProductivity[record.userName]!['totalInterruptionTime'] =
            (operatorProductivity[record.userName]!['totalInterruptionTime']
                    as int) +
                record.totalInterruptionTimeSeconds;
      }
    }

    // Sort and get top items
    final topItems = itemsProduced.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate and sort operators by productivity
    final operatorList = operatorProductivity.entries.map((entry) {
      final totalTime = (entry.value['totalProductionTime'] as int) +
          (entry.value['totalInterruptionTime'] as int);
      final productivity = totalTime > 0
          ? (entry.value['totalProductionTime'] as int) / totalTime * 100
          : 0;

      return {
        'name': entry.key,
        'itemsCompleted': entry.value['itemsCompleted'],
        'productivity': productivity,
        'totalTime': totalTime,
      };
    }).toList()
      ..sort((a, b) =>
          (b['productivity'] as double).compareTo(a['productivity'] as double));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Items
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Produced Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  topItems.isEmpty
                      ? const Text('No data available')
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: math.min(5, topItems.length),
                          itemBuilder: (context, index) {
                            final item = topItems[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text('${index + 1}'),
                              ),
                              title: Text(item.key),
                              trailing: Text(
                                '${item.value} items',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: LinearProgressIndicator(
                                value: item.value /
                                    (topItems.isNotEmpty
                                        ? topItems.first.value
                                        : 1),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Top Operators
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Operator Productivity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  operatorList.isEmpty
                      ? const Text('No data available')
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: math.min(5, operatorList.length),
                          itemBuilder: (context, index) {
                            final operator = operatorList[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getProductivityColor(
                                    operator['productivity'] as double),
                                child: Text('${index + 1}'),
                              ),
                              title: Text(operator['name'] as String),
                              subtitle: Row(
                                children: [
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value:
                                          (operator['productivity'] as double) /
                                              100,
                                      backgroundColor: Colors.grey[200],
                                      color: _getProductivityColor(
                                          operator['productivity'] as double),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                      '${(operator['productivity'] as double).toStringAsFixed(1)}%'),
                                ],
                              ),
                              trailing: Text(
                                '${operator['itemsCompleted']} items',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Add a new method to analyze non-productive time by category
  Widget _buildNonProductiveAnalysis() {
    // Get all production records from the service
    final mesService = Provider.of<MESService>(context);
    final records = mesService.productionRecords;

    // Define a map to track interruption types and their durations
    final interruptionsByType = <String, int>{};
    int totalInterruptionTime = 0;

    // Analyze all interruptions
    for (var record in records) {
      for (var interruption in record.interruptions) {
        // Add to the type map
        interruptionsByType[interruption.typeName] =
            (interruptionsByType[interruption.typeName] ?? 0) +
                interruption.durationSeconds;

        // Add to total
        totalInterruptionTime += interruption.durationSeconds;
      }
    }

    // Sort interruption types by duration (descending)
    final sortedTypes = interruptionsByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Determine colors for each type
    final typeColors = <String, Color>{};
    for (var entry in sortedTypes) {
      Color color = Colors.grey;

      if (entry.key.toLowerCase().contains('break')) {
        color = const Color(0xFF795548); // Brown
      } else if (entry.key.toLowerCase().contains('maintenance')) {
        color = const Color(0xFFFF9800); // Orange
      } else if (entry.key.toLowerCase().contains('prep')) {
        color = const Color(0xFF2196F3); // Blue
      } else if (entry.key.toLowerCase().contains('material')) {
        color = const Color(0xFF4CAF50); // Green
      } else if (entry.key.toLowerCase().contains('training')) {
        color = const Color(0xFF9C27B0); // Purple
      }

      typeColors[entry.key] = color;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Non-Productive Time Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (interruptionsByType.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                    'No non-productive activities recorded in this period.'),
              )
            else
              Column(
                children: [
                  // Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'Total Non-Productive Time',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDuration(totalInterruptionTime),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'Different Types',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              interruptionsByType.length.toString(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Type breakdown
                  const Text(
                    'Breakdown by Type',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bar chart
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    height: interruptionsByType.length * 50.0 + 40,
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Y-axis labels
                              SizedBox(
                                width: 150,
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: sortedTypes.map((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Text(
                                        entry.key,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Bars
                              Expanded(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: sortedTypes.map((entry) {
                                    // Calculate percentage of total
                                    final percentage = totalInterruptionTime > 0
                                        ? entry.value / totalInterruptionTime
                                        : 0.0;

                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 24,
                                            clipBehavior: Clip.hardEdge,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              color: Colors.grey[200],
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: (percentage * 100)
                                                      .round(),
                                                  child: Container(
                                                    color:
                                                        typeColors[entry.key],
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 100 -
                                                      (percentage * 100)
                                                          .round(),
                                                  child: Container(),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 100,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _formatDuration(entry.value),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                '${(percentage * 100).toStringAsFixed(1)}%',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
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

  // Export current report to CSV
  void _exportCurrentReport() {
    final tabIndex = _tabController.index;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Exporting ${_getReportNameByTabIndex(tabIndex)} report...')),
    );

    // In a real implementation, you would generate and download a CSV here
    // This is a placeholder for the actual export implementation
    Future.delayed(const Duration(seconds: 2), () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${_getReportNameByTabIndex(tabIndex)} report exported successfully!')),
      );
    });
  }

  String _getReportNameByTabIndex(int index) {
    switch (index) {
      case 0:
        return 'Production Records';
      case 1:
        return 'Daily Summaries';
      case 2:
        return 'Productivity Analysis';
      default:
        return 'MES';
    }
  }

  // Helper method to get color based on productivity percentage
  Color _getProductivityColor(double productivity) {
    if (productivity >= 80) {
      return Colors.green;
    } else if (productivity >= 60) {
      return Colors.amber;
    } else {
      return Colors.red;
    }
  }

  Widget _buildSummaryCard(List<MESProductionRecord> records) {
    // Calculate summary statistics
    final totalItems = records.length;
    final totalProductionTime = records.fold(
      0,
      (sum, record) => sum + record.totalProductionTimeSeconds,
    );
    final totalInterruptionTime = records.fold(
      0,
      (sum, record) => sum + record.totalInterruptionTimeSeconds,
    );

    // Calculate average production time
    final avgProductionTime =
        totalItems > 0 ? totalProductionTime ~/ totalItems : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Production Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat(
                  'Total Items',
                  totalItems.toString(),
                  Icons.category,
                ),
                _buildSummaryStat(
                  'Total Production Time',
                  _formatDuration(totalProductionTime),
                  Icons.access_time,
                ),
                _buildSummaryStat(
                  'Total Interruption Time',
                  _formatDuration(totalInterruptionTime),
                  Icons.pause_circle_outline,
                ),
                _buildSummaryStat(
                  'Avg. Production Time',
                  _formatDuration(avgProductionTime),
                  Icons.timer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon,
      {Color? color}) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color ?? Colors.blue),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordsTable(
      List<MESProductionRecord> records, MESService mesService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Production Records',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateColor.resolveWith(
                  (states) => Colors.grey.shade100,
                ),
                columnSpacing: 20,
                columns: const [
                  DataColumn(
                      label: Text(
                    'Item',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  )),
                  DataColumn(
                      label: Text(
                    'Operator',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  )),
                  DataColumn(
                      label: Text(
                    'Start Time',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  )),
                  DataColumn(
                      label: Text(
                    'End Time',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  )),
                  DataColumn(
                      label: Text(
                    'Production Time',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  )),
                  DataColumn(
                      label: Text(
                    'Interruption Time',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  )),
                  DataColumn(
                      label: Text(
                    'Status',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  )),
                  DataColumn(
                      label: Text(
                    'Actions',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  )),
                ],
                rows: records.map((record) {
                  // Find the item
                  final item = mesService.items.firstWhere(
                    (i) => i.id == record.itemId,
                    orElse: () => MESItem(
                      id: 'unknown',
                      name: 'Unknown Item',
                      processId: 'unknown',
                      estimatedTimeInMinutes: 0,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );

                  return DataRow(
                    cells: [
                      DataCell(Text(item.name)),
                      DataCell(Text(record.userName)),
                      DataCell(Text(DateFormat('yyyy-MM-dd HH:mm')
                          .format(record.startTime))),
                      DataCell(record.endTime != null
                          ? Text(DateFormat('yyyy-MM-dd HH:mm')
                              .format(record.endTime!))
                          : const Text('In Progress',
                              style: TextStyle(color: Colors.blue))),
                      DataCell(Text(
                          _formatDuration(record.totalProductionTimeSeconds))),
                      DataCell(Text(_formatDuration(
                          record.totalInterruptionTimeSeconds))),
                      DataCell(
                        record.isCompleted
                            ? const Text('Completed',
                                style: TextStyle(color: Colors.green))
                            : const Text('In Progress',
                                style: TextStyle(color: Colors.blue)),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          tooltip: 'View Details',
                          onPressed: () =>
                              _showRecordDetailsDialog(context, record, item),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordDetailsDialog(
      BuildContext context, MESProductionRecord record, MESItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 800,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Production Record Details: ${item.name}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              // Record details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column - Basic info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Item', item.name),
                        _buildInfoRow('Category', item.category),
                        _buildInfoRow('Operator', record.userName),
                        _buildInfoRow('Status',
                            record.isCompleted ? 'Completed' : 'In Progress'),
                        _buildInfoRow(
                            'Start Time',
                            DateFormat('yyyy-MM-dd HH:mm')
                                .format(record.startTime)),
                        if (record.endTime != null)
                          _buildInfoRow(
                              'End Time',
                              DateFormat('yyyy-MM-dd HH:mm')
                                  .format(record.endTime!)),
                        const SizedBox(height: 8),
                        Divider(color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        _buildInfoRow('Production Time',
                            _formatDuration(record.totalProductionTimeSeconds),
                            valueColor: Colors.green),
                        _buildInfoRow(
                            'Non-Productive Time',
                            _formatDuration(
                                record.totalInterruptionTimeSeconds),
                            valueColor: Colors.red),
                        _buildInfoRow(
                            'Total Time',
                            _formatDuration(record.totalProductionTimeSeconds +
                                record.totalInterruptionTimeSeconds)),
                      ],
                    ),
                  ),

                  // Right column - Interruptions
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Non-Productive Activities',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (record.interruptions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child:
                                Text('No non-productive activities recorded.'),
                          )
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: SingleChildScrollView(
                              child: Column(
                                children:
                                    record.interruptions.map((interruption) {
                                  final startTime = DateFormat('HH:mm:ss')
                                      .format(interruption.startTime);
                                  final endTime = interruption.endTime != null
                                      ? DateFormat('HH:mm:ss')
                                          .format(interruption.endTime!)
                                      : 'N/A';

                                  // Determine color based on type name
                                  Color typeColor = Colors.grey[800]!;
                                  if (interruption.typeName
                                      .toLowerCase()
                                      .contains('break')) {
                                    typeColor =
                                        const Color(0xFF795548); // Brown
                                  } else if (interruption.typeName
                                      .toLowerCase()
                                      .contains('maintenance')) {
                                    typeColor =
                                        const Color(0xFFFF9800); // Orange
                                  } else if (interruption.typeName
                                      .toLowerCase()
                                      .contains('prep')) {
                                    typeColor = const Color(0xFF2196F3); // Blue
                                  } else if (interruption.typeName
                                      .toLowerCase()
                                      .contains('material')) {
                                    typeColor =
                                        const Color(0xFF4CAF50); // Green
                                  } else if (interruption.typeName
                                      .toLowerCase()
                                      .contains('training')) {
                                    typeColor =
                                        const Color(0xFF9C27B0); // Purple
                                  }

                                  String duration;
                                  if (interruption.durationSeconds > 0) {
                                    duration = _formatDuration(
                                        interruption.durationSeconds);
                                  } else if (interruption.endTime != null) {
                                    duration = _formatDuration(interruption
                                        .endTime!
                                        .difference(interruption.startTime)
                                        .inSeconds);
                                  } else {
                                    duration = 'In Progress';
                                  }

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: typeColor.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 12,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      color: typeColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    interruption.typeName,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: typeColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                duration,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Start: $startTime',
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                              Text(
                                                'End: $endTime',
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ),
                                          if (interruption.notes != null &&
                                              interruption
                                                  .notes!.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              'Notes: ${interruption.notes}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to format seconds as HH:MM:SS
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Date picker for start date
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: _endDate,
    );

    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  // Date picker for end date
  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }
}

// Custom chart widget for productivity trend visualization
class _ProductivityChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailySummaries;

  const _ProductivityChart({Key? key, required this.dailySummaries})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ProductivityChartPainter(dailySummaries),
      child: Container(),
    );
  }
}

class _ProductivityChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> dailySummaries;

  _ProductivityChartPainter(this.dailySummaries);

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final int dataPoints = dailySummaries.length;

    if (dataPoints == 0) return;

    // Drawing setup
    final barWidth = width / (dataPoints * 2);
    final productionPaint = Paint()..color = Colors.green;
    final interruptionPaint = Paint()..color = Colors.red;
    final textStyle = TextStyle(color: Colors.black, fontSize: 10);
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Find max value for scaling
    int maxTotalTime = 0;
    for (var summary in dailySummaries) {
      final totalTime = (summary['totalProductionTimeSeconds'] as int) +
          (summary['totalNonProductiveTimeSeconds'] as int);
      if (totalTime > maxTotalTime) maxTotalTime = totalTime;
    }

    // Draw each day's data
    for (int i = 0; i < dataPoints; i++) {
      final summary = dailySummaries[i];
      final date = summary['date'] as DateTime;
      final productiveTime = summary['totalProductionTimeSeconds'] as int;
      final nonProductiveTime = summary['totalNonProductiveTimeSeconds'] as int;

      final x = i * (width / dataPoints) + (width / dataPoints / 2);

      // Calculate bar heights
      final productiveHeight = height * (productiveTime / maxTotalTime);
      final nonProductiveHeight = height * (nonProductiveTime / maxTotalTime);

      // Draw bars
      canvas.drawRect(
          Rect.fromLTWH(x - barWidth / 2, height - productiveHeight, barWidth,
              productiveHeight),
          productionPaint);

      canvas.drawRect(
          Rect.fromLTWH(
              x - barWidth / 2,
              height - productiveHeight - nonProductiveHeight,
              barWidth,
              nonProductiveHeight),
          interruptionPaint);

      // Draw date label
      textPainter.text = TextSpan(
        text: DateFormat('MM/dd').format(date),
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, height + 5));
    }

    // Draw legend
    final legendY = 20.0;
    // Productive time legend
    canvas.drawRect(
        Rect.fromLTWH(width - 120, legendY, 10, 10), productionPaint);
    textPainter.text = TextSpan(text: 'Productive', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset(width - 105, legendY));

    // Non-productive time legend
    canvas.drawRect(
        Rect.fromLTWH(width - 120, legendY + 20, 10, 10), interruptionPaint);
    textPainter.text = TextSpan(text: 'Non-productive', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset(width - 105, legendY + 20));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
