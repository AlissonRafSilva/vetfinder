import 'package:flutter/foundation.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/app_user_role.dart';
import '../../features/auth/domain/auth_result.dart';

class AppSessionController extends ChangeNotifier {
  AppSessionController({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;

  AuthResult? _currentSession;

  AuthResult? get currentSession => _currentSession;
  bool get isAuthenticated => _currentSession?.accessToken != null;
  String? get accessToken => _currentSession?.accessToken;
  String? get email => _currentSession?.email;
  String? get userId => _currentSession?.userId;
  String? get status => _currentSession?.status;
  String? get roleValue => _currentSession?.role;

  bool get canApplyToOpportunities {
    return roleValue == AppUserRole.veterinarian.apiValue ||
        roleValue == AppUserRole.intern.apiValue;
  }

  bool get isInstitutionUser {
    return roleValue == AppUserRole.clinic.apiValue ||
        roleValue == AppUserRole.hospital.apiValue;
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final result = await _authRepository.login(
      email: email,
      password: password,
    );

    _currentSession = result;
    notifyListeners();
    return result;
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required AppUserRole role,
    String? phone,
  }) {
    return _authRepository.register(
      email: email,
      password: password,
      role: role,
      phone: phone,
    );
  }

  void logout() {
    _currentSession = null;
    notifyListeners();
  }
}
