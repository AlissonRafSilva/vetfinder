import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/session/app_session_controller.dart';
import '../core/session/app_session_scope.dart';
import '../core/theme/app_theme.dart';
import '../features/shell/presentation/app_shell_page.dart';

class VetFinderApp extends StatefulWidget {
  const VetFinderApp({super.key});

  @override
  State<VetFinderApp> createState() => _VetFinderAppState();
}

class _VetFinderAppState extends State<VetFinderApp> {
  final AppSessionController _sessionController = AppSessionController();

  @override
  Widget build(BuildContext context) {
    return AppSessionScope(
      controller: _sessionController,
      child: MaterialApp(
        title: 'VetFinder',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [
          Locale('pt', 'BR'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AppShellPage(),
      ),
    );
  }
}
