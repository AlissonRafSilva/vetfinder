import 'package:flutter/widgets.dart';

import 'app_session_controller.dart';

class AppSessionScope extends InheritedNotifier<AppSessionController> {
  const AppSessionScope({
    super.key,
    required AppSessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppSessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppSessionScope>();
    assert(scope != null, 'AppSessionScope não encontrado no contexto.');
    return scope!.notifier!;
  }
}
