import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../auth/auth_provider.dart';
import '../../core/app_colors.dart';
import 'logs_provider.dart';
import 'access_log_filter_screen.dart';

class AccessLogListScreen extends StatefulWidget {
  const AccessLogListScreen({super.key});

  @override
  State<AccessLogListScreen> createState() => _AccessLogListScreenState();
}

class _AccessLogListScreenState extends State<AccessLogListScreen> {
  late DateTime _baseDate, _selectedDate;
  late PageController _pageController;
  late int _initialPage;

  AccessLogFilter? _currentFilter;
  String _sortBy = 'time_desc';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _baseDate = DateTime(now.year, now.month, now.day);
    _selectedDate = _baseDate;
    _initialPage = _baseDate.difference(DateTime(2020, 1, 1)).inDays;
    _pageController = PageController(initialPage: _initialPage);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final logsProvider = context.read<LogsProvider>();

      final uid = context.read<AuthProvider>().userId;
      if (uid != null) {
        logsProvider.fetchAccessLogs("CAB0001");
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<AccessLog> _getFilteredLogsForDate(DateTime date) {
    final allAccessLogs = context.read<LogsProvider>().accessLogs;
    List<AccessLog> accessLogs = allAccessLogs.where((log) {
      final ld = log.timestamp;
      return ld.year == date.year && ld.month == date.month && ld.day == date.day;
    }).toList();

    if (_currentFilter != null) {
      accessLogs = accessLogs.where((log) {
        bool match = true;
        // if (_currentFilter!.weightFrom != null) match &= log.weight >= _currentFilter!.weightFrom!;
        // if (_currentFilter!.weightTo != null) match &= log.weight <= _currentFilter!.weightTo!;
        // if (_currentFilter!.typeId != null) match &= log.bin?.wasteType?.id == _currentFilter!.typeId;
        if (_currentFilter!.accessResult != null) match &= log.accessResult == _currentFilter!.accessResult;
        return match;
      }).toList();
    }

    switch (_sortBy) {
      case 'time_asc': accessLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp)); break;
      case 'time_desc': default: accessLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp)); break;
    }
    return accessLogs;
  }

  void _changeDate(int days) {
    _pageController.animateToPage(
      _pageController.page!.round() + days,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final dateOnlyPicked = DateTime(picked.year, picked.month, picked.day);
      final dateOnlyBase = DateTime(_baseDate.year, _baseDate.month, _baseDate.day);
      final difference = dateOnlyPicked.difference(dateOnlyBase).inDays;
      _pageController.jumpToPage(_initialPage + difference);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cabinet Access Logs'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Header Section ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Date Selector Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: DateTime(2020, 1, 1).isBefore(_selectedDate)
                            ? AppColors.surface
                            : AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.chevron_left,
                          color: DateTime(2020, 1, 1).isBefore(_selectedDate)
                              ? Colors.black54
                              : Colors.black26,
                        ),
                        onPressed: DateTime(2020, 1, 1).isBefore(_selectedDate)
                            ? () => _changeDate(-1)
                            : null,
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _formatDate(_selectedDate),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: _baseDate.isAfter(_selectedDate)
                            ? AppColors.surface
                            : AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          color: _baseDate.isAfter(_selectedDate)
                              ? Colors.black54
                              : Colors.black26,
                        ),
                        onPressed: _baseDate.isAfter(_selectedDate)
                            ? () => _changeDate(1)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filter and Add Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PopupMenuButton<String>(
                      initialValue: _sortBy,
                      onSelected: (String value) {
                        setState(() {
                          _sortBy = value;
                        });
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(value: 'time_desc', child: Text('Time (Desc)')),
                        const PopupMenuItem<String>(value: 'time_asc', child: Text('Time (Asc)')),
                      ],
                      child: _actionButton(
                        _getSortLabel(_sortBy),
                        Icons.keyboard_arrow_down,
                        null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _actionButton(
                      _currentFilter == null || _currentFilter!.isEmpty ? 'Apply Filter' : 'Remove Filter',
                      _currentFilter == null || _currentFilter!.isEmpty ? null : Icons.close,
                      () async {
                        AccessLogFilter? result;
                        if (_currentFilter == null || _currentFilter!.isEmpty) {
                          result = await Navigator.push<AccessLogFilter>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AccessLogFilterScreen(initialFilter: _currentFilter),
                            ),
                          );
                        }
                        else {
                          result = null;
                        }

                        setState(() {
                          _currentFilter = result;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── List Section ───────────────────────────────────────
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : PageView.builder(
                    controller: _pageController,
                    itemCount: _initialPage + 1,
                    onPageChanged: (index) {
                      setState(() {
                        _selectedDate = _baseDate.add(Duration(days: index - _initialPage));
                      });
                    },
                    itemBuilder: (context, index) {
                      final date = _baseDate.add(Duration(days: index - _initialPage));
                      final logs = _getFilteredLogsForDate(date);

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: logs.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                key: ValueKey(date),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: logs.length,
                                itemBuilder: (context, lIndex) {
                                  return _buildWasteCard(logs[lIndex]);
                                },
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) {
      return 'Today (${DateFormat('d/M/yyyy').format(date)})';
    }
    return DateFormat('EEEE (d/M/yyyy)').format(date);
  }

  String _getSortLabel(String value) {
    switch (value) {
      case 'time_asc': return 'Time (Asc)';
      case 'weight_desc': return 'Weight (Desc)';
      case 'weight_asc': return 'Weight (Asc)';
      case 'time_desc':
      default: return 'Time (Desc)';
    }
  }

  Widget _actionButton(String label, IconData? icon, VoidCallback? onTap) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (icon != null) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWasteCard(AccessLog log) {
    Color mainColor = log.accessResult == "granted" ? Colors.green : Colors.red;
    String accessResult = log.accessResult.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mainColor, width: 2),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 8,
              decoration: BoxDecoration(
                color: mainColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '[$accessResult]',
                          style: GoogleFonts.poppins(
                            color: mainColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.photo_outlined,
                              color: Colors.grey[600], size: 22),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Access Image', 
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            )),
                                          IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                        ],
                                      ),
                                    ),
                                    FutureBuilder<String>(
                                      future: FirebaseStorage.instance
                                          .ref('cabinet-images/${log.cabinetId}/${log.imagePath}')
                                          .getDownloadURL(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const SizedBox(
                                            height: 200,
                                            child: Center(child: CircularProgressIndicator()),
                                          );
                                        }
                                        if (snapshot.hasError) {
                                          return Padding(
                                            padding: const EdgeInsets.all(24.0),
                                            child: Column(
                                              children: [
                                                const Icon(Icons.image_not_supported_outlined, 
                                                    color: Colors.grey, size: 48),
                                                const SizedBox(height: 12),
                                                Text('Image not available',
                                                    style: GoogleFonts.poppins(color: Colors.grey)),
                                              ],
                                            ),
                                          );
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              snapshot.data!,
                                              fit: BoxFit.contain,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return const SizedBox(
                                                  height: 200,
                                                  child: Center(child: CircularProgressIndicator()),
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    Text(
                      "Accessed: ${DateFormat('dd/MM/yyyy, HH:mm').format(log.timestamp)}",
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        'ID: ${log.id}',
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_sweep_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No logs for this date',
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
