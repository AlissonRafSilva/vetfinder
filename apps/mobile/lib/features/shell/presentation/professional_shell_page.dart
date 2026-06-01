import 'package:flutter/material.dart';

import '../../auth/presentation/auth_gate_page.dart';
import '../../engagements/presentation/professional_engagements_page.dart';
import '../../notifications/presentation/notifications_page.dart';
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
  final Set<int> _visitedIndexes = {0};
  final Map<int, Widget> _pages = {};

  @override
  Widget build(BuildContext context) {
    final keyboardIsOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: List.generate(
            6,
            (index) => _visitedIndexes.contains(index)
                ? _pageForIndex(index)
                : const SizedBox.shrink(),
          ),
        ),
      ),
      bottomNavigationBar: keyboardIsOpen
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _selectTab,
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
                  icon: Icon(Icons.handshake_rounded),
                  label: 'Contratos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_rounded),
                  label: 'Alertas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_rounded),
                  label: 'Perfil',
                ),
              ],
            ),
    );
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _visitedIndexes.add(index);
    });
  }

  Widget _pageForIndex(int index) {
    return _pages.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return AuthGatePage(
            onOpenMarketplace: () => _selectTab(1),
            onOpenSchedule: () => _selectTab(2),
            onOpenProfile: () => _selectTab(5),
          );
        case 1:
          return const OpportunitiesPage();
        case 2:
          return const SchedulePage();
        case 3:
          return const ProfessionalEngagementsPage();
        case 4:
          return const NotificationsPage();
        case 5:
          return const ProfilePage();
        default:
          return const SizedBox.shrink();
      }
    });
  }
}
