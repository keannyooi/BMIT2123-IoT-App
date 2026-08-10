import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets.dart';
import '../models/cabinet.dart';

/// Compact summary row for a cabinet, used in both the Cabinets list
/// (tappable, navigates to [CabinetDetailScreen]) and the read-only
/// Dashboard overview (not tappable, no chevron).
class CabinetListTile extends StatelessWidget {
  final Cabinet cabinet;
  final VoidCallback? onTap;
  final bool showChevron;

  const CabinetListTile({
    super.key,
    required this.cabinet,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final locked = cabinet.locked;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_services_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cabinet.name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ID: ${cabinet.cabinetId}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (cabinet.temperature != null || cabinet.humidity != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (cabinet.temperature != null) ...[
                          const Icon(
                            Icons.thermostat_rounded,
                            size: 14,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${cabinet.temperature!.toStringAsFixed(0)}°C',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (cabinet.humidity != null) ...[
                          const Icon(
                            Icons.water_drop_rounded,
                            size: 14,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${cabinet.humidity!.toStringAsFixed(0)}%',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(
              label: locked ? 'LOCKED' : 'UNLOCKED',
              color: locked ? AppColors.error : AppColors.success,
            ),
            if (showChevron) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
