import 'package:flutter/material.dart';
import '../../../core/location/current_location_service.dart';
import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/network/api_client.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/app_user_role.dart';
import '../domain/auth_result.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({
    super.key,
    this.onOpenProfile,
    this.onOpenSchedule,
    this.onOpenMarketplace,
  });

  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenSchedule;
  final VoidCallback? onOpenMarketplace;

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

enum _AuthMode { login, register }

class _AuthGatePageState extends State<AuthGatePage> {
  final _formKey = GlobalKey<FormState>();
  final ProfileRepository _profileRepository = ProfileRepository();
  final CurrentLocationService _locationService =
      const CurrentLocationService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vetCrmvController = TextEditingController();
  final _vetCrmvStateController = TextEditingController(text: 'SP');
  final _vetRateController = TextEditingController();
  final _vetExperienceController = TextEditingController();
  final _vetDistanceController = TextEditingController();
  final _internUniversityController = TextEditingController();
  final _internPeriodController = TextEditingController();
  final _internGraduationController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _tradeNameController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _stateRegistrationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _profileLatController = TextEditingController();
  final _profileLngController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  AppUserRole _selectedRole = AppUserRole.veterinarian;
  bool _vetEmergencyCare = true;
  bool _vetCanTravel = true;
  bool _isSubmitting = false;
  bool _isDetectingLocation = false;
  String? _feedbackMessage;
  String? _locationFeedback;
  bool _isSuccessFeedback = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _vetCrmvController.dispose();
    _vetCrmvStateController.dispose();
    _vetRateController.dispose();
    _vetExperienceController.dispose();
    _vetDistanceController.dispose();
    _internUniversityController.dispose();
    _internPeriodController.dispose();
    _internGraduationController.dispose();
    _legalNameController.dispose();
    _tradeNameController.dispose();
    _cnpjController.dispose();
    _stateRegistrationController.dispose();
    _descriptionController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _profileLatController.dispose();
    _profileLngController.dispose();
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
      String feedbackMessage;
      var isSuccessFeedback = true;
      final session = AppSessionScope.of(context);

      if (_mode == _AuthMode.login) {
        result = await session.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
        feedbackMessage = _buildSuccessMessage(result);
      } else {
        result = await session.register(
          email: _emailController.text,
          password: _passwordController.text,
          phone: _phoneController.text,
          role: _selectedRole,
        );

        try {
          final profileMessage = await _saveInitialProfile(result);
          feedbackMessage = '${result.message}\n$profileMessage';
        } on ApiException catch (error) {
          isSuccessFeedback = false;
          feedbackMessage =
              'Conta criada e login realizado, mas o perfil inicial não foi salvo: ${error.message}';
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isSuccessFeedback = isSuccessFeedback;
        _feedbackMessage = feedbackMessage;
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
        _feedbackMessage = 'Não foi possível concluir a solicitação agora.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<String> _saveInitialProfile(AuthResult result) {
    final accessToken = result.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException('Token de acesso não retornado após cadastro.');
    }

    switch (_selectedRole) {
      case AppUserRole.veterinarian:
        return _profileRepository.createVeterinarianProfile(
          accessToken: accessToken,
          crmvNumber: _vetCrmvController.text,
          crmvState: _vetCrmvStateController.text,
          baseShiftRate: _vetRateController.text,
          yearsExperience: _vetExperienceController.text,
          emergencyCare: _vetEmergencyCare,
          canTravel: _vetCanTravel,
          maxDistanceKm: _vetDistanceController.text,
          latitude: _profileLatController.text,
          longitude: _profileLngController.text,
        );
      case AppUserRole.intern:
        return _profileRepository.createInternProfile(
          accessToken: accessToken,
          universityName: _internUniversityController.text,
          coursePeriod: _internPeriodController.text,
          expectedGraduationDate: _internGraduationController.text,
          latitude: _profileLatController.text,
          longitude: _profileLngController.text,
        );
      case AppUserRole.clinic:
      case AppUserRole.hospital:
        return _profileRepository.createInstitutionProfile(
          accessToken: accessToken,
          institutionType:
              _selectedRole == AppUserRole.hospital ? 'HOSPITAL' : 'CLINIC',
          legalName: _legalNameController.text,
          tradeName: _tradeNameController.text,
          cnpj: _cnpjController.text,
          stateRegistration: _stateRegistrationController.text,
          description: _descriptionController.text,
          contactName: _contactNameController.text,
          contactPhone: _contactPhoneController.text.isNotEmpty
              ? _contactPhoneController.text
              : _phoneController.text,
          latitude: _profileLatController.text,
          longitude: _profileLngController.text,
        );
    }
  }

  Future<void> _detectProfileLocation() async {
    if (_isDetectingLocation) {
      return;
    }

    setState(() {
      _isDetectingLocation = true;
      _locationFeedback = null;
    });

    try {
      final result = await _locationService.detect();
      if (!mounted) {
        return;
      }

      setState(() {
        if (result.location != null) {
          _profileLatController.text =
              result.location!.latitude.toStringAsFixed(6);
          _profileLngController.text =
              result.location!.longitude.toStringAsFixed(6);
        }
        _locationFeedback = result.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationFeedback = 'Não foi possível detectar sua localização agora.';
      });
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  String _buildSuccessMessage(AuthResult result) {
    if (_mode == _AuthMode.login) {
      return 'Login concluído para ${result.email ?? 'o usuário selecionado'}.';
    }

    return result.message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = AppSessionScope.of(context);
    final keyboardIsOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!keyboardIsOpen) ...[
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
                    'Conecte profissionais veterinários e instituições para cobrir plantões com rapidez.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _HeroMetric(label: 'Agenda'),
                      _HeroMetric(label: 'Geolocalização'),
                      _HeroMetric(label: 'Split sandbox'),
                      _HeroMetric(label: 'Alertas'),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
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
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Entrar'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _mode = _AuthMode.register);
                          Scrollable.ensureVisible(
                            _formKey.currentContext ?? context,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOut,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Criar conta'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
          if (session.isAuthenticated && !keyboardIsOpen) ...[
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
                            'Sessão ativa',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            session.email ?? 'Usuário autenticado',
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
            const SizedBox(height: 14),
            _OnboardingChecklistCard(
              roleValue: session.roleValue,
              onOpenProfile: widget.onOpenProfile,
              onOpenSchedule: widget.onOpenSchedule,
              onOpenMarketplace: widget.onOpenMarketplace,
            ),
            const SizedBox(height: 28),
          ],
          SectionHeader(
            title: _mode == _AuthMode.login
                ? 'Acesse sua conta'
                : 'Crie sua conta',
            subtitle: _mode == _AuthMode.login
                ? 'Use o mesmo backend do VetFinder para autenticar.'
                : 'O cadastro já prepara seu perfil para usar a plataforma.',
          ),
          const SizedBox(height: 16),
          _AuthFormCard(
            formKey: _formKey,
            mode: _mode,
            selectedRole: _selectedRole,
            emailController: _emailController,
            passwordController: _passwordController,
            phoneController: _phoneController,
            vetCrmvController: _vetCrmvController,
            vetCrmvStateController: _vetCrmvStateController,
            vetRateController: _vetRateController,
            vetExperienceController: _vetExperienceController,
            vetDistanceController: _vetDistanceController,
            vetEmergencyCare: _vetEmergencyCare,
            vetCanTravel: _vetCanTravel,
            internUniversityController: _internUniversityController,
            internPeriodController: _internPeriodController,
            internGraduationController: _internGraduationController,
            legalNameController: _legalNameController,
            tradeNameController: _tradeNameController,
            cnpjController: _cnpjController,
            stateRegistrationController: _stateRegistrationController,
            descriptionController: _descriptionController,
            contactNameController: _contactNameController,
            contactPhoneController: _contactPhoneController,
            latitudeController: _profileLatController,
            longitudeController: _profileLngController,
            isSubmitting: _isSubmitting,
            isDetectingLocation: _isDetectingLocation,
            feedbackMessage: _feedbackMessage,
            locationFeedback: _locationFeedback,
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
            onVetEmergencyCareChanged: (value) {
              setState(() => _vetEmergencyCare = value);
            },
            onVetCanTravelChanged: (value) {
              setState(() => _vetCanTravel = value);
            },
            onDetectLocation: _detectProfileLocation,
            onSubmit: _submit,
          ),
          if (!keyboardIsOpen) ...[
            const SizedBox(height: 28),
            const SectionHeader(
              title: 'Escolha seu perfil',
              subtitle: 'A experiência muda conforme o tipo de usuário.',
            ),
            const SizedBox(height: 16),
            const _RoleOptionCard(
              icon: Icons.local_hospital_rounded,
              title: 'Veterinário volante',
              description:
                  'Receba plantões próximos, convites e pagamentos pelo app.',
            ),
            const SizedBox(height: 14),
            const _RoleOptionCard(
              icon: Icons.school_rounded,
              title: 'Estagiário',
              description:
                  'Encontre oportunidades compatíveis com sua formação e agenda.',
            ),
            const SizedBox(height: 14),
            const _RoleOptionCard(
              icon: Icons.storefront_rounded,
              title: 'Clínica ou hospital',
              description:
                  'Publique demandas urgentes e feche plantões com segurança.',
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _OnboardingChecklistCard extends StatelessWidget {
  const _OnboardingChecklistCard({
    required this.roleValue,
    required this.onOpenProfile,
    required this.onOpenSchedule,
    required this.onOpenMarketplace,
  });

  final String? roleValue;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenSchedule;
  final VoidCallback? onOpenMarketplace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVeterinarian = roleValue == AppUserRole.veterinarian.apiValue;
    final isIntern = roleValue == AppUserRole.intern.apiValue;
    final isInstitution = roleValue == AppUserRole.clinic.apiValue ||
        roleValue == AppUserRole.hospital.apiValue;

    final title = isInstitution
        ? 'Próximos passos da instituição'
        : 'Próximos passos do profissional';
    final subtitle = isInstitution
        ? 'Complete o cadastro institucional para publicar vagas e convidar profissionais com mais confiança.'
        : 'Complete seu perfil e agenda para aparecer melhor nas buscas e receber oportunidades compatíveis.';
    final profileStep = isInstitution
        ? 'Validar dados de CNPJ e contato'
        : isIntern
            ? 'Informar instituição de ensino'
            : isVeterinarian
                ? 'Informar CRMV e valor base'
                : 'Completar dados principais';
    final marketStep = isInstitution
        ? 'Buscar profissionais disponíveis'
        : isIntern
            ? 'Ver estágios disponíveis'
            : 'Ver plantões disponíveis';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _ChecklistItem(
              icon: Icons.verified_user_outlined,
              label: profileStep,
            ),
            if (!isInstitution)
              const _ChecklistItem(
                icon: Icons.calendar_month_outlined,
                label: 'Configurar dias e horários disponíveis',
              ),
            _ChecklistItem(
              icon: isInstitution
                  ? Icons.search_rounded
                  : Icons.work_outline_rounded,
              label: marketStep,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onOpenProfile,
                  icon: const Icon(Icons.person_rounded),
                  label: const Text('Completar perfil'),
                ),
                if (!isInstitution)
                  OutlinedButton.icon(
                    onPressed: onOpenSchedule,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: const Text('Configurar agenda'),
                  ),
                OutlinedButton.icon(
                  onPressed: onOpenMarketplace,
                  icon: const Icon(Icons.search_rounded),
                  label: Text(
                      isInstitution ? 'Buscar profissionais' : 'Ver vagas'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
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
    required this.vetCrmvController,
    required this.vetCrmvStateController,
    required this.vetRateController,
    required this.vetExperienceController,
    required this.vetDistanceController,
    required this.vetEmergencyCare,
    required this.vetCanTravel,
    required this.internUniversityController,
    required this.internPeriodController,
    required this.internGraduationController,
    required this.legalNameController,
    required this.tradeNameController,
    required this.cnpjController,
    required this.stateRegistrationController,
    required this.descriptionController,
    required this.contactNameController,
    required this.contactPhoneController,
    required this.latitudeController,
    required this.longitudeController,
    required this.isSubmitting,
    required this.isDetectingLocation,
    required this.feedbackMessage,
    required this.locationFeedback,
    required this.isSuccessFeedback,
    required this.onModeChanged,
    required this.onRoleChanged,
    required this.onVetEmergencyCareChanged,
    required this.onVetCanTravelChanged,
    required this.onDetectLocation,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final _AuthMode mode;
  final AppUserRole selectedRole;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController phoneController;
  final TextEditingController vetCrmvController;
  final TextEditingController vetCrmvStateController;
  final TextEditingController vetRateController;
  final TextEditingController vetExperienceController;
  final TextEditingController vetDistanceController;
  final bool vetEmergencyCare;
  final bool vetCanTravel;
  final TextEditingController internUniversityController;
  final TextEditingController internPeriodController;
  final TextEditingController internGraduationController;
  final TextEditingController legalNameController;
  final TextEditingController tradeNameController;
  final TextEditingController cnpjController;
  final TextEditingController stateRegistrationController;
  final TextEditingController descriptionController;
  final TextEditingController contactNameController;
  final TextEditingController contactPhoneController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final bool isSubmitting;
  final bool isDetectingLocation;
  final String? feedbackMessage;
  final String? locationFeedback;
  final bool isSuccessFeedback;
  final ValueChanged<_AuthMode> onModeChanged;
  final ValueChanged<AppUserRole> onRoleChanged;
  final ValueChanged<bool> onVetEmergencyCareChanged;
  final ValueChanged<bool> onVetCanTravelChanged;
  final VoidCallback onDetectLocation;
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
                const SizedBox(height: 18),
                _RegistrationProfileFields(
                  selectedRole: selectedRole,
                  vetCrmvController: vetCrmvController,
                  vetCrmvStateController: vetCrmvStateController,
                  vetRateController: vetRateController,
                  vetExperienceController: vetExperienceController,
                  vetDistanceController: vetDistanceController,
                  vetEmergencyCare: vetEmergencyCare,
                  vetCanTravel: vetCanTravel,
                  internUniversityController: internUniversityController,
                  internPeriodController: internPeriodController,
                  internGraduationController: internGraduationController,
                  legalNameController: legalNameController,
                  tradeNameController: tradeNameController,
                  cnpjController: cnpjController,
                  stateRegistrationController: stateRegistrationController,
                  descriptionController: descriptionController,
                  contactNameController: contactNameController,
                  contactPhoneController: contactPhoneController,
                  latitudeController: latitudeController,
                  longitudeController: longitudeController,
                  isDetectingLocation: isDetectingLocation,
                  locationFeedback: locationFeedback,
                  onVetEmergencyCareChanged: onVetEmergencyCareChanged,
                  onVetCanTravelChanged: onVetCanTravelChanged,
                  onDetectLocation: onDetectLocation,
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
                          mode == _AuthMode.login
                              ? 'Entrar na conta'
                              : 'Criar conta',
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

class _RegistrationProfileFields extends StatelessWidget {
  const _RegistrationProfileFields({
    required this.selectedRole,
    required this.vetCrmvController,
    required this.vetCrmvStateController,
    required this.vetRateController,
    required this.vetExperienceController,
    required this.vetDistanceController,
    required this.vetEmergencyCare,
    required this.vetCanTravel,
    required this.internUniversityController,
    required this.internPeriodController,
    required this.internGraduationController,
    required this.legalNameController,
    required this.tradeNameController,
    required this.cnpjController,
    required this.stateRegistrationController,
    required this.descriptionController,
    required this.contactNameController,
    required this.contactPhoneController,
    required this.latitudeController,
    required this.longitudeController,
    required this.isDetectingLocation,
    required this.locationFeedback,
    required this.onVetEmergencyCareChanged,
    required this.onVetCanTravelChanged,
    required this.onDetectLocation,
  });

  final AppUserRole selectedRole;
  final TextEditingController vetCrmvController;
  final TextEditingController vetCrmvStateController;
  final TextEditingController vetRateController;
  final TextEditingController vetExperienceController;
  final TextEditingController vetDistanceController;
  final bool vetEmergencyCare;
  final bool vetCanTravel;
  final TextEditingController internUniversityController;
  final TextEditingController internPeriodController;
  final TextEditingController internGraduationController;
  final TextEditingController legalNameController;
  final TextEditingController tradeNameController;
  final TextEditingController cnpjController;
  final TextEditingController stateRegistrationController;
  final TextEditingController descriptionController;
  final TextEditingController contactNameController;
  final TextEditingController contactPhoneController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final bool isDetectingLocation;
  final String? locationFeedback;
  final ValueChanged<bool> onVetEmergencyCareChanged;
  final ValueChanged<bool> onVetCanTravelChanged;
  final VoidCallback onDetectLocation;

  @override
  Widget build(BuildContext context) {
    switch (selectedRole) {
      case AppUserRole.veterinarian:
        return _RegisterSection(
          title: 'Dados profissionais',
          subtitle:
              'Essas informações criam seu perfil veterinário imediatamente após a conta.',
          children: [
            _RequiredTextField(
              controller: vetCrmvController,
              label: 'Número do CRMV',
            ),
            _RequiredTextField(
              controller: vetCrmvStateController,
              label: 'UF do CRMV',
              maxLength: 2,
            ),
            _RequiredTextField(
              controller: vetRateController,
              label: 'Valor base do plantão',
              keyboardType: TextInputType.number,
            ),
            _OptionalTextField(
              controller: vetExperienceController,
              label: 'Anos de experiência',
              keyboardType: TextInputType.number,
            ),
            _OptionalTextField(
              controller: vetDistanceController,
              label: 'Distância máxima em km',
              keyboardType: TextInputType.number,
            ),
            _RegistrationLocationFields(
              latitudeController: latitudeController,
              longitudeController: longitudeController,
              isDetectingLocation: isDetectingLocation,
              feedback: locationFeedback,
              onDetectLocation: onDetectLocation,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: vetEmergencyCare,
              onChanged: onVetEmergencyCareChanged,
              title: const Text('Atende emergência'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: vetCanTravel,
              onChanged: onVetCanTravelChanged,
              title: const Text('Pode se deslocar'),
            ),
          ],
        );
      case AppUserRole.intern:
        return _RegisterSection(
          title: 'Dados acadêmicos',
          subtitle:
              'Essas informações ajudam clínicas e hospitais a validar sua candidatura.',
          children: [
            _RequiredTextField(
              controller: internUniversityController,
              label: 'Instituição de ensino',
            ),
            _OptionalTextField(
              controller: internPeriodController,
              label: 'Período do curso',
            ),
            _OptionalTextField(
              controller: internGraduationController,
              label: 'Previsão de formatura (AAAA-MM-DD)',
            ),
            _RegistrationLocationFields(
              latitudeController: latitudeController,
              longitudeController: longitudeController,
              isDetectingLocation: isDetectingLocation,
              feedback: locationFeedback,
              onDetectLocation: onDetectLocation,
            ),
          ],
        );
      case AppUserRole.clinic:
      case AppUserRole.hospital:
        return _RegisterSection(
          title: 'Dados da instituição',
          subtitle:
              'Essas informações criam o perfil institucional para publicar vagas.',
          children: [
            _RequiredTextField(
              controller: legalNameController,
              label: 'Razão social',
            ),
            _RequiredTextField(
              controller: tradeNameController,
              label: 'Nome fantasia',
            ),
            _RequiredTextField(
              controller: cnpjController,
              label: 'CNPJ',
              keyboardType: TextInputType.number,
            ),
            _OptionalTextField(
              controller: stateRegistrationController,
              label: 'Inscrição estadual',
            ),
            _RequiredTextField(
              controller: contactNameController,
              label: 'Responsável pelo contato',
            ),
            _OptionalTextField(
              controller: contactPhoneController,
              label: 'Telefone institucional',
              keyboardType: TextInputType.phone,
            ),
            _OptionalTextField(
              controller: descriptionController,
              label: 'Descrição da instituição',
              maxLines: 3,
            ),
            _RegistrationLocationFields(
              latitudeController: latitudeController,
              longitudeController: longitudeController,
              isDetectingLocation: isDetectingLocation,
              feedback: locationFeedback,
              onDetectLocation: onDetectLocation,
            ),
          ],
        );
    }
  }
}

class _RegisterSection extends StatelessWidget {
  const _RegisterSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _RegistrationLocationFields extends StatelessWidget {
  const _RegistrationLocationFields({
    required this.latitudeController,
    required this.longitudeController,
    required this.isDetectingLocation,
    required this.feedback,
    required this.onDetectLocation,
  });

  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final bool isDetectingLocation;
  final String? feedback;
  final VoidCallback onDetectLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Localização',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _OptionalTextField(
                  controller: latitudeController,
                  label: 'Latitude',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OptionalTextField(
                  controller: longitudeController,
                  label: 'Longitude',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: isDetectingLocation ? null : onDetectLocation,
            icon: const Icon(Icons.my_location_rounded),
            label: Text(
              isDetectingLocation
                  ? 'Detectando localização...'
                  : 'Usar localização atual',
            ),
          ),
          if (feedback != null) ...[
            const SizedBox(height: 8),
            Text(
              feedback!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequiredTextField extends StatelessWidget {
  const _RequiredTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return _RegisterTextField(
      controller: controller,
      label: label,
      keyboardType: keyboardType,
      maxLength: maxLength,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Informe $label.';
        }

        return null;
      },
    );
  }
}

class _OptionalTextField extends StatelessWidget {
  const _OptionalTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return _RegisterTextField(
      controller: controller,
      label: label,
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }
}

class _RegisterTextField extends StatelessWidget {
  const _RegisterTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(labelText: label),
        validator: validator,
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
