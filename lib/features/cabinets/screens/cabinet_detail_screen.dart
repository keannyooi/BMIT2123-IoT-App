import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../cabinet_provider.dart';
import '../widgets/cabinet_detail_card.dart';
import '../../logs/logs_provider.dart';

/// Full details for a single cabinet, reached by tapping it from the
/// Cabinets list. This is where connect/disconnect (lock/unlock, unpair)
/// controls live - the Dashboard only shows a read-only summary.
class CabinetDetailScreen extends StatefulWidget {
  final String cabinetId;

  const CabinetDetailScreen({super.key, required this.cabinetId});

  @override
  State<CabinetDetailScreen> createState() => _CabinetDetailScreenState();
}

class _CabinetDetailScreenState extends State<CabinetDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LogsProvider>().subscribeToTelemetryLogs(widget.cabinetId);
    });
  }

  @override
  void dispose() {
    context.read<LogsProvider>().unsubscribeFromTelemetryLogs();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cabinet = context.watch<CabinetProvider>().cabinetById(widget.cabinetId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cabinet Details'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: cabinet == null
            ? Center(
                child: Text(
                  'This cabinet is no longer available.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [CabinetDetailCard(cabinet: cabinet)],
              ),
      ),
    );
  }
}
