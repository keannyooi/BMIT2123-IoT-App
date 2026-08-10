import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/widgets.dart';
import 'access_log_provider.dart';
import 'models/access_log.dart';
import 'widgets/access_log_tile.dart';

const _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _dayHeader(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final target = DateTime(time.year, time.month, time.day);
  if (target == today) return 'Today';
  if (target == yesterday) return 'Yesterday';
  return '${_kMonths[time.month - 1]} ${time.day}, ${time.year}';
}

/// The "Logs" tab: who has been accessing the cabinet, organised by day
/// with simple granted/denied filtering.
class AccessLogsScreen extends StatelessWidget {
  const AccessLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccessLogProvider>();
    final logs = provider.logs;

    final grouped = <String, List<AccessLog>>{};
    for (final log in logs) {
      final key =
          log.timestamp == null ? 'Unknown Date' : _dayHeader(log.timestamp!);
      grouped.putIfAbsent(key, () => []).add(log);
    }

    return Scaffold(
      backgroundColor: AppColors.paleBlue,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.refresh,
          child: provider.loading && logs.isEmpty
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
                      'Access Logs',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'See who has been accessing your cabinets.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FilterBar(
                      current: provider.filter,
                      onChanged: provider.setFilter,
                    ),
                    const SizedBox(height: 20),
                    if (logs.isEmpty)
                      const EmptyState(
                        icon: Icons.fact_check_outlined,
                        title: 'No Access Logs Yet',
                        subtitle:
                            'Cabinet access attempts will appear here once your cabinet starts reporting them.',
                      )
                    else
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10, top: 4),
                          child: Text(
                            entry.key,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        for (final log in entry.value) AccessLogTile(log: log),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Granted / Denied / All Filter Bar ───────────────────────────
class _FilterBar extends StatelessWidget {
  final AccessLogFilter current;
  final ValueChanged<AccessLogFilter> onChanged;

  const _FilterBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: 'All',
          selected: current == AccessLogFilter.all,
          onTap: () => onChanged(AccessLogFilter.all),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Granted',
          selected: current == AccessLogFilter.granted,
          color: AppColors.success,
          onTap: () => onChanged(AccessLogFilter.granted),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Denied',
          selected: current == AccessLogFilter.denied,
          color: AppColors.error,
          onTap: () => onChanged(AccessLogFilter.denied),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.cardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
