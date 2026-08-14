import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets.dart';
import '../cabinet_provider.dart';
import '../models/cabinet.dart';
import '../pairing/find_cabinet_screen.dart';
import '../widgets/cabinet_list_tile.dart';
import 'cabinet_detail_screen.dart';

/// The "Cabinets" tab: lists every paired cabinet with connect (pair) and
/// disconnect (unpair) available, and lets you tap into a cabinet for its
/// full details and controls.
class CabinetsListScreen extends StatelessWidget {
  const CabinetsListScreen({super.key});

  void _openFindCabinet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FindCabinetScreen()),
    );
  }

  void _openDetail(BuildContext context, Cabinet cabinet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CabinetDetailScreen(cabinetId: cabinet.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CabinetProvider>();
    final cabinets = provider.cabinets;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: cabinets.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _openFindCabinet(context),
              backgroundColor: AppColors.primary,
              tooltip: 'Connect a cabinet',
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                  children: [
                    Text(
                      'My Cabinets',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (cabinets.isEmpty)
                      _EmptyCabinetsView(
                        onFindCabinet: () => _openFindCabinet(context),
                      )
                    else
                      for (final cabinet in cabinets)
                        CabinetListTile(
                          cabinet: cabinet,
                          onTap: () => _openDetail(context, cabinet),
                        ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Empty State: No Cabinets Paired ─────────────────────────────
class _EmptyCabinetsView extends StatelessWidget {
  final VoidCallback onFindCabinet;

  const _EmptyCabinetsView({required this.onFindCabinet});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashedBorderBox(
          color: AppColors.textHint,
          padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 28),
          child: Text(
            'Your smart medicine cabinet would appear here after it is paired to this application.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppButton(label: 'Find Cabinet', onPressed: onFindCabinet),
      ],
    );
  }
}
