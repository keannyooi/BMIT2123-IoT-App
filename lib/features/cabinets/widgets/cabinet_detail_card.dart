import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets.dart';
import '../cabinet_provider.dart';
import '../models/cabinet.dart';
import '../../logs/logs_provider.dart';
import 'environment_reading_tile.dart';

/// Full detail view for a single cabinet, including live readings and the
/// connect/disconnect (lock/unlock, unpair) controls. Used by
/// [CabinetDetailScreen] - kept out of the Dashboard, which is read-only.
class CabinetDetailCard extends StatelessWidget {
  final Cabinet cabinet;

  const CabinetDetailCard({super.key, required this.cabinet});

  String _formatRegistered(DateTime? time) {
    if (time == null) return 'Registered: --';
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final year = time.year.toString();
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final hour = hour12.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'pm' : 'am';
    return 'Registered: $month/$day/$year $hour:$minute:$second$period';
  }

  Future<void> _toggleLock(BuildContext context, bool locked) async {
    final provider = context.read<CabinetProvider>();
    final err = await provider.setLocked(cabinet.id, !locked);
    if (!context.mounted) return;
    if (err != null) {
      showErrorSnack(context, err);
    } else {
      showSuccessSnack(
        context,
        !locked ? 'Cabinet locked.' : 'Cabinet unlocked.',
      );
    }
  }

  void _confirmDisconnect(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Disconnect Cabinet',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.error,
          ),
        ),
        content: Text(
          'This will unpair "${cabinet.name}" from this application. You can pair it again later.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final err =
                  await context.read<CabinetProvider>().deleteCabinet(cabinet.id);
              if (!context.mounted) return;
              if (err != null) {
                showErrorSnack(context, err);
              } else {
                Navigator.pop(context);
                showSuccessSnack(context, 'Cabinet disconnected.');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(130, 40),
            ),
            child: const Text('Confirm'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(minimumSize: const Size(130, 40)),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CabinetProvider>();
    final logsProvider = context.watch<LogsProvider>();
    final latestTelemetry = logsProvider.latestTelemetry;
    
    final locked = cabinet.locked;
    final refreshing = provider.isRefreshing(cabinet.id);
    final updatingLock = provider.isUpdatingLock(cabinet.id);

    // Use live telemetry if it's more recent than the cabinet's cached reading
    final temperature = latestTelemetry != null && 
        (cabinet.lastUpdated == null || latestTelemetry.timestamp.isAfter(cabinet.lastUpdated!))
        ? latestTelemetry.temperature 
        : cabinet.temperature;
        
    final humidity = latestTelemetry != null && 
        (cabinet.lastUpdated == null || latestTelemetry.timestamp.isAfter(cabinet.lastUpdated!))
        ? latestTelemetry.humidity 
        : cabinet.humidity;

    final stockStatus = latestTelemetry != null && 
        (cabinet.lastUpdated == null || latestTelemetry.timestamp.isAfter(cabinet.lastUpdated!))
        ? latestTelemetry.stockStatus 
        : cabinet.stockStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabinet Info Card ────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: AppColors.cardBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cabinet.name,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ID: ${cabinet.cabinetId}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Status: ',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            locked ? 'LOCKED' : 'UNLOCKED',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: locked ? AppColors.error : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatRegistered(cabinet.pairedAt),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Environment Readings ─────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Current Environment Readings',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: refreshing
                  ? null
                  : () => provider.refreshReadings(context.read<LogsProvider>(), cabinet.id),
              icon: refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
              tooltip: 'Refresh readings',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: EnvironmentReadingTile(
                icon: Icons.thermostat_rounded,
                label: 'Temperature',
                value: temperature != null
                    ? '${temperature.toStringAsFixed(2)}°C'
                    : '--',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: EnvironmentReadingTile(
                icon: Icons.water_drop_rounded,
                label: 'Humidity',
                value: humidity != null
                    ? '${humidity.toStringAsFixed(2)}%'
                    : '--',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: EnvironmentReadingTile(
                icon: Icons.inventory_rounded,
                label: 'Stock Status',
                value: stockStatus.toUpperCase(),
              ),
            ),
          ]
        ),
        const SizedBox(height: 28),

        // ── Controls (connect/disconnect live here, not on the Dashboard) ──
        Text(
          'Controls',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                updatingLock ? null : () => _toggleLock(context, locked),
            style: ElevatedButton.styleFrom(
              backgroundColor: locked ? AppColors.success : AppColors.textSecondary,
            ),
            child: updatingLock
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(locked ? 'Unlock Cabinet' : 'Lock Cabinet'),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _confirmDisconnect(context),
            icon: const Icon(Icons.link_off_rounded, size: 18),
            label: const Text('Disconnect Cabinet'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          ),
        ),
      ],
    );
  }
}
