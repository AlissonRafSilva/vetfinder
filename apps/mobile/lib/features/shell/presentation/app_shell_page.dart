import 'package:flutter/material.dart';

import '../../../core/session/app_session_scope.dart';
import '../../auth/presentation/auth_gate_page.dart';
import 'admin_shell_page.dart';
import 'institution_shell_page.dart';
import 'professional_shell_page.dart';

class AppShellPage extends StatelessWidget {
  const AppShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);

    if (!session.isAuthenticated) {
      return const Scaffold(
        body: SafeArea(
          child: AuthGatePage(
            key: ValueKey('guest-auth-gate'),
          ),
        ),
      );
    }

    if (session.roleValue == 'ADMIN') {
      return const AdminShellPage(
        key: ValueKey('admin-shell'),
      );
    }

    if (session.isInstitutionUser) {
      return const InstitutionShellPage(
        key: ValueKey('institution-shell'),
      );
    }

    return const ProfessionalShellPage(
      key: ValueKey('professional-shell'),
    );
  }
}
