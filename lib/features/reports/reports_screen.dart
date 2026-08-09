import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    // final provider = context.watch<LogsProvider>();

    return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Reports & Analytics'),
          elevation: 0,
        ),
        body: Column(
            children: []
        )
    );
  }
}