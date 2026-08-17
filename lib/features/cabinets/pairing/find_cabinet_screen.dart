import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets.dart';
import '../cabinet_provider.dart';
import '../models/discovered_device.dart';

// ── Find Cabinet Screen ─────────────────────────────────────────
// Guides the user through discovering and pairing a nearby smart
// cabinet. There's no finalised hardware pairing protocol yet, so the
// scan itself is simulated by [CabinetProvider.scanForCabinets]; this
// screen only owns the UI/UX flow (scan → pick device → name it → pair).
class FindCabinetScreen extends StatefulWidget {
  const FindCabinetScreen({super.key});

  @override
  State<FindCabinetScreen> createState() => _FindCabinetScreenState();
}

class _FindCabinetScreenState extends State<FindCabinetScreen> {
  bool _scanning = true;
  List<DiscoveredCabinetDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _devices = [];
    });
    final results = await context.read<CabinetProvider>().scanForCabinets();
    if (!mounted) return;
    setState(() {
      _devices = results;
      _scanning = false;
    });
  }

  void _openConnectSheet(DiscoveredCabinetDevice device) {
    final nameCtrl = TextEditingController(text: 'My Cabinet');
    bool pairing = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
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
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connect Cabinet',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Text(
                        //   'ID: ${device.cabinetId}',
                        //   style: GoogleFonts.poppins(
                        //     fontSize: 12,
                        //     color: AppColors.textSecondary,
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          error!,
                          style: GoogleFonts.poppins(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              AppTextField(
                label: 'Cabinet Name',
                hint: 'e.g. Living Room Cabinet',
                controller: nameCtrl,
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Connect Cabinet',
                loading: pairing,
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    setSheetState(
                      () => error = 'Please enter a name for this cabinet.',
                    );
                    return;
                  }
                  setSheetState(() {
                    pairing = true;
                    error = null;
                  });

                  final err = await context.read<CabinetProvider>().pairCabinet(
                        discoveredDevice: device,
                        name: nameCtrl.text.trim(),
                      );
                  if (!ctx.mounted) return;

                  setSheetState(() => pairing = false);
                  if (err != null) {
                    setSheetState(() => error = err);
                  } else {
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    Navigator.pop(context);
                    showSuccessSnack(context, 'Cabinet connected successfully!');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Find Cabinet'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _startScan,
        child: _scanning ? _buildScanning() : _buildResults(),
      ),
    );
  }

  Widget _buildScanning() {
    return ListView(
      children: [
        const SizedBox(height: 90),
        Center(
          child: Column(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bluetooth_searching_rounded,
                        size: 30,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Scanning for nearby cabinets...',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Make sure your cabinet is powered on and within range.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_devices.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 40),
          EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No Cabinets Found',
            subtitle:
                'Make sure the cabinet is powered on, in range, and ready to connect.',
            buttonLabel: 'Scan Again',
            onButton: _startScan,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${_devices.length} cabinet${_devices.length == 1 ? '' : 's'} found nearby',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        for (final device in _devices)
          _DeviceTile(discoveredDevice: device, onTap: () => _openConnectSheet(device)),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: _startScan,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Scan Again'),
          ),
        ),
      ],
    );
  }
}

// ── Discovered Device Tile ──────────────────────────────────────
class _DeviceTile extends StatelessWidget {
  final DiscoveredCabinetDevice discoveredDevice;
  final VoidCallback onTap;

  const _DeviceTile({required this.discoveredDevice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
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
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    discoveredDevice.device.advName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(4, (i) {
                      return Container(
                        margin: const EdgeInsets.only(right: 3),
                        width: 4,
                        height: 6.0 + (i * 3),
                        decoration: BoxDecoration(
                          color: i < discoveredDevice.signalStrength
                              ? AppColors.primary
                              : AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(72, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}
