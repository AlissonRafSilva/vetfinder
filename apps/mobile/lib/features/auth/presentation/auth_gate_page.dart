import 'package:flutter/material.dart';
import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/network/api_client.dart';
import '../domain/app_user_role.dart';
import '../domain/auth_result.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

enum _AuthMode { login, register }

class _AuthGatePageState extends State<AuthGatePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  AppUserRole _selectedRole = AppUserRole.veterinarian;
  bool _isSubmitting = false;
  String? _feedbackMessage;
  bool _isSuccessFeedback = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
    });

    try {
      final AuthResult result;
      final session = AppSessionScope.of(context);

      if (_mode == _AuthMode.login) {
        result = await session.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        result = await session.register(
          email: _emailController.text,
          password: _passwordController.text,
          phone: _phoneController.text,
          role: _selectedRole,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isSuccessFeedback = true;
        _feedbackMessage = _buildSuccessMessage(result);
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSuccessFeedback = false;
        _feedbackMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSuccessFeedback = false;
        _feedbackMessage = 'Nao foi possivel concluir a solicitacao agora.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _buildSuccessMessage(AuthResult result) {
    if (_mode == _AuthMode.login) {
      return 'Login concluido para ${result.email ?? 'o usuario selecionado'}.';
    }

    return result.message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = AppSessionScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  const Color(0xFF115E59),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VetFinder',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Conecte profissionais veterinarios e instituicoes para cobrir plantoes com rapidez.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Scrollable.ensureVisible(
                      _formKey.currentContext ?? context,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  child: const Text('Entrar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (session.isAuthenticated) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sessao ativa',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            session.email ?? 'Usuario autenticado',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Perfil: ${session.roleValue ?? 'indefinido'}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: session.logout,
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
          SectionHeader(
            title: _mode == _AuthMode.login ? 'Acesse sua conta' : 'Crie sua conta',
            subtitle: _mode == _AuthMode.login
                ? 'Use o mesmo backend do VetFinder para autenticar.'
                : 'O cadastro ja respeita os perfis aceitos pela API.',
          ),
          const SizedBox(height: 16),
          _AuthFormCard(
            formKey: _formKey,
            mode: _mode,
            selectedRole: _selectedRole,
            emailController: _emailController,
            passwordController: _passwordController,
            phoneController: _phoneController,
            isSubmitting: _isSubmitting,
            feedbackMessage: _feedbackMessage,
            isSuccessFeedback: _isSuccessFeedback,
            onModeChanged: (mode) {
              setState(() {
                _mode = mode;
                _feedbackMessage = null;
              });
            },
            onRoleChanged: (role) {
              setState(() {
                _selectedRole = role;
              });
            },
            onSubmit: _submit,
          ),
          const SizedBox(height: 28),
          const SectionHeader(
            title: 'Escolha seu perfil',
            subtitle: 'O onboarding muda conforme o tipo de usuario.',
          ),
          const SizedBox(height: 16),
          const _RoleOptionCard(
            icon: Icons.local_hospital_rounded,
            title: 'Veterinario volante',
            description: 'Receba plantoes proximos, convites e pagamentos pelo app.',
          ),
          const SizedBox(height: 14),
          const _RoleOptionCard(
            icon: Icons.school_rounded,
            title: 'Estagiario',
            description: 'Encontre oportunidades compativeis com sua formacao e agenda.',
          ),
          const SizedBox(height: 14),
          const _RoleOptionCard(
            icon: Icons.storefront_rounded,
            title: 'Clinica ou hospital',
            description: 'Publique demandas urgentes e feche plantoes com seguranca.',
          ),
        ],
      ),
    );
  }
}

class _AuthFormCard extends StatelessWidget {
  const _AuthFormCard({
    required this.formKey,
    required this.mode,
    required this.selectedRole,
    required this.emailController,
    required this.passwordController,
    required this.phoneController,
    required this.isSubmitting,
    required this.feedbackMessage,
    required this.isSuccessFeedback,
    required this.onModeChanged,
    required this.onRoleChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final _AuthMode mode;
  final AppUserRole selectedRole;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController phoneController;
  final bool isSubmitting;
  final String? feedbackMessage;
  final bool isSuccessFeedback;
  final ValueChanged<_AuthMode> onModeChanged;
  final ValueChanged<AppUserRole> onRoleChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<_AuthMode>(
                segments: const [
                  ButtonSegment(
                    value: _AuthMode.login,
                    label: Text('Entrar'),
                    icon: Icon(Icons.login_rounded),
                  ),
                  ButtonSegment(
                    value: _AuthMode.register,
                    label: Text('Cadastrar'),
                    icon: Icon(Icons.person_add_alt_1_rounded),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) {
                  onModeChanged(selection.first);
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  hintText: 'voce@exemplo.com',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe seu e-mail.';
                  }

                  if (!value.contains('@')) {
                    return 'Digite um e-mail valido.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  hintText: 'Minimo de 8 caracteres',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe sua senha.';
                  }

                  if (value.length < 8) {
                    return 'A senha precisa ter pelo menos 8 caracteres.';
                  }

                  return null;
                },
              ),
              if (mode == _AuthMode.register) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<AppUserRole>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Perfil',
                  ),
                  items: AppUserRole.values
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.label),
                        ),
                      )
                      .toList(),
                  onChanged: (role) {
                    if (role != null) {
                      onRoleChanged(role);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    hintText: '(11) 99999-9999',
                  ),
                ),
              ],
              if (feedbackMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSuccessFeedback
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    feedbackMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSuccessFeedback
                          ? const Color(0xFF166534)
                          : const Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          mode == _AuthMode.login ? 'Entrar na conta' : 'Criar conta',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  const _RoleOptionCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
