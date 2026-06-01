import 'package:flutter/material.dart';

import '../../../core/widgets/info_badge.dart';
import '../../availability/domain/available_professional_summary.dart';

class AvailableProfessionalProfilePage extends StatelessWidget {
  const AvailableProfessionalProfilePage({
    super.key,
    required this.professional,
    required this.onInvite,
  });

  final AvailableProfessionalSummary professional;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil do profissional'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: professional.isVerified
                              ? theme.colorScheme.primary.withValues(alpha: 0.12)
                              : theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            professional.isVerified
                                ? Icons.verified_rounded
                                : Icons.person_outline_rounded,
                            color: professional.isVerified
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                professional.name,
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                professional.roleLabel,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  InfoBadge(label: professional.verificationLabel),
                                  InfoBadge(label: professional.completenessLabel),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _TrustPanel(professional: professional),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _ProfileDetailsCard(professional: professional),
            const SizedBox(height: 18),
            _AvailabilityCard(professional: professional),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onInvite();
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('Convidar para uma vaga'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustPanel extends StatelessWidget {
  const _TrustPanel({
    required this.professional,
  });

  final AvailableProfessionalSummary professional;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: professional.isVerified
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            professional.isVerified
                ? Icons.workspace_premium_outlined
                : Icons.trending_up_rounded,
            color: professional.isVerified
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  professional.trustLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(professional.trustDescription),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailsCard extends StatelessWidget {
  const _ProfileDetailsCard({
    required this.professional,
  });

  final AvailableProfessionalSummary professional;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dados principais',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            _DetailRow(label: 'Contato', value: professional.email),
            _DetailRow(label: 'Regiao', value: professional.cityLabel),
            _DetailRow(label: 'Area', value: professional.specialtyLabel),
            _DetailRow(label: 'Valor', value: professional.rateLabel),
            _DetailRow(label: 'Reputacao', value: professional.reputationLabel),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.professional,
  });

  final AvailableProfessionalSummary professional;

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
              'Agenda disponivel',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Horários encontrados conforme o filtro aplicado pela instituição.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (professional.availability.isEmpty)
              const Text('Nenhum horário exibido para este filtro.')
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: professional.availability
                    .map((slot) => InfoBadge(label: slot.displayLabel))
                    .toList(),
              ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
