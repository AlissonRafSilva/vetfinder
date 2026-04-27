import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../availability/data/availability_repository.dart';
import '../../availability/domain/available_professional_summary.dart';
import '../../applications/data/applications_repository.dart';
import '../data/opportunities_repository.dart';
import '../domain/institution_opportunity_option.dart';
import '../domain/opportunity_summary.dart';
import 'opportunity_detail_page.dart';

class OpportunitiesPage extends StatefulWidget {
  const OpportunitiesPage({super.key});

  @override
  State<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<OpportunitiesPage> {
  late Future<List<OpportunitySummary>> _future;
  final OpportunitiesRepository _repository = OpportunitiesRepository();
  final AvailabilityRepository _availabilityRepository = AvailabilityRepository();
  final ApplicationsRepository _applicationsRepository = ApplicationsRepository();
  Future<List<AvailableProfessionalSummary>>? _professionalsFuture;
  Future<List<InstitutionOpportunityOption>>? _myOpportunitiesFuture;
  int _selectedWeekday = 1;
  final TextEditingController _startTimeController = TextEditingController(
    text: '08:00',
  );
  final TextEditingController _endTimeController = TextEditingController(
    text: '18:00',
  );

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchOpenOpportunities();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProfessionalsIfNeeded();
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  void _loadProfessionalsIfNeeded() {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated || !session.isInstitutionUser) {
      return;
    }

    _professionalsFuture = _availabilityRepository.searchAvailableProfessionals(
      accessToken: session.accessToken!,
      weekday: _selectedWeekday,
      startTime: _startTimeController.text,
      endTime: _endTimeController.text,
    );
    _myOpportunitiesFuture = _repository.fetchMyInstitutionOpportunities(
      accessToken: session.accessToken!,
    );
  }

  void _reload() {
    setState(() {
      _future = _repository.fetchOpenOpportunities();
      _loadProfessionalsIfNeeded();
    });
  }

  Future<void> _inviteProfessional(AvailableProfessionalSummary professional) async {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated || !session.isInstitutionUser || session.accessToken == null) {
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
          content: Text('Crie ou mantenha uma vaga ativa para enviar convites.'),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<_InviteSelectionResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _InviteProfessionalSheet(
        professional: professional,
        opportunities: opportunities,
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
        professionalsFuture: _professionalsFuture,
        onInvite: _inviteProfessional,
        onWeekdayChanged: (value) {
          setState(() {
            _selectedWeekday = value;
            _loadProfessionalsIfNeeded();
          });
        },
        onSearch: () {
          setState(_loadProfessionalsIfNeeded);
        },
      );
    }

    return _OpportunitiesBody(
      opportunitiesFuture: _future,
      onRetry: _reload,
    );
  }
}

class _AvailableProfessionalsPage extends StatelessWidget {
  const _AvailableProfessionalsPage({
    required this.selectedWeekday,
    required this.startTimeController,
    required this.endTimeController,
    required this.professionalsFuture,
    required this.onInvite,
    required this.onWeekdayChanged,
    required this.onSearch,
  });

  final int selectedWeekday;
  final TextEditingController startTimeController;
  final TextEditingController endTimeController;
  final Future<List<AvailableProfessionalSummary>>? professionalsFuture;
  final ValueChanged<AvailableProfessionalSummary> onInvite;
  final ValueChanged<int> onWeekdayChanged;
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
                  DropdownButtonFormField<int>(
                    initialValue: selectedWeekday,
                    decoration: const InputDecoration(
                      labelText: 'Dia da semana',
                    ),
                    items: List.generate(
                      7,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(_weekdayLabel(index + 1)),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        onWeekdayChanged(value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startTimeController,
                          decoration: const InputDecoration(
                            labelText: 'Inicio',
                            hintText: '08:00',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: endTimeController,
                          decoration: const InputDecoration(
                            labelText: 'Fim',
                            hintText: '18:00',
                          ),
                        ),
                      ),
                    ],
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

              final items = snapshot.data ?? const <AvailableProfessionalSummary>[];
              if (items.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Nenhum profissional disponivel foi encontrado para esse horario.',
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
  });

  final AvailableProfessionalSummary item;
  final VoidCallback onInvite;

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
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InfoBadge(label: item.specialtyLabel),
                InfoBadge(label: item.cityLabel),
                InfoBadge(label: item.rateLabel),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onInvite,
                child: const Text('Convidar para uma vaga'),
              ),
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
  State<_InviteProfessionalSheet> createState() => _InviteProfessionalSheetState();
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
              hintText: 'Ex.: Gostaria de te convidar para um plantao noturno na nossa unidade.',
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
  });

  final Future<List<OpportunitySummary>> opportunitiesFuture;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Plantoes proximos',
                  subtitle: 'Veja vagas abertas com base em proximidade e urgencia.',
                ),
                SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    InfoBadge(label: 'Ate 10 km', icon: Icons.place_outlined),
                    InfoBadge(label: 'Clinica geral'),
                    InfoBadge(label: 'Hoje'),
                    InfoBadge(label: 'Perfil validado'),
                  ],
                ),
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
                    message: 'Nao foi possivel carregar as oportunidades agora.',
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
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
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
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
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
