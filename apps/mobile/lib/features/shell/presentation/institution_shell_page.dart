import 'package:flutter/material.dart';

import '../../auth/presentation/auth_gate_page.dart';
import '../../engagements/presentation/institution_engagements_page.dart';
import '../../opportunities/presentation/institution_opportunities_page.dart';
import '../../opportunities/presentation/opportunities_page.dart';
import '../../profile/presentation/profile_page.dart';

class InstitutionShellPage extends StatefulWidget {
  const InstitutionShellPage({super.key});

  @override
  State<InstitutionShellPage> createState() => _InstitutionShellPageState();
}

class _InstitutionShellPageState extends State<InstitutionShellPage> {
  int _currentIndex = 0;

  static const _pages = [
    AuthGatePage(),
    OpportunitiesPage(),
    InstitutionOpportunitiesPage(),
    InstitutionEngagementsPage(),
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
            label: 'Disponiveis',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_history_rounded),
            label: 'Minhas vagas',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_rounded),
            label: 'Contratacoes',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
