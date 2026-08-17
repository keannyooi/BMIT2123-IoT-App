import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import '../logs/logs_provider.dart';
import '../auth/auth_provider.dart';
import '../../core/app_colors.dart';

enum ReportType { activity, denied, environmental }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = false;
  int _currentPage = 1;
  static const int _itemsPerPage = 5;
  ReportType _selectedReport = ReportType.activity;
  DateTime? _selectedDate;
  String? _lastCabinetId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cabinetId = context.read<AuthProvider>().profile?['cabinetId'];
      _lastCabinetId = cabinetId;
      if (cabinetId != null) {
        _fetchData();
      }
    });
  }

  Future<void> _fetchData() async {
    final auth = context.read<AuthProvider>();
    final cabinetId = auth.profile?['cabinetId'];

    if (cabinetId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });
    
    if (_selectedReport == ReportType.environmental) {
      await context.read<LogsProvider>().fetchTelemetryLogs(cabinetId);
    } else {
      await context.read<LogsProvider>().fetchAccessLogs(cabinetId);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final logsProvider = context.watch<LogsProvider>();
    final auth = context.watch<AuthProvider>();
    final cabinetId = auth.profile?['cabinetId'];

    if (cabinetId != _lastCabinetId) {
      _lastCabinetId = cabinetId;
      if (cabinetId != null) {
        Future.microtask(() => _fetchData());
      }
    }

    if (cabinetId == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Reports', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: _buildNoCabinetState(),
      );
    }

    // 1. Get unique months available in logs
    final Map<String, DateTime> availableMonths = {};
    final allAccessLogs = logsProvider.accessLogs;
    final allTelemetry = logsProvider.telemetryLogs;

    for (var log in allAccessLogs) {
      final key = DateFormat('yyyy-MM').format(log.timestamp);
      if (!availableMonths.containsKey(key)) {
        availableMonths[key] = DateTime(log.timestamp.year, log.timestamp.month);
      }
    }
    for (var log in allTelemetry) {
      final key = DateFormat('yyyy-MM').format(log.timestamp);
      if (!availableMonths.containsKey(key)) {
        availableMonths[key] = DateTime(log.timestamp.year, log.timestamp.month);
      }
    }
    
    final sortedMonths = availableMonths.values.toList()..sort((a, b) => b.compareTo(a));

    // 2. Set the report date
    DateTime reportDate = _selectedDate ?? (sortedMonths.isNotEmpty ? sortedMonths.first : DateTime.now());
    
    // Data Preparation based on Report Type
    List<AccessLog> monthAccessLogs = allAccessLogs.where((l) => 
      l.timestamp.year == reportDate.year && l.timestamp.month == reportDate.month
    ).toList();

    List<TelemetryLog> monthTelemetry = allTelemetry.where((t) =>
      t.timestamp.year == reportDate.year && t.timestamp.month == reportDate.month
    ).toList();

    // Filtered Content
    List<dynamic> filteredData = [];
    if (_selectedReport == ReportType.activity) {
      filteredData = monthAccessLogs;
    } else if (_selectedReport == ReportType.denied) {
      filteredData = monthAccessLogs.where((l) => !l.accessResult.toLowerCase().contains('granted')).toList();
    } else {
      filteredData = monthTelemetry;
    }

    // Stats calculation
    int totalAttempts = 0;
    int granted = 0;
    int denied = 0;
    double ratio = 0.0;
    String mostRepeatedRfid = 'N/A';

    double avgTemp = 0, maxTemp = -999, minTemp = 999;
    double avgHum = 0, maxHum = -999, minHum = 999;

    if (_selectedReport == ReportType.activity || _selectedReport == ReportType.denied) {
      totalAttempts = filteredData.length;
      granted = filteredData.where((l) => (l as AccessLog).accessResult.toLowerCase().contains('granted')).length;
      denied = totalAttempts - granted;
      ratio = totalAttempts == 0 ? 0.0 : (granted / totalAttempts * 100);

      if (filteredData.isNotEmpty) {
        final counts = <String, int>{};
        for (var log in filteredData) {
          counts[(log as AccessLog).cardId] = (counts[log.cardId] ?? 0) + 1;
        }
        mostRepeatedRfid = counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }
    } else {
      if (monthTelemetry.isNotEmpty) {
        double sumTemp = 0;
        double sumHum = 0;
        for (var t in monthTelemetry) {
          sumTemp += t.temperature;
          sumHum += t.humidity;
          if (t.temperature > maxTemp) maxTemp = t.temperature;
          if (t.temperature < minTemp) minTemp = t.temperature;
          if (t.humidity > maxHum) maxHum = t.humidity;
          if (t.humidity < minHum) minHum = t.humidity;
        }
        avgTemp = sumTemp / monthTelemetry.length;
        avgHum = sumHum / monthTelemetry.length;
      }
    }

    // Pagination
    final totalPages = (filteredData.length / _itemsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final paginatedData = filteredData.isNotEmpty
        ? filteredData.sublist(startIndex, endIndex > filteredData.length ? filteredData.length : endIndex)
        : [];

    // Chart Data Preparation
    final daysInMonth = DateTime(reportDate.year, reportDate.month + 1, 0).day;
    final dailyActivity = List.generate(daysInMonth, (index) => 0);
    final dailyTemp = List.generate(daysInMonth, (index) => 0.0);
    final dailyHum = List.generate(daysInMonth, (index) => 0.0);
    final dailyTempCounts = List.generate(daysInMonth, (index) => 0);

    if (_selectedReport == ReportType.environmental) {
      for (var t in monthTelemetry) {
        int day = t.timestamp.day - 1;
        dailyTemp[day] += t.temperature;
        dailyHum[day] += t.humidity;
        dailyTempCounts[day]++;
      }
      for (int i = 0; i < daysInMonth; i++) {
        if (dailyTempCounts[i] > 0) {
          dailyTemp[i] /= dailyTempCounts[i];
          dailyHum[i] /= dailyTempCounts[i];
        }
      }
    } else {
      for (var log in (filteredData as List<AccessLog>)) {
        dailyActivity[log.timestamp.day - 1]++;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Reports', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: AppColors.surface,
            onPressed: _fetchData,
          )
        ],
      ),
      body: _isLoading || logsProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReportHeader(reportDate, sortedMonths, cabinetId),
                    const SizedBox(height: 20),

                    if (_selectedReport == ReportType.activity)
                      _buildStatsTable(totalAttempts, granted, denied, ratio)
                    else if (_selectedReport == ReportType.denied)
                      _buildDeniedStatsCard(totalAttempts, mostRepeatedRfid)
                    else
                      _buildEnvironmentalStatsTable(avgTemp, maxTemp, minTemp, avgHum, maxHum, minHum),
                    
                    const SizedBox(height: 20),

                    if (_selectedReport == ReportType.environmental)
                      _buildDualLineGraph(dailyTemp, dailyHum, daysInMonth)
                    else
                      _buildLineGraph(
                        dailyActivity.toList(),
                        dailyActivity.isEmpty ? 0 : dailyActivity.reduce((a, b) => a > b ? a : b).toDouble(), 
                        daysInMonth, 
                        _selectedReport == ReportType.activity ? 'Daily Activity' : 'Daily Denied Attempts'
                      ),

                    const SizedBox(height: 24),

                    Text(
                      _selectedReport == ReportType.activity ? 'Access Details' 
                        : _selectedReport == ReportType.denied ? 'Denied Attempts' 
                        : 'Environmental Readings',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_selectedReport == ReportType.activity)
                      _buildAccessList(paginatedData.cast<AccessLog>())
                    else if (_selectedReport == ReportType.denied)
                      _buildDeniedAccessList(paginatedData.cast<AccessLog>())
                    else
                      _buildEnvironmentalList(paginatedData.cast<TelemetryLog>()),
                    const SizedBox(height: 16),
                    _buildPaginationControls(totalPages),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPaginationControls(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageButton(
          icon: Icons.first_page,
          onPressed: _currentPage > 1 ? () => setState(() => _currentPage = 1) : null,
          enabled: _currentPage > 1,
        ),
        const SizedBox(width: 8),
        _buildPageButton(
          icon: Icons.chevron_left,
          onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          enabled: _currentPage > 1,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Page $_currentPage of $totalPages',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        _buildPageButton(
          icon: Icons.chevron_right,
          onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
          enabled: _currentPage < totalPages,
        ),
        const SizedBox(width: 8),
        _buildPageButton(
          icon: Icons.last_page,
          onPressed: _currentPage < totalPages ? () => setState(() => _currentPage = totalPages) : null,
          enabled: _currentPage < totalPages,
        ),
      ],
    );
  }

  Widget _buildPageButton({required IconData icon, required VoidCallback? onPressed, required bool enabled}) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? AppColors.surface : AppColors.accent.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        color: enabled ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildReportHeader(DateTime selectedDate, List<DateTime> availableMonths, String cabinetId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              canvasColor: AppColors.primary,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ReportType>(
                value: _selectedReport,
                icon: const Icon(Icons.expand_more, color: Colors.white),
                isDense: true,
                dropdownColor: AppColors.primary,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: (ReportType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedReport = newValue;
                      _currentPage = 1;
                    });
                    _fetchData();
                  }
                },
                items: const [
                  DropdownMenuItem(value: ReportType.activity, child: Text('Cabinet Access Activity')),
                  DropdownMenuItem(value: ReportType.denied, child: Text('Denied Access Report')),
                  DropdownMenuItem(value: ReportType.environmental, child: Text('Environmental Conditions')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cabinet ID: $cabinetId',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(canvasColor: AppColors.primary),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DateTime>(
                value: selectedDate,
                icon: const Icon(Icons.expand_more, color: Colors.white, size: 20),
                isDense: true,
                dropdownColor: AppColors.primary,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
                onChanged: (DateTime? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedDate = newValue;
                      _currentPage = 1;
                    });
                  }
                },
                items: availableMonths.map((date) {
                  return DropdownMenuItem<DateTime>(
                    value: date,
                    child: Text(DateFormat('MMMM yyyy').format(date)),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTable(int total, int granted, int denied, double ratio) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatRow('Total Access Attempts', total.toString(), isBold: true),
            const Divider(height: 20),
            _buildStatRow('Granted', granted.toString(), valueColor: AppColors.success),
            _buildStatRow('Denied', denied.toString(), valueColor: AppColors.error),
            _buildStatRow('Granted Ratio (%)', ratio.toStringAsFixed(2)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineGraph(List<int> dailyCounts, double max, int days, String title) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1.7,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 1,
                  maxX: days.toDouble(),
                  minY: 0,
                  maxY: (max == 0 ? 5 : max + 2),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (max > 0)
                        HorizontalLine(
                          y: max,
                          color: Colors.orange.withValues(alpha: 0.6),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                            labelResolver: (line) => 'MAX: ${max.toInt()}',
                          ),
                        ),
                    ],
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: dailyCounts.asMap().entries.map((e) => FlSpot(e.key + 1.0, e.value.toDouble())).toList(),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)),
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

  Widget _buildAccessList(List<AccessLog> logs) {
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text('No access records for this period', style: GoogleFonts.poppins(color: Colors.grey)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final log = logs[index];
        final isSuccess = log.accessResult.toLowerCase().contains('granted') || 
                          log.accessResult.toLowerCase().contains('success');
        
        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (isSuccess ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
              child: Icon(isSuccess ? Icons.check : Icons.close, color: isSuccess ? AppColors.success : AppColors.error),
            ),
            title: Text('Card ID: ${log.cardId}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(DateFormat('MMM dd, HH:mm').format(log.timestamp), style: GoogleFonts.poppins(fontSize: 12)),
            trailing: Text(
              log.accessResult.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSuccess ? AppColors.success : AppColors.error,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnvironmentalStatsTable(double avgT, double maxT, double minT, double avgH, double maxH, double minH) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatRow('Average Temperature', '${avgT.toStringAsFixed(1)}°C', isBold: true, valueColor: Colors.orange),
            _buildStatRow('Temp Range', '${minT == 999 ? 0 : minT.toStringAsFixed(1)}°C - ${maxT == -999 ? 0 : maxT.toStringAsFixed(1)}°C'),
            const Divider(height: 20),
            _buildStatRow('Average Humidity', '${avgH.toStringAsFixed(1)}%', isBold: true, valueColor: Colors.blue),
            _buildStatRow('Humidity Range', '${minH == 999 ? 0 : minH.toStringAsFixed(1)}% - ${maxH == -999 ? 0 : maxH.toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildDualLineGraph(List<double> temp, List<double> hum, int days) {
    double maxVal = 100; // Humidity max is 100
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildLegendItem('Temperature (°C)', Colors.orange),
                const SizedBox(width: 16),
                _buildLegendItem('Humidity (%)', Colors.blue),
              ],
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1.7,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 1,
                  maxX: days.toDouble(),
                  minY: 0,
                  maxY: maxVal,
                  lineBarsData: [
                    LineChartBarData(
                      spots: temp.asMap().entries.where((e) => e.value > 0).map((e) => FlSpot(e.key + 1.0, e.value)).toList(),
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: hum.asMap().entries.where((e) => e.value > 0).map((e) => FlSpot(e.key + 1.0, e.value)).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
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

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEnvironmentalList(List<TelemetryLog> logs) {
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text('No telemetry records for this period', style: GoogleFonts.poppins(color: Colors.grey)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final log = logs[index];
        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.accent,
              child: Icon(Icons.sensors, color: Colors.white, size: 20),
            ),
            title: Text(
              '${log.temperature.toStringAsFixed(1)}°C | ${log.humidity.toStringAsFixed(1)}% Humidity',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(DateFormat('MMM dd, HH:mm:ss').format(log.timestamp), style: GoogleFonts.poppins(fontSize: 12)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: log.stockStatus.toLowerCase() == 'normal' ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                log.stockStatus.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: log.stockStatus.toLowerCase() == 'normal' ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeniedStatsCard(int totalDenied, String mostRepeatedRfid) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatRow('Total Denied Events', totalDenied.toString(), isBold: true, valueColor: AppColors.error),
            const Divider(height: 20),
            Text(
                "Most Repeated RFID Card Code",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
            ),
            Text(
              mostRepeatedRfid,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeniedAccessList(List<AccessLog> logs) {
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text('No denied access records for this period', style: GoogleFonts.poppins(color: Colors.grey)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final log = logs[index];
        
        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.image_outlined, color: AppColors.primary),
                onPressed: () => _showImagePopup(log),
              ),
            ),
            title: Text(
              log.cardId,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              DateFormat('MMM dd, yyyy HH:mm').format(log.timestamp),
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  void _showImagePopup(AccessLog log) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Evidence Image', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            FutureBuilder<String>(
              future: log.imagePath.isEmpty 
                  ? Future.error('No image') 
                  : FirebaseStorage.instance.ref('cabinet-images/${log.cabinetId}/${log.imagePath}').getDownloadURL(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(snapshot.data!, fit: BoxFit.contain),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCabinetState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.kitchen, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Cabinet Paired',
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please pair a cabinet to view reports',
            style: GoogleFonts.poppins(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
