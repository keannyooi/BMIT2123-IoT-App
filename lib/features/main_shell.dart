import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';

// import 'package:waste_tracker/features/jiaqin/bins/bin_list_screen.dart';
// import 'package:waste_tracker/features/keanwei/wastelogs/wastelog_create_screen.dart';
import 'logs/access_log_list_screen.dart';
import 'auth/profile_screen.dart';
import 'reports/reports_screen.dart';
import 'cabinets/screens/cabinets_list_screen.dart';
import 'dashboard/dashboard_screen.dart';
// import 'zijie/goals/goal_plan_screen.dart';

// ── Placeholders for WIP modules ────────────────────────────
class Placeholder extends StatelessWidget {
  const Placeholder({super.key});

  @override
  Widget build(BuildContext context) {
    return _Placeholder(
      icon: Icons.dashboard_outlined,
      label: 'Placeholder',
      color: AppColors.warning,
    );
  }
}

// ── Generic placeholder widget ────────────────────────────────
class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Placeholder({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Coming soon',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Main Shell ────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Tab order: Dashboard, Cabinets, Logs, Reports, Notifications, Profile
  final List<Widget> _screens = const [
    DashboardScreen(),
    CabinetsListScreen(),
    AccessLogListScreen(),
    ReportsScreen(),
    Placeholder(),
    ProfileScreen()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Cabinets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storage_outlined),
            activeIcon: Icon(Icons.storage),
            label: 'Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}