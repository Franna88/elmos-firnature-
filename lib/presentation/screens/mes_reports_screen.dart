import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/mes_service.dart';
import '../../data/models/mes_production_record_model.dart';
import '../../data/models/mes_item_model.dart';

class MESReportsScreen extends StatefulWidget {
  const MESReportsScreen({Key? key}) : super(key: key);

  @override
  State<MESReportsScreen> createState() => _MESReportsScreenState();
}

class _MESReportsScreenState extends State<MESReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String? _selectedItemId;
  bool _onlyCompleted = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load MES data
  Future<void> _loadData() async {
    final mesService = Provider.of<MESService>(context, listen: false);

    // Load items
    await mesService.fetchItems();

    // Load production records with filters
    await mesService.fetchProductionRecords(
      itemId: _selectedItemId,
      startDate: _startDate,
      endDate: _endDate,
      onlyCompleted: _onlyCompleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MES Production Reports'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilters(),
          Expanded(
            child: _buildReportContent(),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Date'),
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
                      const Text('End Date'),
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
                      const Text('Filter by Item'),
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
                  onPressed: _loadData,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent() {
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

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.blue),
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
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('Item')),
                  DataColumn(label: Text('Operator')),
                  DataColumn(label: Text('Start Time')),
                  DataColumn(label: Text('End Time')),
                  DataColumn(label: Text('Production Time')),
                  DataColumn(label: Text('Interruption Time')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: records.map((record) {
                  // Find the item
                  final item = mesService.items.firstWhere(
                    (i) => i.id == record.itemId,
                    orElse: () => MESItem(
                      id: 'unknown',
                      name: 'Unknown Item',
                      category: 'Unknown',
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
                        _buildInfoRow('Estimated Time',
                            '${item.estimatedTimeInMinutes} minutes'),
                        _buildInfoRow('Operator', record.userName),
                        _buildInfoRow('Status',
                            record.isCompleted ? 'Completed' : 'In Progress'),
                      ],
                    ),
                  ),

                  // Right column - Timing info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                            'Start Time',
                            DateFormat('yyyy-MM-dd HH:mm:ss')
                                .format(record.startTime)),
                        if (record.endTime != null)
                          _buildInfoRow(
                              'End Time',
                              DateFormat('yyyy-MM-dd HH:mm:ss')
                                  .format(record.endTime!))
                        else
                          _buildInfoRow('End Time', 'Not completed'),
                        _buildInfoRow('Production Time',
                            _formatDuration(record.totalProductionTimeSeconds)),
                        _buildInfoRow(
                            'Interruption Time',
                            _formatDuration(
                                record.totalInterruptionTimeSeconds)),
                        _buildInfoRow(
                            'Total Time',
                            _formatDuration(record.totalProductionTimeSeconds +
                                record.totalInterruptionTimeSeconds)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Text(
                'Interruptions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Interruptions table
              record.interruptions.isEmpty
                  ? const Text('No interruptions recorded')
                  : Table(
                      border: TableBorder.all(color: Colors.grey.shade300),
                      columnWidths: const {
                        0: FlexColumnWidth(2), // Type
                        1: FlexColumnWidth(2), // Start Time
                        2: FlexColumnWidth(2), // End Time
                        3: FlexColumnWidth(1), // Duration
                        4: FlexColumnWidth(3), // Notes
                      },
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(
                            color: Colors.black12,
                          ),
                          children: [
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Type',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Start Time',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('End Time',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Duration',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Notes',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        ...record.interruptions.map((interruption) {
                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(interruption.typeName),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(DateFormat('yyyy-MM-dd HH:mm:ss')
                                    .format(interruption.startTime)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: interruption.endTime != null
                                    ? Text(DateFormat('yyyy-MM-dd HH:mm:ss')
                                        .format(interruption.endTime!))
                                    : const Text('N/A'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(_formatDuration(
                                    interruption.durationSeconds)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(interruption.notes ?? 'No notes'),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
          Expanded(child: Text(value)),
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
