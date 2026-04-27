import 'package:flutter/material.dart';

import '../../../core/session/app_session_scope.dart';
import 'institution_shell_page.dart';
import 'professional_shell_page.dart';

class AppShellPage extends StatelessWidget {
  const AppShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);

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
