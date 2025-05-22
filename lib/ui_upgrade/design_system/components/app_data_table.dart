import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../responsive/responsive_breakpoints.dart';

/// A customized data table component that follows the design system guidelines.
///
/// The AppDataTable provides a consistent way to display tabular data across
/// the application with features like sorting, pagination, and responsive behavior.
class AppDataTable<T> extends StatefulWidget {
  /// List of columns to display in the table
  final List<AppDataColumn> columns;

  /// List of data rows to display
  final List<T> data;

  /// Function to build a row from a data item
  final List<DataCell> Function(T item, int index) rowBuilder;

  /// Function called when a row is tapped
  final void Function(T item)? onRowTap;

  /// Whether to show the pagination controls
  final bool showPagination;

  /// Number of rows per page when pagination is enabled
  final int rowsPerPage;

  /// Whether the table is sortable
  final bool sortable;

  /// Initial sort column index
  final int? initialSortColumnIndex;

  /// Initial sort direction
  final bool initialSortAscending;

  /// Whether to show the checkbox column for row selection
  final bool showCheckboxColumn;

  /// Function called when row selection changes
  final void Function(List<T> selectedItems)? onSelectChanged;

  /// Whether the table should be horizontally scrollable on smaller screens
  final bool horizontalScrollOnMobile;

  /// Custom empty state widget to show when there's no data
  final Widget? emptyStateWidget;

  /// Loading indicator to show when data is loading
  final Widget? loadingWidget;

  /// Whether the data is currently loading
  final bool isLoading;

  const AppDataTable({
    Key? key,
    required this.columns,
    required this.data,
    required this.rowBuilder,
    this.onRowTap,
    this.showPagination = true,
    this.rowsPerPage = 10,
    this.sortable = true,
    this.initialSortColumnIndex,
    this.initialSortAscending = true,
    this.showCheckboxColumn = false,
    this.onSelectChanged,
    this.horizontalScrollOnMobile = true,
    this.emptyStateWidget,
    this.loadingWidget,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<AppDataTable<T>> createState() => _AppDataTableState<T>();
}

class _AppDataTableState<T> extends State<AppDataTable<T>> {
  late int _currentPage;
  late int _rowsPerPage;
  late int? _sortColumnIndex;
  late bool _sortAscending;
  List<T> _selectedItems = [];
  List<T> _sortedData = [];

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _rowsPerPage = widget.rowsPerPage;
    _sortColumnIndex = widget.initialSortColumnIndex;
    _sortAscending = widget.initialSortAscending;
    _sortedData = List.from(widget.data);
  }

  @override
  void didUpdateWidget(covariant AppDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _sortedData = List.from(widget.data);
      _sort();
    }
  }

  void _sort() {
    if (_sortColumnIndex != null && widget.sortable) {
      final column = widget.columns[_sortColumnIndex!];
      if (column.onSort != null) {
        setState(() {
          _sortedData.sort((a, b) {
            final result = column.onSort!(a, b);
            return _sortAscending ? result : -result;
          });
        });
      }
    }
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sort();
    });
  }

  void _onSelectAll(bool? checked) {
    if (checked == null) return;

    setState(() {
      if (checked) {
        _selectedItems = List.from(_getCurrentPageItems());
      } else {
        _selectedItems = [];
      }
    });

    if (widget.onSelectChanged != null) {
      widget.onSelectChanged!(_selectedItems);
    }
  }

  void _onSelectRow(bool? selected, T item) {
    if (selected == null) return;

    setState(() {
      if (selected) {
        if (!_selectedItems.contains(item)) {
          _selectedItems.add(item);
        }
      } else {
        _selectedItems.remove(item);
      }
    });

    if (widget.onSelectChanged != null) {
      widget.onSelectChanged!(_selectedItems);
    }
  }

  List<T> _getCurrentPageItems() {
    if (!widget.showPagination) return _sortedData;

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage <= _sortedData.length)
        ? startIndex + _rowsPerPage
        : _sortedData.length;

    if (startIndex >= _sortedData.length) return [];
    return _sortedData.sublist(startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = AppTheme.of(context);

    if (widget.isLoading) {
      return widget.loadingWidget ??
          const Center(child: CircularProgressIndicator());
    }

    if (_sortedData.isEmpty) {
      return widget.emptyStateWidget ??
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No data available',
                style: appTheme.typography.body,
              ),
            ),
          );
    }

    final isSmallScreen = ResponsiveBreakpoints.of(context).isSmallScreen;

    final dataTable = DataTable(
      columns: widget.columns.map((column) {
        return DataColumn(
          label: column.label,
          tooltip: column.tooltip,
          numeric: column.numeric,
          onSort: widget.sortable && column.onSort != null
              ? (columnIndex, ascending) => _onSort(columnIndex, ascending)
              : null,
        );
      }).toList(),
      rows: _getCurrentPageItems().asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        return DataRow(
          selected: _selectedItems.contains(item),
          onSelectChanged: widget.showCheckboxColumn
              ? (selected) => _onSelectRow(selected, item)
              : null,
          cells: widget.rowBuilder(item, index),
          onLongPress:
              widget.onRowTap != null ? () => widget.onRowTap!(item) : null,
        );
      }).toList(),
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      showCheckboxColumn: widget.showCheckboxColumn,
      onSelectAll: widget.showCheckboxColumn ? _onSelectAll : null,
      dataRowHeight: 56.0,
      headingRowHeight: 56.0,
      horizontalMargin: 24.0,
      columnSpacing: 24.0,
      dividerThickness: 1.0,
      headingTextStyle: appTheme.typography.subtitle1.copyWith(
        fontWeight: FontWeight.w600,
        color: appTheme.colors.textPrimaryColor,
      ),
      dataTextStyle: appTheme.typography.body,
    );

    final paginationControls = widget.showPagination
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${_currentPage * _rowsPerPage + 1} to ${(_currentPage * _rowsPerPage + _getCurrentPageItems().length)} of ${_sortedData.length}',
                  style: appTheme.typography.caption,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                      tooltip: 'Previous page',
                    ),
                    Text(
                      '${_currentPage + 1} / ${(_sortedData.length / _rowsPerPage).ceil()}',
                      style: appTheme.typography.caption,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed:
                          (_currentPage + 1) * _rowsPerPage < _sortedData.length
                              ? () => setState(() => _currentPage++)
                              : null,
                      tooltip: 'Next page',
                    ),
                  ],
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        isSmallScreen && widget.horizontalScrollOnMobile
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: dataTable,
              )
            : dataTable,
        paginationControls,
      ],
    );
  }
}

class AppDataColumn<T> {
  /// The widget to display as the column header
  final Widget label;

  /// The tooltip text for the column header
  final String? tooltip;

  /// Whether the column contains numeric data
  final bool numeric;

  /// Function to sort the data for this column
  final int Function(T a, T b)? onSort;

  AppDataColumn({
    required this.label,
    this.tooltip,
    this.numeric = false,
    this.onSort,
  });
}

/// Example usage:
///
/// ```dart
/// AppDataTable<User>(
///   columns: [
///     AppDataColumn<User>(
///       label: Text('Name'),
///       onSort: (a, b) => a.name.compareTo(b.name),
///     ),
///     AppDataColumn<User>(
///       label: Text('Email'),
///       onSort: (a, b) => a.email.compareTo(b.email),
///     ),
///     AppDataColumn<User>(
///       label: Text('Age'),
///       numeric: true,
///       onSort: (a, b) => a.age.compareTo(b.age),
///     ),
///   ],
///   data: users,
///   rowBuilder: (user, index) => [
///     DataCell(Text(user.name)),
///     DataCell(Text(user.email)),
///     DataCell(Text(user.age.toString())),
///   ],
///   onRowTap: (user) {
///     print('Selected user: ${user.name}');
///   },
/// )
/// ```
