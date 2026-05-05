import 'package:flutter/material.dart';

import '../../../core/widgets/info_badge.dart';
import '../domain/engagement_summary.dart';

class EngagementDetailPage extends StatelessWidget {
  const EngagementDetailPage({
    super.key,
    required this.item,
    required this.isInstitutionView,
  });

  final EngagementSummary item;
  final bool isInstitutionView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryPersonLabel =
        isInstitutionView ? 'Profissional confirmado' : 'Instituicao';
    final primaryPersonValue =
        isInstitutionView ? item.professionalName : item.institutionName;
    final primaryPersonSubtitle =
        isInstitutionView ? item.professionalRoleLabel : 'Contratante';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do plantao'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        InfoBadge(label: item.statusLabel),
                        InfoBadge(label: item.sourceLabel),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      item.opportunityTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.shiftLabel,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _DetailSection(
              title: primaryPersonLabel,
              children: [
                _DetailRow(label: 'Nome', value: primaryPersonValue),
                _DetailRow(label: 'Perfil', value: primaryPersonSubtitle),
                if (isInstitutionView && item.professionalEmail.isNotEmpty)
                  _DetailRow(label: 'Email', value: item.professionalEmail),
              ],
            ),
            const SizedBox(height: 14),
            _DetailSection(
              title: 'Plantao',
              children: [
                _DetailRow(label: 'Especialidade', value: item.specialtyLabel),
                _DetailRow(label: 'Horario', value: item.shiftLabel),
                _DetailRow(label: 'Fechamento', value: item.createdAtLabel),
                _DetailRow(label: 'Status', value: item.statusLabel),
              ],
            ),
            const SizedBox(height: 14),
            _DetailSection(
              title: 'Financeiro',
              children: [
                _DetailRow(label: 'Valor bruto', value: item.grossAmountLabel),
                _DetailRow(
                  label: 'Taxa da plataforma',
                  value: item.platformFeeLabel,
                ),
                _DetailRow(
                  label: 'Valor liquido profissional',
                  value: item.netAmountLabel,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.payments_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pagamento em preparacao',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'O plantao ja foi fechado. A cobranca real e o split serao habilitados quando o gateway juridicamente validado for escolhido.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
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
