import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../applications/data/applications_repository.dart';
import '../../applications/domain/opportunity_application_summary.dart';
import '../../applications/domain/opportunity_invite_summary.dart';
import '../../engagements/data/engagements_repository.dart';
import '../../platform/data/platform_config_repository.dart';
import '../data/opportunities_repository.dart';
import '../domain/create_institution_opportunity_input.dart';
import '../domain/institution_opportunity_option.dart';

class InstitutionOpportunitiesPage extends StatefulWidget {
  const InstitutionOpportunitiesPage({super.key});

  @override
  State<InstitutionOpportunitiesPage> createState() =>
      _InstitutionOpportunitiesPageState();
}

class _InstitutionOpportunitiesPageState
    extends State<InstitutionOpportunitiesPage> {
  final OpportunitiesRepository _opportunitiesRepository =
      OpportunitiesRepository();
  final PlatformConfigRepository _platformConfigRepository =
      PlatformConfigRepository();
  Future<List<InstitutionOpportunityOption>>? _myOpportunitiesFuture;
  String? _loadedSessionKey;
  int _refreshVersion = 0;
  double _platformFeeRate = 0.03;
  String _platformFeePercentLabel = '3%';

  @override
  void initState() {
    super.initState();
    _loadPlatformConfig();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshIfNeeded();
  }

  void _refreshIfNeeded() {
    final session = AppSessionScope.of(context);
    final sessionKey =
        '${session.userId ?? 'guest'}:${session.accessToken ?? 'none'}:${session.roleValue ?? 'none'}';

    if (_loadedSessionKey == sessionKey && _myOpportunitiesFuture != null) {
      return;
    }

    if (!session.isAuthenticated || !session.isInstitutionUser) {
      _myOpportunitiesFuture = null;
      _loadedSessionKey = sessionKey;
      return;
    }

    _loadedSessionKey = sessionKey;
    _refresh();
  }

  void _refresh() {
    final session = AppSessionScope.of(context);

    if (!session.isAuthenticated || !session.isInstitutionUser) {
      _myOpportunitiesFuture = null;
      return;
    }

    _myOpportunitiesFuture =
        _opportunitiesRepository.fetchMyInstitutionOpportunities(
      accessToken: session.accessToken!,
    );
    _refreshVersion++;
  }

  Future<void> _loadPlatformConfig() async {
    try {
      final config = await _platformConfigRepository.fetchConfig();
      if (!mounted) {
        return;
      }

      setState(() {
        _platformFeeRate = config.platformFeeRate;
        _platformFeePercentLabel = config.platformFeePercentLabel;
      });
    } catch (_) {
      // Mantem o fallback local para permitir uso do app se a API cair.
    }
  }

  Future<void> _openCreateOpportunityFlow() async {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated || !session.isInstitutionUser) {
      return;
    }

    final input = await showModalBottomSheet<CreateInstitutionOpportunityInput>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _CreateOpportunitySheet(),
    );

    if (input == null) {
      return;
    }

    try {
      final message =
          await _opportunitiesRepository.createInstitutionOpportunity(
        accessToken: session.accessToken!,
        input: input,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() => _refresh());
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyOpportunityError(error.message))),
      );
    }
  }

  Future<void> _openEditOpportunityFlow(
      InstitutionOpportunityOption item) async {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated || !session.isInstitutionUser) {
      return;
    }

    final input = await showModalBottomSheet<CreateInstitutionOpportunityInput>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateOpportunitySheet(
        initialOpportunity: item,
      ),
    );

    if (input == null) {
      return;
    }

    try {
      final message =
          await _opportunitiesRepository.updateInstitutionOpportunity(
        accessToken: session.accessToken!,
        opportunityId: item.id,
        input: input,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() => _refresh());
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyOpportunityError(error.message))),
      );
    }
  }

  String _friendlyOpportunityError(String message) {
    if (message.contains('Instituicao do usuario autenticado nao encontrada')) {
      return 'Complete e salve o cadastro institucional na aba Perfil antes de criar vagas.';
    }

    return message;
  }

  Future<void> _changeOpportunityStatus({
    required InstitutionOpportunityOption item,
    required String status,
  }) async {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated || !session.isInstitutionUser) {
      return;
    }

    try {
      final message = await _opportunitiesRepository.updateOpportunityStatus(
        accessToken: session.accessToken!,
        opportunityId: item.id,
        status: status,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() => _refresh());
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
    final theme = Theme.of(context);

    if (!session.isAuthenticated) {
      return const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Minhas vagas',
              subtitle:
                  'Faça login como clínica ou hospital para acompanhar suas vagas abertas.',
            ),
            SizedBox(height: 18),
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nenhuma sessão institucional ativa no momento.'),
              ),
            ),
          ],
        ),
      );
    }

    if (!session.isInstitutionUser) {
      return const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Minhas vagas',
              subtitle:
                  'Esta área é exclusiva para clínicas e hospitais gerenciarem suas vagas.',
            ),
            SizedBox(height: 18),
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Entre com um perfil institucional para acompanhar convites e status das vagas publicadas.',
                ),
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
          const SectionHeader(
            title: 'Minhas vagas',
            subtitle:
                'Publique novas vagas, acompanhe as abertas da sua instituição e veja o retorno dos convites enviados.',
          ),
          const SizedBox(height: 18),
          if (session.status != 'ACTIVE') ...[
            const _InstitutionVerificationNotice(),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              const Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    InfoBadge(label: 'Somente da sua instituição'),
                    InfoBadge(label: 'Convites monitorados'),
                    InfoBadge(label: 'Fluxo institucional'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => _refresh()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Atualizar'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _openCreateOpportunityFlow,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nova vaga'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<InstitutionOpportunityOption>>(
            future: _myOpportunitiesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Não foi possível carregar as vagas da instituição.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tente novamente para atualizar o acompanhamento das vagas abertas.',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() => _refresh()),
                          child: const Text('Atualizar'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final items =
                  snapshot.data ?? const <InstitutionOpportunityOption>[];
              if (items.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nenhuma vaga aberta da sua instituição foi encontrada ainda.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Crie sua primeira vaga para comecar a convidar profissionais ou receber candidaturas.',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _openCreateOpportunityFlow,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Criar primeira vaga'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    _InstitutionOpportunityCard(
                      item: items[index],
                      accessToken: session.accessToken!,
                      platformFeeRate: _platformFeeRate,
                      platformFeePercentLabel: _platformFeePercentLabel,
                      refreshVersion: _refreshVersion,
                      onEngagementCreated: () => setState(() => _refresh()),
                      onEdit: () => _openEditOpportunityFlow(items[index]),
                      onStatusChange: (status) => _changeOpportunityStatus(
                        item: items[index],
                        status: status,
                      ),
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
}

class _InstitutionVerificationNotice extends StatelessWidget {
  const _InstitutionVerificationNotice();

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
              Icons.domain_verification_outlined,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CNPJ aguardando aprovação',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Complete o perfil institucional e envie o comprovante de CNPJ. Publicar vagas e fechar plantões pode ser bloqueado até a aprovação no admin.',
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

class _InstitutionOpportunityCard extends StatefulWidget {
  const _InstitutionOpportunityCard({
    required this.item,
    required this.accessToken,
    required this.platformFeeRate,
    required this.platformFeePercentLabel,
    required this.refreshVersion,
    required this.onEngagementCreated,
    required this.onEdit,
    required this.onStatusChange,
  });

  final InstitutionOpportunityOption item;
  final String accessToken;
  final double platformFeeRate;
  final String platformFeePercentLabel;
  final int refreshVersion;
  final VoidCallback onEngagementCreated;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatusChange;

  @override
  State<_InstitutionOpportunityCard> createState() =>
      _InstitutionOpportunityCardState();
}

class _InstitutionOpportunityCardState
    extends State<_InstitutionOpportunityCard> {
  final ApplicationsRepository _applicationsRepository =
      ApplicationsRepository();
  late Future<_InstitutionOpportunityActivity> _activityFuture;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _loadCardData();
  }

  @override
  void didUpdateWidget(covariant _InstitutionOpportunityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.accessToken != widget.accessToken ||
        oldWidget.refreshVersion != widget.refreshVersion) {
      _loadCardData();
    }
  }

  void _loadCardData() {
    _activityFuture = _loadActivity();
  }

  Future<_InstitutionOpportunityActivity> _loadActivity() async {
    final results = await Future.wait([
      _applicationsRepository.fetchApplicationsByOpportunity(
        accessToken: widget.accessToken,
        opportunityId: widget.item.id,
      ),
      _applicationsRepository.fetchInvitesByOpportunity(
        accessToken: widget.accessToken,
        opportunityId: widget.item.id,
      ),
    ]);

    return _InstitutionOpportunityActivity(
      applications: results[0] as List<OpportunityApplicationSummary>,
      invites: results[1] as List<OpportunityInviteSummary>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDraft = widget.item.statusValue == 'DRAFT';
    final isOpen = widget.item.statusValue == 'OPEN';
    final canReopen = widget.item.statusValue == 'CANCELLED';

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
                    widget.item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                InfoBadge(label: widget.item.statusLabel),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InfoBadge(label: widget.item.specialtyLabel),
                InfoBadge(label: widget.item.shiftLabel),
                InfoBadge(label: widget.item.amountLabel),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
                if (isDraft)
                  ElevatedButton.icon(
                    onPressed: () => widget.onStatusChange('OPEN'),
                    icon: const Icon(Icons.publish_rounded),
                    label: const Text('Publicar'),
                  ),
                if (isOpen)
                  OutlinedButton.icon(
                    onPressed: () => widget.onStatusChange('CANCELLED'),
                    icon: const Icon(Icons.pause_circle_outline_rounded),
                    label: const Text('Cancelar vaga'),
                  ),
                if (canReopen)
                  OutlinedButton.icon(
                    onPressed: () => widget.onStatusChange('OPEN'),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reabrir vaga'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<_InstitutionOpportunityActivity>(
              future: _activityFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return const Text(
                    'Não foi possível carregar candidaturas e convites desta vaga.',
                  );
                }

                final activity =
                    snapshot.data ?? const _InstitutionOpportunityActivity();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OpportunityActivitySummary(
                      activity: activity,
                      isExpanded: _showDetails,
                      onToggleDetails: () {
                        setState(() => _showDetails = !_showDetails);
                      },
                    ),
                    if (_showDetails) ...[
                      const SizedBox(height: 16),
                      _OpportunityActivityDetails(
                        activity: activity,
                        accessToken: widget.accessToken,
                        opportunity: widget.item,
                        platformFeeRate: widget.platformFeeRate,
                        platformFeePercentLabel: widget.platformFeePercentLabel,
                        onEngagementCreated: widget.onEngagementCreated,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InstitutionOpportunityActivity {
  const _InstitutionOpportunityActivity({
    this.applications = const <OpportunityApplicationSummary>[],
    this.invites = const <OpportunityInviteSummary>[],
  });

  final List<OpportunityApplicationSummary> applications;
  final List<OpportunityInviteSummary> invites;

  int get pendingApplications =>
      applications.where((item) => item.statusValue == 'APPLIED').length;

  int get acceptedApplications =>
      applications.where((item) => item.statusValue == 'ACCEPTED').length;

  int get acceptedInvites =>
      invites.where((item) => item.statusValue == 'ACCEPTED').length;

  bool get hasActivity => applications.isNotEmpty || invites.isNotEmpty;

  bool get hasAcceptedProfessional =>
      acceptedApplications > 0 || acceptedInvites > 0;
}

class _OpportunityActivitySummary extends StatelessWidget {
  const _OpportunityActivitySummary({
    required this.activity,
    required this.isExpanded,
    required this.onToggleDetails,
  });

  final _InstitutionOpportunityActivity activity;
  final bool isExpanded;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = activity.hasAcceptedProfessional
        ? 'Profissional aceito aguardando fechamento'
        : activity.hasActivity
            ? 'Retorno da vaga'
            : 'Sem retorno ainda';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
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
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: activity.hasActivity ? onToggleDetails : null,
                  icon: Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                  label: Text(isExpanded ? 'Ocultar' : 'Ver detalhes'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoBadge(
                    label: '${activity.applications.length} candidaturas'),
                InfoBadge(label: '${activity.pendingApplications} pendentes'),
                InfoBadge(label: '${activity.invites.length} convites'),
                InfoBadge(label: '${activity.acceptedInvites} aceitos'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OpportunityActivityDetails extends StatelessWidget {
  const _OpportunityActivityDetails({
    required this.activity,
    required this.accessToken,
    required this.opportunity,
    required this.platformFeeRate,
    required this.platformFeePercentLabel,
    required this.onEngagementCreated,
  });

  final _InstitutionOpportunityActivity activity;
  final String accessToken;
  final InstitutionOpportunityOption opportunity;
  final double platformFeeRate;
  final String platformFeePercentLabel;
  final VoidCallback onEngagementCreated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Candidaturas recebidas', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        if (activity.applications.isEmpty)
          Text(
            'Nenhuma candidatura recebida para esta vaga ainda.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (var index = 0;
              index < activity.applications.length;
              index++) ...[
            _OpportunityApplicationStatusRow(
              item: activity.applications[index],
              accessToken: accessToken,
              opportunity: opportunity,
              platformFeeRate: platformFeeRate,
              platformFeePercentLabel: platformFeePercentLabel,
              onEngagementCreated: onEngagementCreated,
            ),
            if (index < activity.applications.length - 1)
              const SizedBox(height: 10),
          ],
        const SizedBox(height: 16),
        Text('Convites enviados', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        if (activity.invites.isEmpty)
          Text(
            'Nenhum convite enviado para esta vaga ainda.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (var index = 0; index < activity.invites.length; index++) ...[
            _OpportunityInviteStatusRow(
              item: activity.invites[index],
              accessToken: accessToken,
              opportunity: opportunity,
              platformFeeRate: platformFeeRate,
              platformFeePercentLabel: platformFeePercentLabel,
              onEngagementCreated: onEngagementCreated,
            ),
            if (index < activity.invites.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _OpportunityApplicationStatusRow extends StatefulWidget {
  const _OpportunityApplicationStatusRow({
    required this.item,
    required this.accessToken,
    required this.opportunity,
    required this.platformFeeRate,
    required this.platformFeePercentLabel,
    required this.onEngagementCreated,
  });

  final OpportunityApplicationSummary item;
  final String accessToken;
  final InstitutionOpportunityOption opportunity;
  final double platformFeeRate;
  final String platformFeePercentLabel;
  final VoidCallback onEngagementCreated;

  @override
  State<_OpportunityApplicationStatusRow> createState() =>
      _OpportunityApplicationStatusRowState();
}

class _OpportunityApplicationStatusRowState
    extends State<_OpportunityApplicationStatusRow> {
  final ApplicationsRepository _applicationsRepository =
      ApplicationsRepository();
  final EngagementsRepository _engagementsRepository = EngagementsRepository();
  bool _isResponding = false;
  late OpportunityApplicationSummary _currentItem;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
  }

  Future<void> _respond(bool accept) async {
    setState(() {
      _isResponding = true;
    });

    try {
      final message = await _applicationsRepository.respondApplication(
        accessToken: widget.accessToken,
        applicationId: widget.item.id,
        accept: accept,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentItem = OpportunityApplicationSummary(
          id: _currentItem.id,
          professionalUserId: _currentItem.professionalUserId,
          professionalName: _currentItem.professionalName,
          professionalEmail: _currentItem.professionalEmail,
          professionalRoleLabel: _currentItem.professionalRoleLabel,
          statusValue: accept ? 'ACCEPTED' : 'REJECTED',
          statusLabel: accept ? 'Candidatura aceita' : 'Candidatura recusada',
          appliedAtLabel: _currentItem.appliedAtLabel,
          message: _currentItem.message,
        );
      });

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
    } finally {
      if (mounted) {
        setState(() {
          _isResponding = false;
        });
      }
    }
  }

  Future<void> _finalizeShift() async {
    final grossAmount = widget.opportunity.grossAmount ?? 0;
    final platformFeeAmount = _calculatePlatformFee(grossAmount);

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Fechar plantão'),
            content: Text(
              'Deseja confirmar ${_currentItem.professionalName} para esta vaga?\n\nValor bruto: ${widget.opportunity.amountLabel}\nTaxa da plataforma (${widget.platformFeePercentLabel}): R\$ ${platformFeeAmount.toStringAsFixed(2)}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() {
      _isResponding = true;
    });

    try {
      final message = await _engagementsRepository.createEngagement(
        accessToken: widget.accessToken,
        opportunityId: widget.opportunity.id,
        professionalUserId: _currentItem.professionalUserId,
        sourceType: 'APPLICATION',
        sourceId: _currentItem.id,
        grossAmount: grossAmount,
      );

      if (!mounted) {
        return;
      }

      widget.onEngagementCreated();
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
    } finally {
      if (mounted) {
        setState(() {
          _isResponding = false;
        });
      }
    }
  }

  double _calculatePlatformFee(num grossAmount) {
    return _roundMoney(grossAmount.toDouble() * widget.platformFeeRate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = _currentItem;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.professionalName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InfoBadge(label: item.statusLabel),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.professionalRoleLabel} • ${item.professionalEmail}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.appliedAtLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (item.message != null && item.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Mensagem do profissional',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(item.message!),
          ],
          if (item.canRespond) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isResponding ? null : () => _respond(false),
                    child: const Text('Recusar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isResponding ? null : () => _respond(true),
                    child: _isResponding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Aceitar'),
                  ),
                ),
              ],
            ),
          ] else if (item.canFinalize) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isResponding ? null : _finalizeShift,
                icon: const Icon(Icons.handshake_rounded),
                label: const Text('Fechar plantão'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OpportunityInviteStatusRow extends StatelessWidget {
  const _OpportunityInviteStatusRow({
    required this.item,
    required this.accessToken,
    required this.opportunity,
    required this.platformFeeRate,
    required this.platformFeePercentLabel,
    required this.onEngagementCreated,
  });

  final OpportunityInviteSummary item;
  final String accessToken;
  final InstitutionOpportunityOption opportunity;
  final double platformFeeRate;
  final String platformFeePercentLabel;
  final VoidCallback onEngagementCreated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final engagementsRepository = EngagementsRepository();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.professionalName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InfoBadge(label: item.statusLabel),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.professionalEmail,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.invitedAtLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (item.canFinalize) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final grossAmount = opportunity.grossAmount ?? 0;
                  final platformFeeAmount =
                      _roundMoney(grossAmount.toDouble() * platformFeeRate);

                  final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Fechar plantão'),
                          content: Text(
                            'Deseja confirmar ${item.professionalName} para esta vaga?\n\nValor bruto: ${opportunity.amountLabel}\nTaxa da plataforma ($platformFeePercentLabel): R\$ ${platformFeeAmount.toStringAsFixed(2)}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Confirmar'),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (!confirmed || !context.mounted) {
                    return;
                  }

                  try {
                    final message =
                        await engagementsRepository.createEngagement(
                      accessToken: accessToken,
                      opportunityId: opportunity.id,
                      professionalUserId: item.professionalUserId,
                      sourceType: 'INVITE',
                      sourceId: item.id,
                      grossAmount: grossAmount,
                    );

                    if (!context.mounted) {
                      return;
                    }

                    onEngagementCreated();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  } on ApiException catch (error) {
                    if (!context.mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.message)),
                    );
                  }
                },
                icon: const Icon(Icons.handshake_rounded),
                label: const Text('Fechar plantão'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

double _roundMoney(double value) {
  return (value * 100).roundToDouble() / 100;
}

class _CreateOpportunitySheet extends StatefulWidget {
  const _CreateOpportunitySheet({
    this.initialOpportunity,
  });

  final InstitutionOpportunityOption? initialOpportunity;

  @override
  State<_CreateOpportunitySheet> createState() =>
      _CreateOpportunitySheetState();
}

class _OpportunityAudienceNotice extends StatelessWidget {
  const _OpportunityAudienceNotice({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateOpportunitySheetState extends State<_CreateOpportunitySheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _grossAmountController = TextEditingController();
  final _durationController = TextEditingController();
  final _startDateController = TextEditingController();
  final _startTimeController = TextEditingController(text: '19:00');
  final _endDateController = TextEditingController();
  final _endTimeController = TextEditingController(text: '07:00');
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  TimeOfDay _selectedStartTime = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay _selectedEndTime = const TimeOfDay(hour: 7, minute: 0);
  String _opportunityType = 'SHIFT';
  String _urgencyLevel = 'MEDIUM';
  final _customSpecialtyController = TextEditingController();
  bool _requiresVerifiedProfile = false;

  bool get _isEditMode => widget.initialOpportunity != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialOpportunity;
    if (initial == null) {
      return;
    }

    _titleController.text = initial.title;
    _descriptionController.text = initial.description;
    _grossAmountController.text = (initial.grossAmount ?? 0).toString();
    _durationController.text = initial.durationHours?.toString() ?? '';
    _customSpecialtyController.text = initial.customSpecialtyLabel ?? '';
    _opportunityType = initial.opportunityType;
    _urgencyLevel = initial.urgencyLevel;
    _requiresVerifiedProfile = initial.requiresVerifiedProfile;

    final parsedStartAt = DateTime.tryParse(initial.startAt)?.toLocal();
    final parsedEndAt = DateTime.tryParse(initial.endAt)?.toLocal();

    if (parsedStartAt != null) {
      _selectedStartDate = parsedStartAt;
      _selectedStartTime = TimeOfDay.fromDateTime(parsedStartAt);
      _startDateController.text = _formatBrazilianDate(parsedStartAt);
      _startTimeController.text = _formatTime(_selectedStartTime);
    }

    if (parsedEndAt != null) {
      _selectedEndDate = parsedEndAt;
      _selectedEndTime = TimeOfDay.fromDateTime(parsedEndAt);
      _endDateController.text = _formatBrazilianDate(parsedEndAt);
      _endTimeController.text = _formatTime(_selectedEndTime);
    }

    _syncDurationField();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _grossAmountController.dispose();
    _durationController.dispose();
    _customSpecialtyController.dispose();
    _startDateController.dispose();
    _startTimeController.dispose();
    _endDateController.dispose();
    _endTimeController.dispose();
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
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditMode ? 'Editar vaga' : 'Nova vaga',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _isEditMode
                    ? 'Atualize os dados principais da vaga para refletir a necessidade real da instituição.'
                    : 'Crie uma vaga institucional com os dados principais para já poder publicar e convidar profissionais.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titulo da vaga',
                  hintText: 'Ex.: Plantão noturno em clínica 24h',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Informe o titulo.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText:
                      'Descreva o tipo de atendimento, público, especialidade e contexto do plantão.',
                ),
                validator: (value) =>
                    (value == null || value.trim().length < 10)
                        ? 'Descreva melhor a vaga.'
                        : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _opportunityType,
                decoration: const InputDecoration(labelText: 'Tipo de vaga'),
                items: const [
                  DropdownMenuItem(
                      value: 'SHIFT', child: Text('Plantão veterinário')),
                  DropdownMenuItem(value: 'COVERAGE', child: Text('Cobertura')),
                  DropdownMenuItem(
                      value: 'TEMPORARY', child: Text('Temporario')),
                  DropdownMenuItem(
                    value: 'INTERNSHIP',
                    child: Text('Estágio - somente estagiários'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _opportunityType = value;
                    });
                  }
                },
              ),
              if (_opportunityType == 'INTERNSHIP') ...[
                const SizedBox(height: 10),
                const _OpportunityAudienceNotice(
                  message:
                      'Esta vaga será exibida apenas para perfis de estagiário.',
                ),
              ] else ...[
                const SizedBox(height: 10),
                const _OpportunityAudienceNotice(
                  message:
                      'Esta vaga será exibida para veterinários volantes, não para estagiários.',
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _customSpecialtyController,
                decoration: const InputDecoration(
                  labelText: 'Especialidade',
                  hintText: 'Ex.: Emergencia e Intensivismo',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Informe a especialidade.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _urgencyLevel,
                decoration: const InputDecoration(labelText: 'Urgencia'),
                items: const [
                  DropdownMenuItem(value: 'LOW', child: Text('Baixa')),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('Media')),
                  DropdownMenuItem(value: 'HIGH', child: Text('Alta')),
                  DropdownMenuItem(value: 'CRITICAL', child: Text('Critica')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _urgencyLevel = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startDateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Data de inicio',
                        hintText: '30/04/2026',
                        suffixIcon: Icon(Icons.calendar_month_rounded),
                      ),
                      onTap: () => _pickDate(isStart: true),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Selecione a data.'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _startTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Hora de inicio',
                        hintText: '19:00',
                        suffixIcon: Icon(Icons.access_time_rounded),
                      ),
                      onTap: () => _pickTime(isStart: true),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Selecione a hora.'
                              : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _endDateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Data de fim',
                        hintText: '01/05/2026',
                        suffixIcon: Icon(Icons.calendar_month_rounded),
                      ),
                      onTap: () => _pickDate(isStart: false),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Selecione a data.'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Hora de fim',
                        hintText: '07:00',
                        suffixIcon: Icon(Icons.access_time_rounded),
                      ),
                      onTap: () => _pickTime(isStart: false),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Selecione a hora.'
                              : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _grossAmountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valor bruto',
                        hintText: '850',
                      ),
                      validator: (value) {
                        final amount =
                            double.tryParse(value?.replaceAll(',', '.') ?? '');
                        if (amount == null || amount <= 0) {
                          return 'Informe um valor valido.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Duracao em horas',
                        hintText: 'Calculada automaticamente',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Preferir perfil validado'),
                subtitle: const Text(
                  'Não bloqueia candidaturas. Serve como sinal de confiança para destacar perfis mais completos.',
                ),
                value: _requiresVerifiedProfile,
                onChanged: (value) {
                  setState(() {
                    _requiresVerifiedProfile = value;
                  });
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(_isEditMode ? 'Salvar alteracoes' : 'Criar vaga'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final startAt = _combineSelectedDateAndTime(
      _selectedStartDate,
      _selectedStartTime,
    );
    final endAt = _combineSelectedDateAndTime(
      _selectedEndDate,
      _selectedEndTime,
    );

    if (startAt == null || endAt == null || !endAt.isAfter(startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revise a data e hora de inicio e fim da vaga.'),
        ),
      );
      return;
    }

    final input = CreateInstitutionOpportunityInput(
      title: _titleController.text,
      description: _descriptionController.text,
      opportunityType: _opportunityType,
      customSpecialtyLabel: _customSpecialtyController.text,
      startAt: startAt,
      endAt: endAt,
      grossAmount:
          double.parse(_grossAmountController.text.replaceAll(',', '.')),
      durationHours: _durationController.text.trim().isEmpty
          ? null
          : double.tryParse(_durationController.text.replaceAll(',', '.')),
      urgencyLevel: _urgencyLevel,
      requiresVerifiedProfile: _requiresVerifiedProfile,
    );

    Navigator.of(context).pop(input);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart
        ? (_selectedStartDate ?? DateTime.now())
        : (_selectedEndDate ?? _selectedStartDate ?? DateTime.now());

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _selectedStartDate = pickedDate;
        _startDateController.text = _formatBrazilianDate(pickedDate);

        if (_selectedEndDate != null &&
            _selectedEndDate!.isBefore(pickedDate)) {
          _selectedEndDate = pickedDate;
          _endDateController.text = _formatBrazilianDate(pickedDate);
        }
      } else {
        _selectedEndDate = pickedDate;
        _endDateController.text = _formatBrazilianDate(pickedDate);
      }

      _syncDurationField();
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: isStart ? _selectedStartTime : _selectedEndTime,
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _selectedStartTime = pickedTime;
        _startTimeController.text = _formatTime(pickedTime);
      } else {
        _selectedEndTime = pickedTime;
        _endTimeController.text = _formatTime(pickedTime);
      }

      _syncDurationField();
    });
  }

  DateTime? _combineSelectedDateAndTime(
    DateTime? date,
    TimeOfDay time,
  ) {
    if (date == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  String _formatBrazilianDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _syncDurationField() {
    final startAt = _combineSelectedDateAndTime(
      _selectedStartDate,
      _selectedStartTime,
    );
    final endAt = _combineSelectedDateAndTime(
      _selectedEndDate,
      _selectedEndTime,
    );

    if (startAt == null || endAt == null || !endAt.isAfter(startAt)) {
      _durationController.clear();
      return;
    }

    final durationInMinutes = endAt.difference(startAt).inMinutes;
    final durationInHours = durationInMinutes / 60;
    final isWholeNumber = durationInHours == durationInHours.roundToDouble();

    _durationController.text = isWholeNumber
        ? durationInHours.toStringAsFixed(0)
        : durationInHours.toStringAsFixed(1);
  }
}
