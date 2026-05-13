class AuthResult {
  const AuthResult({
    required this.message,
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.email,
    this.role,
    this.status,
  });

  final String message;
  final String? accessToken;
  final String? refreshToken;
  final String? userId;
  final String? email;
  final String? role;
  final String? status;

  factory AuthResult.fromRegisterJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return AuthResult(
      message: json['message']?.toString() ?? 'Conta criada com sucesso.',
      userId: user?['id']?.toString(),
      email: user?['email']?.toString(),
      role: user?['role']?.toString(),
      status: user?['status']?.toString(),
    );
  }

  factory AuthResult.fromLoginJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return AuthResult(
      message: 'Login realizado com sucesso.',
      accessToken: json['accessToken']?.toString(),
      refreshToken: json['refreshToken']?.toString(),
      userId: user?['id']?.toString(),
      email: user?['email']?.toString(),
      role: user?['role']?.toString(),
      status: user?['status']?.toString(),
    );
  }

  factory AuthResult.fromUserJson(
    Map<String, dynamic> json, {
    required AuthResult currentSession,
  }) {
    return AuthResult(
      message: currentSession.message,
      accessToken: currentSession.accessToken,
      refreshToken: currentSession.refreshToken,
      userId: json['id']?.toString() ?? currentSession.userId,
      email: json['email']?.toString() ?? currentSession.email,
      role: json['role']?.toString() ?? currentSession.role,
      status: json['status']?.toString() ?? currentSession.status,
    );
  }
}
