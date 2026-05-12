import 'package:flutter/material.dart';

import '../../admin/presentation/admin_dashboard_page.dart';
import '../../auth/presentation/auth_gate_page.dart';

class AdminShellPage extends StatefulWidget {
  const AdminShellPage({super.key});

  @override
  State<AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends State<AdminShellPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      AuthGatePage(),
      AdminDashboardPage(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.login_rounded),
            label: 'Entrada',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_rounded),
            label: 'Validacoes',
          ),
        ],
      ),
    );
  }
}
