import 'package:flutter/material.dart';

import '../../auth/presentation/auth_gate_page.dart';
import '../../opportunities/presentation/opportunities_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../schedule/presentation/schedule_page.dart';

class ProfessionalShellPage extends StatefulWidget {
  const ProfessionalShellPage({super.key});

  @override
  State<ProfessionalShellPage> createState() => _ProfessionalShellPageState();
}

class _ProfessionalShellPageState extends State<ProfessionalShellPage> {
  int _currentIndex = 0;

  static const _pages = [
    AuthGatePage(),
    OpportunitiesPage(),
    SchedulePage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.login_rounded),
            label: 'Entrada',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            label: 'Plantoes',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
