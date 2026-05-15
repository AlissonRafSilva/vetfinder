import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/info_badge.dart';
import '../data/opportunities_repository.dart';
import '../domain/opportunity_detail.dart';
import '../domain/opportunity_summary.dart';

class OpportunityDetailPage extends StatefulWidget {
  const OpportunityDetailPage({
    super.key,
    required this.summary,
  });

  final OpportunitySummary summary;

  @override
  State<OpportunityDetailPage> createState() => _OpportunityDetailPageState();
}

class _OpportunityDetailPageState extends State<OpportunityDetailPage> {
  final OpportunitiesRepository _repository = OpportunitiesRepository();
  final TextEditingController _messageController = TextEditingController();
  late Future<OpportunityDetail> _future;
  bool _isApplying = false;
  String? _applyFeedback;
  bool _isApplySuccess = false;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchOpportunityDetail(widget.summary.id);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _reload({bool clearFeedback = true}) {
    setState(() {
      _future = _repository.fetchOpportunityDetail(widget.summary.id);
      if (clearFeedback) {
        _applyFeedback = null;
      }
    });
  }

  Future<void> _apply(OpportunityDetail detail) async {
    final session = AppSessionScope.of(context);

    if (!session.isAuthenticated || session.accessToken == null) {
      setState(() {
        _isApplySuccess = false;
        _applyFeedback = 'Faca login antes de se candidatar.';
      });
      return;
    }

    if (!session.canApplyToOpportunities) {
      setState(() {
        _isApplySuccess = false;
        _applyFeedback =
            'Apenas veterinarios e estagiarios podem se candidatar a oportunidades.';
      });
      return;
    }

    if (session.userId != null && detail.applicantUserIds.contains(session.userId)) {
      setState(() {
        _isApplySuccess = false;
        _applyFeedback = 'Voce ja se candidatou a esta oportunidade.';
      });
      return;
    }

    setState(() {
      _isApplying = true;
      _applyFeedback = null;
    });

    try {
      final message = await _repository.applyToOpportunity(
        opportunityId: detail.id,
        accessToken: session.accessToken!,
        message: _messageController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isApplySuccess = true;
        _applyFeedback = message;
      });
      _reload(clearFeedback: false);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isApplySuccess = false;
        _applyFeedback = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isApplySuccess = false;
        _applyFeedback = 'Nao foi possivel enviar sua candidatura agora.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = AppSessionScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe da oportunidade'),
      ),
      body: FutureBuilder<OpportunityDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nao foi possivel carregar esta oportunidade.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _reload,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          final hasApplied =
              session.userId != null && detail.applicantUserIds.contains(session.userId);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.title,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    InfoBadge(label: detail.urgencyLabel),
                    InfoBadge(label: detail.statusLabel),
                    if (detail.requiresVerifiedProfile)
                      const InfoBadge(label: 'Prefere perfil validado'),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.institution,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(detail.description),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.4,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                detail.dateLabel,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                detail.durationLabel,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                label: 'Valor',
                                value: detail.amountLabel,
                                icon: Icons.payments_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                label: 'Local',
                                value: detail.locationLabel,
                                icon: Icons.place_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                label: 'Especialidade',
                                value: detail.specialty,
                                icon: Icons.local_hospital_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                label: 'Turno',
                                value: detail.shiftLabel,
                                icon: Icons.schedule_outlined,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Candidatura',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          session.isAuthenticated
                              ? 'Voce esta autenticado como ${session.email ?? 'usuario'}.'
                              : 'Faca login na aba Entrada para se candidatar.',
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _messageController,
                          minLines: 3,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Mensagem opcional',
                            hintText: 'Apresente sua disponibilidade ou experiencia.',
                          ),
                        ),
                        if (_applyFeedback != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _isApplySuccess
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _applyFeedback!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _isApplySuccess
                                    ? const Color(0xFF166534)
                                    : const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isApplying || hasApplied
                                ? null
                                : () => _apply(detail),
                            child: _isApplying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    hasApplied
                                        ? 'Candidatura ja enviada'
                                        : 'Quero me candidatar',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
