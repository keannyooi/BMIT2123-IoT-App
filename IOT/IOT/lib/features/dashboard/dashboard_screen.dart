import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/widgets.dart';
import '../cabinets/cabinet_provider.dart';
import '../cabinets/widgets/cabinet_list_tile.dart';

/// The Dashboard/home tab: a read-only overview of every paired cabinet.
/// Connect/disconnect and other controls intentionally live on the
/// Cabinets tab and cabinet detail screen instead.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CabinetProvider>();
    final cabinets = provider.cabinets;

    return Scaffold(
      backgroundColor: AppColors.paleBlue,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.refreshCabinets,
          child: provider.loading && cabinets.isEmpty
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
                      for (final cabinet in cabinets)
                        CabinetListTile(cabinet: cabinet, showChevron: false),
                  ],
                ),
        ),
      ),
    );
  }
}
