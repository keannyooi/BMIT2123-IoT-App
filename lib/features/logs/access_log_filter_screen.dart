import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

class AccessLogFilter {
  final String? accessResult;

  AccessLogFilter({
    this.accessResult
  });

  bool get isEmpty => accessResult == null;
}

class AccessLogFilterScreen extends StatefulWidget {
  final AccessLogFilter? initialFilter;
  const AccessLogFilterScreen({super.key, this.initialFilter});

  @override
  State<AccessLogFilterScreen> createState() => AccessLogFilterScreenState();
}

class AccessLogFilterScreenState extends State<AccessLogFilterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _weightFromController = TextEditingController();
  final TextEditingController _weightToController = TextEditingController();
  String? _selectedAccessResult;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _selectedAccessResult = widget.initialFilter!.accessResult;
    }
  }

  @override
  void dispose() {
    _weightFromController.dispose();
    _weightToController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.keyboard_backspace, size: 32),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Filter Access Logs',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // Access Result Dropdown
                        _buildDropdown<String>(
                          label: 'Access Result',
                          value: _selectedAccessResult,
                          items: [
                            DropdownMenuItem(value: "granted", child: Text("Granted")),
                            DropdownMenuItem(value: "denied", child: Text("Denied"))
                          ],
                          onChanged: (val) => setState(() => _selectedAccessResult = val),
                        ),

                        const Spacer(),

                        // Apply Filter Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              if (!_formKey.currentState!.validate()) return;

                              final filter = AccessLogFilter(
                                accessResult: _selectedAccessResult,
                              );
                              Navigator.pop(context, filter);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF38D366), // Bright green
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: Text(
                              'Apply Filter',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            errorStyle: GoogleFonts.poppins(fontSize: 10),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
        ),
        Positioned(
          top: -10,
          left: 12,
          child: Container(
            color: const Color(0xFFF1FBE9),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.purple.shade200,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
