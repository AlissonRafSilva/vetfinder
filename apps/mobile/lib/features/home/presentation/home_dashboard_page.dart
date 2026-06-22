import 'package:flutter/material.dart';

import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/info_badge.dart';
import '../../auth/domain/app_user_role.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({
    super.key,
    this.onOpenMarketplace,
    this.onOpenSchedule,
    this.onOpenOpportunities,
    this.onOpenEngagements,
    this.onOpenNotifications,
    this.onOpenProfile,
  });

  final VoidCallback? onOpenMarketplace;
  final VoidCallback? onOpenSchedule;
  final VoidCallback? onOpenOpportunities;
  final VoidCallback? onOpenEngagements;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final isInstitution = session.isInstitutionUser;
    final roleLabel = _roleLabel(session.roleValue);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommercialHero(
            title: isInstitution
                ? 'Contrate plantonistas com mais velocidade'
                : 'Encontre plantões compatíveis com seu perfil',
            subtitle: isInstitution
                ? 'Publique vagas, acompanhe candidatos e convide profissionais disponíveis na sua região.'
                : 'Veja oportunidades próximas, mantenha sua agenda disponível e fortaleça sua reputação.',
            roleLabel: roleLabel,
            statusLabel: _statusLabel(session.status),
            onPrimaryAction:
                isInstitution ? onOpenOpportunities : onOpenMarketplace,
            primaryActionLabel:
                isInstitution ? 'Criar ou ver vagas' : 'Ver plantões',
            onSecondaryAction: onOpenProfile,
            secondaryActionLabel: 'Completar perfil',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              InfoBadge(
                icon: Icons.verified_user_rounded,
                label: 'Confiança por validação',
              ),
              InfoBadge(
                icon: Icons.location_on_rounded,
                label: 'Busca por região',
              ),
              InfoBadge(
                icon: Icons.payments_rounded,
                label: 'Pagamento com split',
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Próximos passos',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
          ),
          const SizedBox(height: 12),
          if (isInstitution)
            _InstitutionActionGrid(
              onOpenMarketplace: onOpenMarketplace,
              onOpenOpportunities: onOpenOpportunities,
              onOpenEngagements: onOpenEngagements,
              onOpenNotifications: onOpenNotifications,
              onOpenProfile: onOpenProfile,
            )
          else
            _ProfessionalActionGrid(
              onOpenMarketplace: onOpenMarketplace,
              onOpenSchedule: onOpenSchedule,
              onOpenEngagements: onOpenEngagements,
              onOpenNotifications: onOpenNotifications,
              onOpenProfile: onOpenProfile,
            ),
          const SizedBox(height: 22),
          _TrustPanel(isInstitution: isInstitution),
        ],
      ),
    );
  }

  String _roleLabel(String? value) {
    if (value == AppUserRole.veterinarian.apiValue) {
      return 'Veterinário volante';
    }

    if (value == AppUserRole.intern.apiValue) {
      return 'Estagiário';
    }

    if (value == AppUserRole.clinic.apiValue) {
      return 'Clínica veterinária';
    }

    if (value == AppUserRole.hospital.apiValue) {
      return 'Hospital veterinário';
    }

    return 'Conta VetFinder';
  }

  String _statusLabel(String? value) {
    if (value == 'APPROVED') {
      return 'Perfil verificado';
    }

    if (value == 'UNDER_REVIEW') {
      return 'Em análise';
    }

    if (value == 'REJECTED') {
      return 'Ajuste pendente';
    }

    return 'Cadastro em andamento';
  }
}

class _CommercialHero extends StatelessWidget {
  const _CommercialHero({
    required this.title,
    required this.subtitle,
    required this.roleLabel,
    required this.statusLabel,
    required this.primaryActionLabel,
    required this.secondaryActionLabel,
    this.onPrimaryAction,
    this.onSecondaryAction,
  });

  final String title;
  final String subtitle;
  final String roleLabel;
  final String statusLabel;
  final String primaryActionLabel;
  final String secondaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.tertiary.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -42,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroBadge(label: roleLabel),
                  _HeroBadge(label: statusLabel),
                ],
              ),
              const SizedBox(height: 24),
              Icon(
                Icons.pets_rounded,
                color: Colors.white.withValues(alpha: 0.92),
                size: 38,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: onPrimaryAction,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(primaryActionLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onSecondaryAction,
                    icon: const Icon(Icons.person_rounded),
                    label: Text(secondaryActionLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ProfessionalActionGrid extends StatelessWidget {
  const _ProfessionalActionGrid({
    this.onOpenMarketplace,
    this.onOpenSchedule,
    this.onOpenEngagements,
    this.onOpenNotifications,
    this.onOpenProfile,
  });

  final VoidCallback? onOpenMarketplace;
  final VoidCallback? onOpenSchedule;
  final VoidCallback? onOpenEngagements;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.search_rounded,
          title: 'Encontrar plantões',
          message: 'Veja vagas abertas por proximidade, valor e especialidade.',
          actionLabel: 'Abrir plantões',
          onTap: onOpenMarketplace,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.calendar_month_rounded,
          title: 'Disponibilizar agenda',
          message: 'Mostre seus horários livres para receber convites melhores.',
          actionLabel: 'Atualizar agenda',
          onTap: onOpenSchedule,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.handshake_rounded,
          title: 'Acompanhar contratos',
          message: 'Confira plantões fechados, pagamentos e avaliações.',
          actionLabel: 'Ver contratos',
          onTap: onOpenEngagements,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.notifications_rounded,
          title: 'Responder alertas',
          message: 'Convites e respostas importantes ficam centralizados.',
          actionLabel: 'Ver alertas',
          onTap: onOpenNotifications,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.verified_user_rounded,
          title: 'Fortalecer perfil',
          message: 'Documentos, localização e reputação aumentam sua conversão.',
          actionLabel: 'Abrir perfil',
          onTap: onOpenProfile,
        ),
      ],
    );
  }
}

class _InstitutionActionGrid extends StatelessWidget {
  const _InstitutionActionGrid({
    this.onOpenMarketplace,
    this.onOpenOpportunities,
    this.onOpenEngagements,
    this.onOpenNotifications,
    this.onOpenProfile,
  });

  final VoidCallback? onOpenMarketplace;
  final VoidCallback? onOpenOpportunities;
  final VoidCallback? onOpenEngagements;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.work_history_rounded,
          title: 'Publicar ou editar vagas',
          message: 'Crie plantões, estágios e oportunidades temporárias.',
          actionLabel: 'Abrir minhas vagas',
          onTap: onOpenOpportunities,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.groups_rounded,
          title: 'Buscar disponíveis',
          message: 'Encontre profissionais por agenda, distância e especialidade.',
          actionLabel: 'Ver disponíveis',
          onTap: onOpenMarketplace,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.handshake_rounded,
          title: 'Gerenciar contratações',
          message: 'Acompanhe plantões fechados, pagamentos e avaliações.',
          actionLabel: 'Ver contratações',
          onTap: onOpenEngagements,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.notifications_rounded,
          title: 'Monitorar respostas',
          message: 'Convites, candidaturas e confirmações aparecem em alertas.',
          actionLabel: 'Ver alertas',
          onTap: onOpenNotifications,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.apartment_rounded,
          title: 'Completar instituição',
          message: 'Dados e documentos verificados aumentam a confiança da vaga.',
          actionLabel: 'Abrir perfil',
          onTap: onOpenProfile,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      actionLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustPanel extends StatelessWidget {
  const _TrustPanel({required this.isInstitution});

  final bool isInstitution;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.70),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como aumentar suas chances',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          _TrustItem(
            icon: Icons.badge_rounded,
            text: isInstitution
                ? 'Mantenha CNPJ, endereço e documentos institucionais atualizados.'
                : 'Mantenha CRMV, matrícula ou documentos profissionais atualizados.',
          ),
          _TrustItem(
            icon: Icons.schedule_rounded,
            text: isInstitution
                ? 'Descreva horário, valor, especialidade e urgência com clareza.'
                : 'Cadastre uma agenda recorrente para aparecer melhor nas buscas.',
          ),
          _TrustItem(
            icon: Icons.star_rounded,
            text:
                'Avaliações escritas e histórico de contratos constroem reputação dentro da plataforma.',
          ),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
