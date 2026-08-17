import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import "package:intl/intl.dart";
import 'package:fl_chart/fl_chart.dart';

import '../../core/app_colors.dart';
import '../../core/widgets.dart';
import '../cabinets/cabinet_provider.dart';
import '../auth/auth_provider.dart';
import '../logs/logs_provider.dart';
import '../cabinets/widgets/cabinet_list_tile.dart';

/// The Dashboard/home tab: a read-only overview of every paired cabinet.
/// Connect/disconnect and other controls intentionally live on the
/// Cabinets tab and cabinet detail screen instead.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = false;
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

    try {
      await Future.wait([
        context.read<LogsProvider>().fetchAccessLogs(cabinetId),
        context.read<LogsProvider>().fetchTelemetryLogs(cabinetId),
      ]);
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
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
    final provider = context.watch<CabinetProvider>();
    final auth = context.watch<AuthProvider>();
    final logsProvider = context.watch<LogsProvider>();
    final cabinetId = auth.profile?['cabinetId'];
    final cabinets = provider.cabinets;

    // Environmental graph data preparation: last 7 days including today
    final telemetry = logsProvider.telemetryLogs;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dailyTemp = List.generate(7, (index) => 0.0);
    final dailyHum = List.generate(7, (index) => 0.0);
    final dailyTempCounts = List.generate(7, (index) => 0);

    for (var t in telemetry) {
      final logDate = DateTime(t.timestamp.year, t.timestamp.month, t.timestamp.day);
      final dayDiff = today.difference(logDate).inDays;
      if (dayDiff >= 0 && dayDiff < 7) {
        int index = 6 - dayDiff; // index 6 is today, 0 is 6 days ago
        dailyTemp[index] += t.temperature;
        dailyHum[index] += t.humidity;
        dailyTempCounts[index]++;
      }
    }
    for (int i = 0; i < 7; i++) {
      if (dailyTempCounts[i] > 0) {
        dailyTemp[i] /= dailyTempCounts[i];
        dailyHum[i] /= dailyTempCounts[i];
      }
    }

    final isAnyLoading = _isLoading || provider.loading || logsProvider.isLoading;

    if (cabinetId != _lastCabinetId) {
      _lastCabinetId = cabinetId;
      if (cabinetId != null) {
        Future.microtask(() => _fetchData());
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                await provider.refreshCabinets();
                await _fetchData();
              },
              child: (isAnyLoading && cabinets.isEmpty)
                  ? ListView(
                      children: const [
                        SizedBox(height: 220),
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      children: [
                        Text(
                          'Dashboard',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Overview of every cabinet paired to this application.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (cabinets.isEmpty)
                          EmptyState(
                            icon: Icons.dashboard_outlined,
                            title: 'No Cabinets Yet',
                            subtitle:
                                'Connect a cabinet from the Cabinets tab to see its live status here.',
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final cabinet in cabinets)
                                CabinetListTile(cabinet: cabinet, showChevron: false),
                              const SizedBox(height: 32),
                              Text(
                                'Weekly Environmental Readings',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildDualLineGraph(dailyTemp, dailyHum, 7),
                              const SizedBox(height: 32),
                              Text(
                                'Recent Access Records',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildRecentAccessList(),
                            ],
                          ),
                      ],
                    ),
            ),
            if (isAnyLoading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAccessList() {
    final allLogs = context.watch<LogsProvider>().accessLogs;

    if (allLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text('No access records for this period', style: GoogleFonts.poppins(color: Colors.grey)),
        ),
      );
    }

    // Sort all available logs by timestamp (newest first) and take the top 5
    final recentLogs = List.from(allLogs)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (recentLogs.length > 5) {
      recentLogs.removeRange(5, recentLogs.length);
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentLogs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final log = recentLogs[index];
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

  Widget _buildDualLineGraph(List<double> temp, List<double> hum, int days) {
    final now = DateTime.now();
    final dayLabels = List.generate(days, (i) {
      // Generate labels backwards from today
      final date = now.subtract(Duration(days: days - 1 - i));
      return DateFormat.E().format(date);
    });

    double maxVal = 100;
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
                        interval: 1,
                        getTitlesWidget: (val, meta) {
                          int index = val.toInt() - 1;
                          if (index >= 0 && index < dayLabels.length) {
                            return SideTitleWidget(
                              meta: meta,
                              space: 8,
                              child: Text(dayLabels[index], style: const TextStyle(fontSize: 10)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (val, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(val.toInt().toString(), style: const TextStyle(fontSize: 10)),
                        ),
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
}
