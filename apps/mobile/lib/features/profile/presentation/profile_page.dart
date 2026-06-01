import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/location/current_location_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/app_session_controller.dart';
import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/domain/app_user_role.dart';
import '../../documents/data/documents_repository.dart';
import '../../documents/domain/document_summary.dart';
import '../data/profile_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileRepository _profileRepository = ProfileRepository();
  final DocumentsRepository _documentsRepository = DocumentsRepository();
  final CurrentLocationService _locationService = const CurrentLocationService();

  final _vetCrmvController = TextEditingController();
  final _vetCrmvStateController = TextEditingController(text: 'SP');
  final _vetRateController = TextEditingController();
  final _vetExperienceController = TextEditingController();
  final _vetDistanceController = TextEditingController();
  final _profileLatController = TextEditingController();
  final _profileLngController = TextEditingController();
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
  bool _isSubmittingDocument = false;
  bool _isDetectingLocation = false;
  bool _isRefreshingSession = false;
  String? _loadedProfileKey;
  String? _loadedDocumentsKey;
  Future<List<DocumentSummary>>? _documentsFuture;
  String? _feedbackMessage;
  String? _locationFeedback;
  bool _isFeedbackError = false;

  @override
  void dispose() {
    _vetCrmvController.dispose();
    _vetCrmvStateController.dispose();
    _vetRateController.dispose();
    _vetExperienceController.dispose();
    _vetDistanceController.dispose();
    _profileLatController.dispose();
    _profileLngController.dispose();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadExistingProfileIfNeeded();
    _loadDocumentsIfNeeded();
    _refreshSessionIfNeeded();
  }

  void _loadDocumentsIfNeeded() {
    final session = AppSessionScope.of(context);
    final documentsKey = '${session.userId}:${session.accessToken}';
    if (!session.isAuthenticated ||
        session.accessToken == null ||
        _loadedDocumentsKey == documentsKey) {
      return;
    }

    _loadedDocumentsKey = documentsKey;
    _documentsFuture = _documentsRepository.fetchMine(
      accessToken: session.accessToken!,
    );
  }

  Future<void> _refreshSessionIfNeeded() async {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated || _isRefreshingSession) {
      return;
    }

    _isRefreshingSession = true;
    try {
      await session.refreshCurrentUser();
    } on ApiException {
      // Mantem a sessao atual se a API estiver indisponivel.
    } finally {
      _isRefreshingSession = false;
    }
  }

  Future<void> _refreshSessionManually() async {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated || _isRefreshingSession) {
      return;
    }

    setState(() {
      _isRefreshingSession = true;
      _feedbackMessage = null;
      _isFeedbackError = false;
    });

    try {
      await session.refreshCurrentUser();
      if (!mounted) {
        return;
      }

      setState(() {
        _feedbackMessage = 'Status da conta atualizado.';
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
    } finally {
      if (mounted) {
        setState(() => _isRefreshingSession = false);
      } else {
        _isRefreshingSession = false;
      }
    }
  }

  Future<void> _loadExistingProfileIfNeeded() async {
    final session = AppSessionScope.of(context);
    final profileKey = '${session.userId}:${session.roleValue}';

    if (!session.isAuthenticated ||
        session.userId == null ||
        session.accessToken == null ||
        _loadedProfileKey == profileKey) {
      return;
    }

    _clearProfileFormForSessionChange();
    _loadedProfileKey = profileKey;

    try {
      if (session.isInstitutionUser) {
        final institution = await _profileRepository.fetchMyInstitutionProfile(
          accessToken: session.accessToken!,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _legalNameController.text =
              institution['legalName']?.toString() ?? '';
          _tradeNameController.text =
              institution['tradeName']?.toString() ?? '';
          _cnpjController.text = institution['cnpj']?.toString() ?? '';
          _stateRegistrationController.text =
              institution['stateRegistration']?.toString() ?? '';
          _descriptionController.text =
              institution['description']?.toString() ?? '';
          _contactNameController.text =
              institution['contactName']?.toString() ?? '';
          _contactPhoneController.text =
              institution['contactPhone']?.toString() ?? '';
          final address = institution['address'] as Map<String, dynamic>?;
          _profileLatController.text = address?['lat']?.toString() ?? '';
          _profileLngController.text = address?['lng']?.toString() ?? '';
        });
        return;
      }

      final professional = await _profileRepository.fetchProfessionalProfile(
        userId: session.userId!,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final veterinarianProfile =
            professional['veterinarianProfile'] as Map<String, dynamic>?;
        final internProfile =
            professional['internProfile'] as Map<String, dynamic>?;
        final baseProfile =
            professional['profile'] as Map<String, dynamic>?;
        final address = baseProfile?['address'] as Map<String, dynamic>?;
        _profileLatController.text = address?['lat']?.toString() ?? '';
        _profileLngController.text = address?['lng']?.toString() ?? '';

        if (veterinarianProfile != null) {
          _vetCrmvController.text =
              veterinarianProfile['crmvNumber']?.toString() ?? '';
          _vetCrmvStateController.text =
              veterinarianProfile['crmvState']?.toString() ?? 'SP';
          _vetRateController.text =
              veterinarianProfile['baseShiftRate']?.toString() ?? '';
          _vetExperienceController.text =
              veterinarianProfile['yearsExperience']?.toString() ?? '';
          _vetDistanceController.text =
              veterinarianProfile['maxDistanceKm']?.toString() ?? '';
          _vetEmergencyCare = veterinarianProfile['emergencyCare'] == true;
          _vetCanTravel = veterinarianProfile['canTravel'] == true;
        }

        if (internProfile != null) {
          _internUniversityController.text =
              internProfile['universityName']?.toString() ?? '';
          _internPeriodController.text =
              internProfile['coursePeriod']?.toString() ?? '';
          _internGraduationController.text =
              _dateOnly(internProfile['expectedGraduationDate']?.toString());
        }
      });
    } on ApiException {
      // Perfil ainda nao existe; o formulario permanece em branco para criacao.
    }
  }

  void _clearProfileFormForSessionChange() {
    _vetCrmvController.clear();
    _vetCrmvStateController.text = 'SP';
    _vetRateController.clear();
    _vetExperienceController.clear();
    _vetDistanceController.clear();
    _profileLatController.clear();
    _profileLngController.clear();
    _vetEmergencyCare = true;
    _vetCanTravel = true;
    _internUniversityController.clear();
    _internPeriodController.clear();
    _internGraduationController.clear();
    _legalNameController.clear();
    _tradeNameController.clear();
    _cnpjController.clear();
    _stateRegistrationController.clear();
    _descriptionController.clear();
    _contactNameController.clear();
    _contactPhoneController.clear();
    _locationFeedback = null;
    _feedbackMessage = null;
    _isFeedbackError = false;
  }

  String _dateOnly(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }

    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');

    return '${parsed.year}-$month-$day';
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
        latitude: _profileLatController.text,
        longitude: _profileLngController.text,
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
        latitude: _profileLatController.text,
        longitude: _profileLngController.text,
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
        latitude: _profileLatController.text,
        longitude: _profileLngController.text,
      );
    });
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
        _isFeedbackError = !result.isSuccess;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationFeedback =
            'Não foi possível detectar sua localização agora.';
        _isFeedbackError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
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
        _feedbackMessage = 'Não foi possível salvar o perfil agora.';
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

  Future<void> _submitDocument(_RequiredDocument document) async {
    final session = AppSessionScope.of(context);
    if (session.accessToken == null || _isSubmittingDocument) {
      return;
    }

    final pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (pickedFile == null || pickedFile.files.isEmpty) {
      return;
    }

    final file = pickedFile.files.single;
    if (file.size > 8 * 1024 * 1024) {
      setState(() {
        _feedbackMessage = 'Envie um arquivo de até 8 MB.';
        _isFeedbackError = true;
      });
      return;
    }

    setState(() {
      _isSubmittingDocument = true;
      _feedbackMessage = null;
      _isFeedbackError = false;
    });

    try {
      final message = await _documentsRepository.uploadDocument(
        accessToken: session.accessToken!,
        ownerType: document.ownerType,
        documentType: document.documentType,
        file: file,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _feedbackMessage = message;
        _isFeedbackError = false;
        _documentsFuture = _documentsRepository.fetchMine(
          accessToken: session.accessToken!,
        );
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _feedbackMessage = error.message;
        _isFeedbackError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmittingDocument = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final isInstitution = session.isInstitutionUser;
    final keyboardIsOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final sectionTitle =
        isInstitution ? 'Perfil da instituição' : 'Perfil profissional';
    final sectionSubtitle = isInstitution
        ? 'Complete os dados da clínica ou hospital para publicar vagas com mais confiança.'
        : 'Complete os dados profissionais para candidaturas, validação e agenda.';

    if (!session.isAuthenticated) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: sectionTitle,
              subtitle: 'Faça login para visualizar e completar seu perfil.',
            ),
            const SizedBox(height: 18),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nenhuma sessão ativa no momento.'),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: sectionTitle,
            subtitle: sectionSubtitle,
          ),
          const SizedBox(height: 18),
          if (!keyboardIsOpen) ...[
            _SessionCard(
              isInstitution: isInstitution,
              onLogout: session.logout,
              onRefreshStatus: _refreshSessionManually,
              isRefreshingStatus: _isRefreshingSession,
              email: session.email,
              roleValue: session.roleValue,
              status: session.status,
            ),
            const SizedBox(height: 18),
            _ValidationGuidanceCard(
              isInstitution: isInstitution,
              roleValue: session.roleValue,
              status: session.status,
            ),
            const SizedBox(height: 18),
          ],
          if (_feedbackMessage != null)
            _FeedbackCard(
              message: _feedbackMessage!,
              isError: _isFeedbackError,
            ),
          if (_feedbackMessage != null) const SizedBox(height: 18),
          if (!keyboardIsOpen) ...[
            _DocumentsValidationSection(
              documentsFuture: _documentsFuture,
              requiredDocuments: _requiredDocumentsForSession(session),
              isSubmitting: _isSubmittingDocument,
              onSubmit: _submitDocument,
              onRefresh: () {
                if (session.accessToken == null) {
                  return;
                }

                setState(() {
                  _documentsFuture = _documentsRepository.fetchMine(
                    accessToken: session.accessToken!,
                  );
                });
              },
            ),
            const SizedBox(height: 18),
          ],
          if (session.roleValue == AppUserRole.veterinarian.apiValue)
            _VeterinarianForm(
              crmvController: _vetCrmvController,
              crmvStateController: _vetCrmvStateController,
              rateController: _vetRateController,
              experienceController: _vetExperienceController,
              distanceController: _vetDistanceController,
              latitudeController: _profileLatController,
              longitudeController: _profileLngController,
              emergencyCare: _vetEmergencyCare,
              canTravel: _vetCanTravel,
              isSaving: _isSaving,
              isDetectingLocation: _isDetectingLocation,
              locationFeedback: _locationFeedback,
              onDetectLocation: _detectProfileLocation,
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
              latitudeController: _profileLatController,
              longitudeController: _profileLngController,
              isSaving: _isSaving,
              isDetectingLocation: _isDetectingLocation,
              locationFeedback: _locationFeedback,
              onDetectLocation: _detectProfileLocation,
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
              latitudeController: _profileLatController,
              longitudeController: _profileLngController,
              isSaving: _isSaving,
              isDetectingLocation: _isDetectingLocation,
              locationFeedback: _locationFeedback,
              onDetectLocation: _detectProfileLocation,
              onSubmit: _saveInstitutionProfile,
            ),
        ],
      ),
    );
  }

  List<_RequiredDocument> _requiredDocumentsForSession(
    AppSessionController session,
  ) {
    if (session.roleValue == AppUserRole.veterinarian.apiValue) {
      return const [
        _RequiredDocument(
          ownerType: 'USER',
          documentType: 'PROFILE_PHOTO',
          title: 'Foto de perfil',
          description:
              'Ajuda clínicas e hospitais a reconhecerem o profissional.',
        ),
        _RequiredDocument(
          ownerType: 'USER',
          documentType: 'CRMV_PROOF',
          title: 'Comprovante CRMV',
          description: 'Documento usado pelo admin para validar seu CRMV.',
        ),
      ];
    }

    if (session.roleValue == AppUserRole.intern.apiValue) {
      return const [
        _RequiredDocument(
          ownerType: 'USER',
          documentType: 'PROFILE_PHOTO',
          title: 'Foto de perfil',
          description:
              'Ajuda instituições a identificarem o candidato com segurança.',
        ),
        _RequiredDocument(
          ownerType: 'USER',
          documentType: 'ENROLLMENT_STATEMENT',
          title: 'Declaracao de matricula',
          description:
              'Comprovante acadêmico necessário para oportunidades de estágio.',
        ),
      ];
    }

    if (session.isInstitutionUser) {
      return const [
        _RequiredDocument(
          ownerType: 'INSTITUTION',
          documentType: 'CNPJ_PROOF',
          title: 'Comprovante CNPJ',
          description: 'Documento usado pelo admin para validar a instituição.',
        ),
      ];
    }

    return const [];
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.isInstitution,
    required this.onLogout,
    required this.onRefreshStatus,
    required this.isRefreshingStatus,
    required this.email,
    required this.roleValue,
    required this.status,
  });

  final bool isInstitution;
  final VoidCallback onLogout;
  final VoidCallback onRefreshStatus;
  final bool isRefreshingStatus;
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
                        email ?? 'Usuário autenticado',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        roleValue ?? 'Perfil não identificado',
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
                OutlinedButton.icon(
                  onPressed: isRefreshingStatus ? null : onRefreshStatus,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    isRefreshingStatus ? 'Atualizando...' : 'Atualizar status',
                  ),
                ),
                InfoBadge(label: roleValue ?? 'Perfil'),
                InfoBadge(label: status ?? 'Status'),
                const InfoBadge(label: 'JWT ativo'),
              ],
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onLogout,
              child: const Text('Encerrar sessão'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationGuidanceCard extends StatelessWidget {
  const _ValidationGuidanceCard({
    required this.isInstitution,
    required this.roleValue,
    required this.status,
  });

  final bool isInstitution;
  final String? roleValue;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isApproved = status == 'ACTIVE';
    final color =
        isApproved ? theme.colorScheme.primary : theme.colorScheme.tertiary;
    final title =
        isApproved ? 'Cadastro validado' : 'Cadastro aguardando validação';
    final message = isApproved
        ? 'Seu perfil esta liberado para usar os fluxos principais do marketplace.'
        : _pendingMessage();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                isApproved
                    ? Icons.verified_rounded
                    : Icons.hourglass_top_rounded,
                color: color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      InfoBadge(label: _statusLabel(status)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(message),
                  if (!isApproved) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Depois que o admin aprovar os documentos, faca login novamente para atualizar a liberacao da conta.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pendingMessage() {
    if (isInstitution) {
      return 'Envie o comprovante de CNPJ. Enquanto a instituição não for aprovada, publicar vagas e fechar plantões pode ser bloqueado.';
    }

    if (roleValue == AppUserRole.intern.apiValue) {
      return 'Envie a foto de perfil e a declaração de matrícula para aumentar confiança e destaque nas oportunidades de estágio.';
    }

    return 'Envie a foto de perfil e o comprovante CRMV para aumentar confiança e destaque nas vagas veterinárias.';
  }

  String _statusLabel(String? value) {
    if (value == 'ACTIVE') {
      return 'Aprovado';
    }

    if (value == 'BLOCKED') {
      return 'Bloqueado';
    }

    return 'Pendente';
  }
}

class _DocumentsValidationSection extends StatelessWidget {
  const _DocumentsValidationSection({
    required this.documentsFuture,
    required this.requiredDocuments,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onRefresh,
  });

  final Future<List<DocumentSummary>>? documentsFuture;
  final List<_RequiredDocument> requiredDocuments;
  final bool isSubmitting;
  final ValueChanged<_RequiredDocument> onSubmit;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Documentos de validação',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Atualizar documentos',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Envie arquivos em PDF, JPG ou PNG com até 8 MB para revisão do admin.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (documentsFuture == null)
              const Text('Documentos ainda não carregados.')
            else
              FutureBuilder<List<DocumentSummary>>(
                future: documentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }

                  if (snapshot.hasError) {
                    return const Text(
                      'Não foi possível carregar os documentos agora.',
                    );
                  }

                  final documents = snapshot.data ?? const <DocumentSummary>[];

                  return Column(
                    children: [
                      for (final requiredDocument in requiredDocuments) ...[
                        _RequiredDocumentTile(
                          requiredDocument: requiredDocument,
                          document: _latestDocumentFor(
                            documents,
                            requiredDocument.documentType,
                          ),
                          isSubmitting: isSubmitting,
                          onSubmit: () => onSubmit(requiredDocument),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (requiredDocuments.isEmpty)
                        const Text(
                          'Este tipo de usuário não possui documentos obrigatórios no MVP.',
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  DocumentSummary? _latestDocumentFor(
    List<DocumentSummary> documents,
    String documentType,
  ) {
    for (final document in documents) {
      if (document.documentType == documentType) {
        return document;
      }
    }

    return null;
  }
}

class _RequiredDocumentTile extends StatelessWidget {
  const _RequiredDocumentTile({
    required this.requiredDocument,
    required this.document,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final _RequiredDocument requiredDocument;
  final DocumentSummary? document;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = document?.statusLabel ?? 'Não enviado';

    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    requiredDocument.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                InfoBadge(label: statusLabel),
              ],
            ),
            const SizedBox(height: 6),
            Text(requiredDocument.description),
            if (document != null) ...[
              const SizedBox(height: 10),
              Text(
                'Enviado em ${document!.createdAtLabel}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (document!.rejectionReason.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Motivo: ${document!.rejectionReason}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isSubmitting ? null : onSubmit,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(document == null
                    ? 'Enviar documento'
                    : 'Reenviar documento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequiredDocument {
  const _RequiredDocument({
    required this.ownerType,
    required this.documentType,
    required this.title,
    required this.description,
  });

  final String ownerType;
  final String documentType;
  final String title;
  final String description;
}

class _VeterinarianForm extends StatelessWidget {
  const _VeterinarianForm({
    required this.crmvController,
    required this.crmvStateController,
    required this.rateController,
    required this.experienceController,
    required this.distanceController,
    required this.latitudeController,
    required this.longitudeController,
    required this.emergencyCare,
    required this.canTravel,
    required this.isSaving,
    required this.isDetectingLocation,
    required this.locationFeedback,
    required this.onEmergencyCareChanged,
    required this.onCanTravelChanged,
    required this.onDetectLocation,
    required this.onSubmit,
  });

  final TextEditingController crmvController;
  final TextEditingController crmvStateController;
  final TextEditingController rateController;
  final TextEditingController experienceController;
  final TextEditingController distanceController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final bool emergencyCare;
  final bool canTravel;
  final bool isSaving;
  final bool isDetectingLocation;
  final String? locationFeedback;
  final ValueChanged<bool> onEmergencyCareChanged;
  final ValueChanged<bool> onCanTravelChanged;
  final VoidCallback onDetectLocation;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _ProfileFormCard(
      title: 'Cadastro veterinário',
      subtitle:
          'Informe CRMV, valor base e preferências para validação inicial.',
      children: [
        _TextField(controller: crmvController, label: 'Numero do CRMV'),
        _TextField(controller: crmvStateController, label: 'UF do CRMV'),
        _TextField(
          controller: rateController,
          label: 'Valor base do plantão',
          keyboardType: TextInputType.number,
        ),
        _TextField(
          controller: experienceController,
          label: 'Anos de experiência',
          keyboardType: TextInputType.number,
        ),
        _TextField(
          controller: distanceController,
          label: 'Distancia maxima em km',
          keyboardType: TextInputType.number,
        ),
        _LocationFields(
          latitudeController: latitudeController,
          longitudeController: longitudeController,
          isDetectingLocation: isDetectingLocation,
          feedback: locationFeedback,
          onDetectLocation: onDetectLocation,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: emergencyCare,
          onChanged: onEmergencyCareChanged,
          title: const Text('Atende emergência'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: canTravel,
          onChanged: onCanTravelChanged,
          title: const Text('Pode se deslocar'),
        ),
        _SubmitButton(
          label: 'Salvar perfil veterinário',
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
    required this.latitudeController,
    required this.longitudeController,
    required this.isSaving,
    required this.isDetectingLocation,
    required this.locationFeedback,
    required this.onDetectLocation,
    required this.onSubmit,
  });

  final TextEditingController universityController;
  final TextEditingController periodController;
  final TextEditingController graduationController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final bool isSaving;
  final bool isDetectingLocation;
  final String? locationFeedback;
  final VoidCallback onDetectLocation;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _ProfileFormCard(
      title: 'Cadastro de estagiario',
      subtitle:
          'Informe sua instituição de ensino e previsão de formatura para validação.',
      children: [
        _TextField(
          controller: universityController,
          label: 'Instituição de ensino',
        ),
        _TextField(controller: periodController, label: 'Periodo do curso'),
        _TextField(
          controller: graduationController,
          label: 'Previsao de formatura (AAAA-MM-DD)',
        ),
        _LocationFields(
          latitudeController: latitudeController,
          longitudeController: longitudeController,
          isDetectingLocation: isDetectingLocation,
          feedback: locationFeedback,
          onDetectLocation: onDetectLocation,
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
    required this.latitudeController,
    required this.longitudeController,
    required this.isSaving,
    required this.isDetectingLocation,
    required this.locationFeedback,
    required this.onDetectLocation,
    required this.onSubmit,
  });

  final TextEditingController legalNameController;
  final TextEditingController tradeNameController;
  final TextEditingController cnpjController;
  final TextEditingController stateRegistrationController;
  final TextEditingController descriptionController;
  final TextEditingController contactNameController;
  final TextEditingController contactPhoneController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final bool isSaving;
  final bool isDetectingLocation;
  final String? locationFeedback;
  final VoidCallback onDetectLocation;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _ProfileFormCard(
      title: 'Cadastro institucional',
      subtitle:
          'Complete os dados da clínica ou hospital para validação por CNPJ.',
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
          label: 'Descrição da instituição',
          maxLines: 3,
        ),
        _LocationFields(
          latitudeController: latitudeController,
          longitudeController: longitudeController,
          isDetectingLocation: isDetectingLocation,
          feedback: locationFeedback,
          onDetectLocation: onDetectLocation,
        ),
        _SubmitButton(
          label: 'Salvar instituição',
          isSaving: isSaving,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

class _LocationFields extends StatelessWidget {
  const _LocationFields({
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
                child: _TextField(
                  controller: latitudeController,
                  label: 'Latitude',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TextField(
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
