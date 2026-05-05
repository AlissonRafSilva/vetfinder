import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/domain/app_user_role.dart';
import '../data/profile_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileRepository _profileRepository = ProfileRepository();

  final _vetCrmvController = TextEditingController();
  final _vetCrmvStateController = TextEditingController(text: 'SP');
  final _vetRateController = TextEditingController();
  final _vetExperienceController = TextEditingController();
  final _vetDistanceController = TextEditingController();
  bool _vetEmergencyCare = true;
  bool _vetCanTravel = true;

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

  bool _isSaving = false;
  String? _feedbackMessage;
  bool _isFeedbackError = false;

  @override
  void dispose() {
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
    super.dispose();
  }

  Future<void> _saveVeterinarianProfile() async {
    final session = AppSessionScope.of(context);
    await _runSave(() {
      return _profileRepository.createVeterinarianProfile(
        accessToken: session.accessToken!,
        crmvNumber: _vetCrmvController.text,
        crmvState: _vetCrmvStateController.text,
        baseShiftRate: _vetRateController.text,
        yearsExperience: _vetExperienceController.text,
        emergencyCare: _vetEmergencyCare,
        canTravel: _vetCanTravel,
        maxDistanceKm: _vetDistanceController.text,
      );
    });
  }

  Future<void> _saveInternProfile() async {
    final session = AppSessionScope.of(context);
    await _runSave(() {
      return _profileRepository.createInternProfile(
        accessToken: session.accessToken!,
        universityName: _internUniversityController.text,
        coursePeriod: _internPeriodController.text,
        expectedGraduationDate: _internGraduationController.text,
      );
    });
  }

  Future<void> _saveInstitutionProfile() async {
    final session = AppSessionScope.of(context);
    await _runSave(() {
      return _profileRepository.createInstitutionProfile(
        accessToken: session.accessToken!,
        institutionType: session.roleValue == AppUserRole.hospital.apiValue
            ? 'HOSPITAL'
            : 'CLINIC',
        legalName: _legalNameController.text,
        tradeName: _tradeNameController.text,
        cnpj: _cnpjController.text,
        stateRegistration: _stateRegistrationController.text,
        description: _descriptionController.text,
        contactName: _contactNameController.text,
        contactPhone: _contactPhoneController.text,
      );
    });
  }

  Future<void> _runSave(Future<String> Function() action) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _feedbackMessage = null;
      _isFeedbackError = false;
    });

    try {
      final message = await action();
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackMessage = message;
        _isFeedbackError = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackMessage = error.message;
        _isFeedbackError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackMessage = 'Nao foi possivel salvar o perfil agora.';
        _isFeedbackError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final isInstitution = session.isInstitutionUser;
    final sectionTitle =
        isInstitution ? 'Perfil da instituicao' : 'Perfil profissional';
    final sectionSubtitle = isInstitution
        ? 'Complete os dados da clinica ou hospital para publicar vagas com mais confianca.'
        : 'Complete os dados profissionais para candidaturas, validacao e agenda.';

    if (!session.isAuthenticated) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: sectionTitle,
              subtitle: 'Faca login para visualizar e completar seu perfil.',
            ),
            const SizedBox(height: 18),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nenhuma sessao ativa no momento.'),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: sectionTitle,
            subtitle: sectionSubtitle,
          ),
          const SizedBox(height: 18),
          _SessionCard(
            isInstitution: isInstitution,
            onLogout: session.logout,
            email: session.email,
            roleValue: session.roleValue,
            status: session.status,
          ),
          const SizedBox(height: 18),
          if (_feedbackMessage != null)
            _FeedbackCard(
              message: _feedbackMessage!,
              isError: _isFeedbackError,
            ),
          if (_feedbackMessage != null) const SizedBox(height: 18),
          if (session.roleValue == AppUserRole.veterinarian.apiValue)
            _VeterinarianForm(
              crmvController: _vetCrmvController,
              crmvStateController: _vetCrmvStateController,
              rateController: _vetRateController,
              experienceController: _vetExperienceController,
              distanceController: _vetDistanceController,
              emergencyCare: _vetEmergencyCare,
              canTravel: _vetCanTravel,
              isSaving: _isSaving,
              onEmergencyCareChanged: (value) {
                setState(() => _vetEmergencyCare = value);
              },
              onCanTravelChanged: (value) {
                setState(() => _vetCanTravel = value);
              },
              onSubmit: _saveVeterinarianProfile,
            )
          else if (session.roleValue == AppUserRole.intern.apiValue)
            _InternForm(
              universityController: _internUniversityController,
              periodController: _internPeriodController,
              graduationController: _internGraduationController,
              isSaving: _isSaving,
              onSubmit: _saveInternProfile,
            )
          else if (isInstitution)
            _InstitutionForm(
              legalNameController: _legalNameController,
              tradeNameController: _tradeNameController,
              cnpjController: _cnpjController,
              stateRegistrationController: _stateRegistrationController,
              descriptionController: _descriptionController,
              contactNameController: _contactNameController,
              contactPhoneController: _contactPhoneController,
              isSaving: _isSaving,
              onSubmit: _saveInstitutionProfile,
            ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.isInstitution,
    required this.onLogout,
    required this.email,
    required this.roleValue,
    required this.status,
  });

  final bool isInstitution;
  final VoidCallback onLogout;
  final String? email;
  final String? roleValue;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarIcon =
        isInstitution ? Icons.apartment_rounded : Icons.pets_rounded;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    avatarIcon,
                    color: theme.colorScheme.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email ?? 'Usuario autenticado',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        roleValue ?? 'Perfil nao identificado',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                InfoBadge(label: status ?? 'Ativo'),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InfoBadge(label: roleValue ?? 'Perfil'),
                InfoBadge(label: status ?? 'Status'),
                const InfoBadge(label: 'JWT ativo'),
              ],
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onLogout,
              child: const Text('Encerrar sessao'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VeterinarianForm extends StatelessWidget {
  const _VeterinarianForm({
    required this.crmvController,
    required this.crmvStateController,
    required this.rateController,
    required this.experienceController,
    required this.distanceController,
    required this.emergencyCare,
    required this.canTravel,
    required this.isSaving,
    required this.onEmergencyCareChanged,
    required this.onCanTravelChanged,
    required this.onSubmit,
  });

  final TextEditingController crmvController;
  final TextEditingController crmvStateController;
  final TextEditingController rateController;
  final TextEditingController experienceController;
  final TextEditingController distanceController;
  final bool emergencyCare;
  final bool canTravel;
  final bool isSaving;
  final ValueChanged<bool> onEmergencyCareChanged;
  final ValueChanged<bool> onCanTravelChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _ProfileFormCard(
      title: 'Cadastro veterinario',
      subtitle:
          'Informe CRMV, valor base e preferencias para validacao inicial.',
      children: [
        _TextField(controller: crmvController, label: 'Numero do CRMV'),
        _TextField(controller: crmvStateController, label: 'UF do CRMV'),
        _TextField(
          controller: rateController,
          label: 'Valor base do plantao',
          keyboardType: TextInputType.number,
        ),
        _TextField(
          controller: experienceController,
          label: 'Anos de experiencia',
          keyboardType: TextInputType.number,
        ),
        _TextField(
          controller: distanceController,
          label: 'Distancia maxima em km',
          keyboardType: TextInputType.number,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: emergencyCare,
          onChanged: onEmergencyCareChanged,
          title: const Text('Atende emergencia'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: canTravel,
          onChanged: onCanTravelChanged,
          title: const Text('Pode se deslocar'),
        ),
        _SubmitButton(
          label: 'Salvar perfil veterinario',
          isSaving: isSaving,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

class _InternForm extends StatelessWidget {
  const _InternForm({
    required this.universityController,
    required this.periodController,
    required this.graduationController,
    required this.isSaving,
    required this.onSubmit,
  });

  final TextEditingController universityController;
  final TextEditingController periodController;
  final TextEditingController graduationController;
  final bool isSaving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _ProfileFormCard(
      title: 'Cadastro de estagiario',
      subtitle:
          'Informe sua instituicao de ensino e previsao de formatura para validacao.',
      children: [
        _TextField(
          controller: universityController,
          label: 'Instituicao de ensino',
        ),
        _TextField(controller: periodController, label: 'Periodo do curso'),
        _TextField(
          controller: graduationController,
          label: 'Previsao de formatura (AAAA-MM-DD)',
        ),
        _SubmitButton(
          label: 'Salvar perfil de estagiario',
          isSaving: isSaving,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

class _InstitutionForm extends StatelessWidget {
  const _InstitutionForm({
    required this.legalNameController,
    required this.tradeNameController,
    required this.cnpjController,
    required this.stateRegistrationController,
    required this.descriptionController,
    required this.contactNameController,
    required this.contactPhoneController,
    required this.isSaving,
    required this.onSubmit,
  });

  final TextEditingController legalNameController;
  final TextEditingController tradeNameController;
  final TextEditingController cnpjController;
  final TextEditingController stateRegistrationController;
  final TextEditingController descriptionController;
  final TextEditingController contactNameController;
  final TextEditingController contactPhoneController;
  final bool isSaving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _ProfileFormCard(
      title: 'Cadastro institucional',
      subtitle:
          'Complete os dados da clinica ou hospital para validacao por CNPJ.',
      children: [
        _TextField(controller: legalNameController, label: 'Razao social'),
        _TextField(controller: tradeNameController, label: 'Nome fantasia'),
        _TextField(controller: cnpjController, label: 'CNPJ'),
        _TextField(
          controller: stateRegistrationController,
          label: 'Inscricao estadual',
        ),
        _TextField(
          controller: contactNameController,
          label: 'Responsavel pelo contato',
        ),
        _TextField(controller: contactPhoneController, label: 'Telefone'),
        _TextField(
          controller: descriptionController,
          label: 'Descricao da instituicao',
          maxLines: 3,
        ),
        _SubmitButton(
          label: 'Salvar instituicao',
          isSaving: isSaving,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

class _ProfileFormCard extends StatelessWidget {
  const _ProfileFormCard({
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
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.isSaving,
    required this.onPressed,
  });

  final String label;
  final bool isSaving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSaving ? null : onPressed,
        child: Text(isSaving ? 'Salvando...' : label),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError ? theme.colorScheme.error : theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
