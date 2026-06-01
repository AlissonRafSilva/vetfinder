import 'package:flutter/material.dart';

import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../data/engagements_repository.dart';
import '../domain/engagement_summary.dart';
import 'engagement_detail_page.dart';

class InstitutionEngagementsPage extends StatefulWidget {
  const InstitutionEngagementsPage({super.key});

  @override
  State<InstitutionEngagementsPage> createState() =>
      _InstitutionEngagementsPageState();
}

class _InstitutionEngagementsPageState
    extends State<InstitutionEngagementsPage> {
  final EngagementsRepository _engagementsRepository = EngagementsRepository();
  Future<List<EngagementSummary>>? _engagementsFuture;
  String? _loadedSessionKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  void _refresh() {
    final session = AppSessionScope.of(context);
    final sessionKey = '${session.userId}:${session.accessToken}';

    if (!session.isAuthenticated || !session.isInstitutionUser) {
      _engagementsFuture = null;
      _loadedSessionKey = null;
      return;
    }

    if (_loadedSessionKey == sessionKey && _engagementsFuture != null) {
      return;
    }

    _loadedSessionKey = sessionKey;
    _engagementsFuture = _engagementsRepository.fetchMyInstitutionEngagements(
      accessToken: session.accessToken!,
    );
  }

  void _forceRefresh() {
    setState(() {
      _loadedSessionKey = null;
      _refresh();
    });
  }

  Future<void> _openDetail(EngagementSummary item) async {
    final shouldRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EngagementDetailPage(
          item: item,
          isInstitutionView: true,
        ),
      ),
    );

    if (shouldRefresh == true && mounted) {
      _forceRefresh();
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
              title: 'Contratações',
              subtitle:
                  'Faça login como clínica ou hospital para acompanhar os plantões fechados.',
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
              title: 'Contratações',
              subtitle:
                  'Esta área é exclusiva para clínicas e hospitais acompanharem plantões fechados.',
            ),
            SizedBox(height: 18),
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Entre com um perfil institucional para ver os fechamentos realizados.',
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
            title: 'Contratações',
            subtitle:
                'Acompanhe os plantões já fechados, o profissional confirmado e os valores da operação.',
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              InfoBadge(label: 'Plantões fechados'),
              InfoBadge(label: 'Valores detalhados'),
              InfoBadge(label: 'Fluxo institucional'),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _forceRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Atualizar contratações'),
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<EngagementSummary>>(
            future: _engagementsFuture,
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
                          'Não foi possível carregar as contratações.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tente novamente para atualizar os plantões já fechados.',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _forceRefresh,
                          child: const Text('Atualizar'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final items = snapshot.data ?? const <EngagementSummary>[];
              if (items.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nenhum plantão fechado foi encontrado ainda.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Depois de confirmar um plantão, toque em atualizar para recarregar a lista.',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _forceRefresh,
                          child: const Text('Atualizar'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    _EngagementCard(
                      item: items[index],
                      onTap: () => _openDetail(items[index]),
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

class _EngagementCard extends StatelessWidget {
  const _EngagementCard({
    required this.item,
    required this.onTap,
  });

  final EngagementSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.opportunityTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                InfoBadge(label: item.statusLabel),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${item.professionalName} - ${item.professionalRoleLabel}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.professionalEmail,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InfoBadge(label: item.specialtyLabel),
                InfoBadge(label: item.shiftLabel),
                InfoBadge(label: item.sourceLabel),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.35),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumo financeiro',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  Text('Bruto: ${item.grossAmountLabel}'),
                  Text('Taxa da plataforma: ${item.platformFeeLabel}'),
                  Text('Liquido do profissional: ${item.netAmountLabel}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.createdAtLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Toque para ver detalhes',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
