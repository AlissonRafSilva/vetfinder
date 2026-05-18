import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/location/current_location_service.dart';
import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../availability/data/availability_repository.dart';
import '../../availability/domain/available_professional_summary.dart';
import '../../applications/data/applications_repository.dart';
import '../../auth/domain/app_user_role.dart';
import '../data/opportunities_repository.dart';
import '../domain/institution_opportunity_option.dart';
import '../domain/opportunity_summary.dart';
import 'available_professional_profile_page.dart';
import 'opportunity_detail_page.dart';

class OpportunitiesPage extends StatefulWidget {
  const OpportunitiesPage({super.key});

  @override
  State<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<OpportunitiesPage> {
  late Future<List<OpportunitySummary>> _future;
  final OpportunitiesRepository _repository = OpportunitiesRepository();
  final AvailabilityRepository _availabilityRepository =
      AvailabilityRepository();
  final ApplicationsRepository _applicationsRepository =
      ApplicationsRepository();
  final CurrentLocationService _locationService = const CurrentLocationService();
  Future<List<AvailableProfessionalSummary>>? _professionalsFuture;
  Future<List<InstitutionOpportunityOption>>? _myOpportunitiesFuture;
  String? _lastAudience;
  String? _loadedProfessionalsSearchKey;
  int? _selectedWeekday;
  String _professionalTypeFilter = 'ALL';
  bool _verifiedOnly = false;
  int? _maxDistanceKm;
  bool _isDetectingLocation = false;
  String? _locationFeedback;
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _originLatController = TextEditingController();
  final TextEditingController _originLngController = TextEditingController();
  final TextEditingController _specialtyFilterController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchOpenOpportunities();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncOpportunityAudience();
    _loadProfessionalsIfNeeded();
  }

  String? _audienceForCurrentSession() {
    final session = AppSessionScope.of(context);
    if (session.roleValue == AppUserRole.intern.apiValue) {
      return 'INTERN';
    }

    if (session.roleValue == AppUserRole.veterinarian.apiValue) {
      return 'VETERINARIAN';
    }

    return null;
  }

  void _syncOpportunityAudience() {
    final session = AppSessionScope.of(context);
    if (session.isInstitutionUser) {
      return;
    }

    final audience = _audienceForCurrentSession();
    if (audience == _lastAudience) {
      return;
    }

    _lastAudience = audience;
    _future = _repository.fetchOpenOpportunities(audience: audience);
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    _originLatController.dispose();
    _originLngController.dispose();
    _specialtyFilterController.dispose();
    super.dispose();
  }

  void _loadProfessionalsIfNeeded() {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated || !session.isInstitutionUser) {
      _professionalsFuture = null;
      _myOpportunitiesFuture = null;
      _loadedProfessionalsSearchKey = null;
      return;
    }

    final searchKey = [
      session.userId,
      session.accessToken,
      _selectedWeekday?.toString() ?? 'any',
      _startTimeController.text,
      _endTimeController.text,
      _originLatController.text,
      _originLngController.text,
      _maxDistanceKm?.toString() ?? 'any',
    ].join(':');

    if (_loadedProfessionalsSearchKey == searchKey &&
        _professionalsFuture != null &&
        _myOpportunitiesFuture != null) {
      return;
    }

    _loadedProfessionalsSearchKey = searchKey;
    _professionalsFuture = _availabilityRepository.searchAvailableProfessionals(
      accessToken: session.accessToken!,
      weekday: _selectedWeekday,
      startTime: _startTimeController.text,
      endTime: _endTimeController.text,
      originLat: _originLatController.text.trim(),
      originLng: _originLngController.text.trim(),
      maxDistanceKm: _maxDistanceKm,
    );
    _myOpportunitiesFuture = _repository.fetchMyInstitutionOpportunities(
      accessToken: session.accessToken!,
    );
  }

  void _reload() {
    setState(() {
      _future = _repository.fetchOpenOpportunities(
        audience: _audienceForCurrentSession(),
      );
      _loadProfessionalsIfNeeded();
    });
  }

  Future<void> _detectCurrentLocation() async {
    if (_isDetectingLocation) {
      return;
    }

    setState(() {
      _isDetectingLocation = true;
      _locationFeedback = null;
    });

    try {
      final result = await _locationService.detect();

      setState(() {
        if (result.location != null) {
          _originLatController.text =
              result.location!.latitude.toStringAsFixed(6);
          _originLngController.text =
              result.location!.longitude.toStringAsFixed(6);
        }
        _loadedProfessionalsSearchKey = null;
        _locationFeedback = result.message;
        _loadProfessionalsIfNeeded();
      });
    } catch (_) {
      setState(() {
        _locationFeedback =
            'Nao foi possivel detectar a localizacao agora. Preencha manualmente se necessario.';
      });
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  Future<void> _inviteProfessional(
      AvailableProfessionalSummary professional) async {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated ||
        !session.isInstitutionUser ||
        session.accessToken == null) {
      return;
    }

    List<InstitutionOpportunityOption> opportunities;

    try {
      opportunities = await (_myOpportunitiesFuture ??
          _repository.fetchMyInstitutionOpportunities(
            accessToken: session.accessToken!,
          ));
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    if (opportunities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Crie ou mantenha uma vaga ativa para enviar convites.'),
        ),
      );
      return;
    }

    final compatibleOpportunities = opportunities.where((opportunity) {
      final isIntern = professional.roleValue == AppUserRole.intern.apiValue;
      if (isIntern) {
        return opportunity.opportunityType == 'INTERNSHIP';
      }

      return opportunity.opportunityType != 'INTERNSHIP';
    }).toList();

    if (compatibleOpportunities.isEmpty) {
      final isIntern = professional.roleValue == AppUserRole.intern.apiValue;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isIntern
                ? 'Crie uma vaga do tipo estagio para convidar este estagiario.'
                : 'Crie uma vaga veterinaria para convidar este profissional.',
          ),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<_InviteSelectionResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _InviteProfessionalSheet(
        professional: professional,
        opportunities: compatibleOpportunities,
      ),
    );

    if (result == null) {
      return;
    }

    try {
      final message = await _applicationsRepository.inviteProfessional(
        accessToken: session.accessToken!,
        opportunityId: result.opportunityId,
        professionalUserId: professional.id,
        message: result.message,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);

    if (session.isAuthenticated && session.isInstitutionUser) {
      return _AvailableProfessionalsPage(
        selectedWeekday: _selectedWeekday,
        startTimeController: _startTimeController,
        endTimeController: _endTimeController,
        originLatController: _originLatController,
        originLngController: _originLngController,
        accountStatus: session.status,
        professionalsFuture: _professionalsFuture,
        professionalTypeFilter: _professionalTypeFilter,
        verifiedOnly: _verifiedOnly,
        maxDistanceKm: _maxDistanceKm,
        specialtyFilterController: _specialtyFilterController,
        onInvite: _inviteProfessional,
        onWeekdayChanged: (value) {
          setState(() {
            _selectedWeekday = value;
            _loadedProfessionalsSearchKey = null;
            _loadProfessionalsIfNeeded();
          });
        },
        onProfessionalTypeFilterChanged: (value) {
          setState(() => _professionalTypeFilter = value);
        },
        onVerifiedOnlyChanged: (value) {
          setState(() => _verifiedOnly = value);
        },
        onMaxDistanceChanged: (value) {
          setState(() {
            _maxDistanceKm = value;
            _loadedProfessionalsSearchKey = null;
            _loadProfessionalsIfNeeded();
          });
        },
        onLocalFiltersChanged: () {
          setState(() {});
        },
        onDetectLocation: _detectCurrentLocation,
        isDetectingLocation: _isDetectingLocation,
        locationFeedback: _locationFeedback,
        onSearch: () {
          setState(() {
            _loadedProfessionalsSearchKey = null;
            _loadProfessionalsIfNeeded();
          });
        },
      );
    }

    return _OpportunitiesBody(
      opportunitiesFuture: _future,
      onRetry: _reload,
      audience: _audienceForCurrentSession(),
      accountStatus: session.isAuthenticated ? session.status : null,
    );
  }
}

class _AvailableProfessionalsPage extends StatelessWidget {
  const _AvailableProfessionalsPage({
    required this.selectedWeekday,
    required this.startTimeController,
    required this.endTimeController,
    required this.originLatController,
    required this.originLngController,
    required this.accountStatus,
    required this.professionalsFuture,
    required this.professionalTypeFilter,
    required this.verifiedOnly,
    required this.maxDistanceKm,
    required this.specialtyFilterController,
    required this.onInvite,
    required this.onWeekdayChanged,
    required this.onProfessionalTypeFilterChanged,
    required this.onVerifiedOnlyChanged,
    required this.onMaxDistanceChanged,
    required this.onLocalFiltersChanged,
    required this.onDetectLocation,
    required this.isDetectingLocation,
    required this.locationFeedback,
    required this.onSearch,
  });

  final int? selectedWeekday;
  final TextEditingController startTimeController;
  final TextEditingController endTimeController;
  final TextEditingController originLatController;
  final TextEditingController originLngController;
  final String? accountStatus;
  final Future<List<AvailableProfessionalSummary>>? professionalsFuture;
  final String professionalTypeFilter;
  final bool verifiedOnly;
  final int? maxDistanceKm;
  final TextEditingController specialtyFilterController;
  final ValueChanged<AvailableProfessionalSummary> onInvite;
  final ValueChanged<int?> onWeekdayChanged;
  final ValueChanged<String> onProfessionalTypeFilterChanged;
  final ValueChanged<bool> onVerifiedOnlyChanged;
  final ValueChanged<int?> onMaxDistanceChanged;
  final VoidCallback onLocalFiltersChanged;
  final VoidCallback onDetectLocation;
  final bool isDetectingLocation;
  final String? locationFeedback;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Profissionais disponiveis',
            subtitle:
                'Clinicas e hospitais veem apenas profissionais com agenda livre. As vagas de outras instituicoes nao aparecem aqui.',
          ),
          const SizedBox(height: 18),
          if (accountStatus != 'ACTIVE') ...[
            const _VerificationNoticeCard(
              title: 'Instituicao aguardando validacao',
              message:
                  'A busca continua visivel, mas convites e fechamento de plantoes podem ser bloqueados ate o CNPJ ser aprovado no admin.',
            ),
            const SizedBox(height: 18),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buscar por agenda',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedWeekday,
                    decoration: const InputDecoration(
                      labelText: 'Dia da semana',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Qualquer dia'),
                      ),
                      ...List.generate(
                        7,
                        (index) => DropdownMenuItem<int?>(
                          value: index + 1,
                          child: Text(_weekdayLabel(index + 1)),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      onWeekdayChanged(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startTimeController,
                          decoration: const InputDecoration(
                            labelText: 'Inicio opcional',
                            hintText: '08:00',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: endTimeController,
                          decoration: const InputDecoration(
                            labelText: 'Fim opcional',
                            hintText: '18:00',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: professionalTypeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de profissional',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'ALL',
                        child: Text('Todos'),
                      ),
                      DropdownMenuItem(
                        value: 'VETERINARIAN',
                        child: Text('Veterinarios'),
                      ),
                      DropdownMenuItem(
                        value: 'INTERN',
                        child: Text('Estagiarios'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onProfessionalTypeFilterChanged(value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: specialtyFilterController,
                    decoration: const InputDecoration(
                      labelText: 'Especialidade',
                      hintText: 'Ex.: emergencia, estagio, clinica geral',
                    ),
                    onChanged: (_) => onLocalFiltersChanged(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: originLatController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Latitude da origem',
                            hintText: '-23.56',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: originLngController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Longitude da origem',
                            hintText: '-46.65',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isDetectingLocation ? null : onDetectLocation,
                      icon: const Icon(Icons.my_location_rounded),
                      label: Text(
                        isDetectingLocation
                            ? 'Detectando localizacao...'
                            : 'Usar minha localizacao atual',
                      ),
                    ),
                  ),
                  if (locationFeedback != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      locationFeedback!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: maxDistanceKm,
                    decoration: const InputDecoration(
                      labelText: 'Distancia maxima',
                    ),
                    items: const [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Sem limite'),
                      ),
                      DropdownMenuItem(value: 5, child: Text('Ate 5 km')),
                      DropdownMenuItem(value: 10, child: Text('Ate 10 km')),
                      DropdownMenuItem(value: 25, child: Text('Ate 25 km')),
                      DropdownMenuItem(value: 50, child: Text('Ate 50 km')),
                    ],
                    onChanged: onMaxDistanceChanged,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: verifiedOnly,
                    onChanged: (value) {
                      onVerifiedOnlyChanged(value ?? false);
                    },
                    title: const Text('Somente perfil verificado'),
                    subtitle: const Text(
                      'Mostra apenas profissionais com documentos aprovados.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onSearch,
                      child: const Text('Buscar profissionais'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<AvailableProfessionalSummary>>(
            future: professionalsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Nao foi possivel carregar os profissionais disponiveis agora.',
                    ),
                  ),
                );
              }

              final items = _filterProfessionals(
                snapshot.data ?? const <AvailableProfessionalSummary>[],
              );
              if (items.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Nenhum profissional foi encontrado para os filtros selecionados.',
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    _ProfessionalAvailabilityCard(
                      item: items[index],
                      onInvite: () => onInvite(items[index]),
                      onOpenProfile: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AvailableProfessionalProfilePage(
                              professional: items[index],
                              onInvite: () => onInvite(items[index]),
                            ),
                          ),
                        );
                      },
                    ),
                    if (index < items.length - 1) const SizedBox(height: 14),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<AvailableProfessionalSummary> _filterProfessionals(
    List<AvailableProfessionalSummary> items,
  ) {
    return items.where((item) {
      if (professionalTypeFilter != 'ALL' &&
          item.roleValue != professionalTypeFilter) {
        return false;
      }

      if (verifiedOnly && !item.isVerified) {
        return false;
      }

      final specialtyFilter =
          specialtyFilterController.text.trim().toLowerCase();
      if (specialtyFilter.isEmpty) {
        return true;
      }

      return item.specialtyLabel.toLowerCase().contains(specialtyFilter);
    }).toList();
  }

  static String _weekdayLabel(int weekday) {
    const values = [
      'Segunda',
      'Terca',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sabado',
      'Domingo',
    ];

    return values[(weekday - 1).clamp(0, values.length - 1)];
  }
}

class _ProfessionalAvailabilityCard extends StatelessWidget {
  const _ProfessionalAvailabilityCard({
    required this.item,
    required this.onInvite,
    required this.onOpenProfile,
  });

  final AvailableProfessionalSummary item;
  final VoidCallback onInvite;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: item.isVerified
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    item.isVerified
                        ? Icons.verified_rounded
                        : Icons.person_outline_rounded,
                    color: item.isVerified
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.name,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                InfoBadge(label: item.verificationLabel),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.roleLabel,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: item.isVerified
                    ? theme.colorScheme.primary.withValues(alpha: 0.08)
                    : theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.isVerified
                        ? Icons.workspace_premium_outlined
                        : Icons.trending_up_rounded,
                    color: item.isVerified
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.trustLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.trustDescription,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InfoBadge(label: item.completenessLabel),
                InfoBadge(label: item.specialtyLabel),
                InfoBadge(label: item.cityLabel),
                InfoBadge(label: item.rateLabel),
                InfoBadge(
                  label: item.reputationLabel,
                  icon: Icons.star_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Horarios disponiveis',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: item.availability
                  .map((slot) => InfoBadge(label: slot.displayLabel))
                  .toList(),
            ),
            const SizedBox(height: 14),
            Text(
              item.email,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenProfile,
                    icon: const Icon(Icons.person_search_rounded),
                    label: const Text('Ver perfil'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onInvite,
                    child: const Text('Convidar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteSelectionResult {
  const _InviteSelectionResult({
    required this.opportunityId,
    this.message,
  });

  final String opportunityId;
  final String? message;
}

class _InviteProfessionalSheet extends StatefulWidget {
  const _InviteProfessionalSheet({
    required this.professional,
    required this.opportunities,
  });

  final AvailableProfessionalSummary professional;
  final List<InstitutionOpportunityOption> opportunities;

  @override
  State<_InviteProfessionalSheet> createState() =>
      _InviteProfessionalSheetState();
}

class _InviteProfessionalSheetState extends State<_InviteProfessionalSheet> {
  late String _selectedOpportunityId;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedOpportunityId = widget.opportunities.first.id;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Convidar ${widget.professional.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Escolha uma das suas vagas abertas e envie um convite direto para esse profissional.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedOpportunityId,
            decoration: const InputDecoration(
              labelText: 'Vaga da instituicao',
            ),
            items: widget.opportunities
                .map(
                  (opportunity) => DropdownMenuItem(
                    value: opportunity.id,
                    child: Text(opportunity.title),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedOpportunityId = value;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Mensagem opcional',
              hintText:
                  'Ex.: Gostaria de te convidar para um plantao noturno na nossa unidade.',
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(
                  _InviteSelectionResult(
                    opportunityId: _selectedOpportunityId,
                    message: _messageController.text,
                  ),
                );
              },
              child: const Text('Enviar convite'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpportunitiesBody extends StatelessWidget {
  const _OpportunitiesBody({
    required this.opportunitiesFuture,
    required this.onRetry,
    required this.audience,
    required this.accountStatus,
  });

  final Future<List<OpportunitySummary>> opportunitiesFuture;
  final VoidCallback onRetry;
  final String? audience;
  final String? accountStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isIntern = audience == 'INTERN';

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title:
                      isIntern ? 'Estagios disponiveis' : 'Plantoes proximos',
                  subtitle: isIntern
                      ? 'Veja apenas oportunidades marcadas para estagiarios.'
                      : 'Veja vagas abertas para veterinarios volantes, sem oportunidades de estagio.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    InfoBadge(
                      label: isIntern ? 'Somente estagios' : 'Sem estagios',
                      icon: Icons.filter_alt_outlined,
                    ),
                    const InfoBadge(
                        label: 'Ate 10 km', icon: Icons.place_outlined),
                    const InfoBadge(label: 'Hoje'),
                    const InfoBadge(label: 'Perfil completo se destaca'),
                  ],
                ),
                if (accountStatus != null && accountStatus != 'ACTIVE') ...[
                  const SizedBox(height: 16),
                  _VerificationNoticeCard(
                    title: isIntern
                        ? 'Estagio pode exigir validacao'
                        : 'Plantao pode exigir validacao',
                    message: isIntern
                        ? 'Envie foto e declaracao de matricula no Perfil para aumentar confianca e destaque nas selecoes.'
                        : 'Envie foto e comprovante CRMV no Perfil para aumentar confianca e destaque nas selecoes.',
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverToBoxAdapter(
            child: FutureBuilder<List<OpportunitySummary>>(
              future: opportunitiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return _OpportunitiesErrorState(
                    onRetry: onRetry,
                    message:
                        'Nao foi possivel carregar as oportunidades agora.',
                  );
                }

                final items = snapshot.data ?? const <OpportunitySummary>[];
                if (items.isEmpty) {
                  return const _EmptyOpportunitiesState();
                }

                return Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      _OpportunityCard(item: items[index], theme: theme),
                      if (index < items.length - 1) const SizedBox(height: 14),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _VerificationNoticeCard extends StatelessWidget {
  const _VerificationNoticeCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.verified_user_outlined,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.item,
    required this.theme,
  });

  final OpportunitySummary item;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                InfoBadge(label: item.urgencyLabel),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.institution,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            InfoBadge(
              label: item.institutionReputationLabel,
              icon: Icons.star_rounded,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _QuickInfoChip(
                  icon: Icons.badge_outlined,
                  label: item.opportunityTypeLabel,
                ),
                _QuickInfoChip(
                  icon: Icons.local_hospital_outlined,
                  label: item.specialty,
                ),
                _QuickInfoChip(
                  icon: Icons.schedule_outlined,
                  label: item.shiftLabel,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 18,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.amountLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    item.distanceLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OpportunityDetailPage(summary: item),
                    ),
                  );
                },
                child: const Text('Ver detalhes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickInfoChip extends StatelessWidget {
  const _QuickInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpportunitiesErrorState extends StatelessWidget {
  const _OpportunitiesErrorState({
    required this.onRetry,
    required this.message,
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conexao indisponivel',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOpportunitiesState extends StatelessWidget {
  const _EmptyOpportunitiesState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nenhuma oportunidade aberta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Assim que clinicas e hospitais publicarem novas vagas, elas aparecerao aqui.',
            ),
          ],
        ),
      ),
    );
  }
}
