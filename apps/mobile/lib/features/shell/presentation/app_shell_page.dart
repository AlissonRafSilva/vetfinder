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
    final keyboardIsOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    if (!session.isAuthenticated) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: const SafeArea(
          child: AuthGatePage(
            key: ValueKey('guest-auth-gate'),
          ),
        ),
        bottomNavigationBar: keyboardIsOpen ? const SizedBox.shrink() : null,
      );
    }

    final sessionKey = '${session.roleValue ?? 'user'}:${session.userId ?? ''}';

    if (session.roleValue == 'ADMIN') {
      return AdminShellPage(
        key: ValueKey('admin-shell:$sessionKey'),
      );
    }

    if (session.isInstitutionUser) {
      return InstitutionShellPage(
        key: ValueKey('institution-shell:$sessionKey'),
      );
    }

    return ProfessionalShellPage(
      key: ValueKey('professional-shell:$sessionKey'),
    );
  }
}
