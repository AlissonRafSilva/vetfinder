import 'package:flutter/material.dart';
import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../core/widgets/section_header.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = AppSessionScope.of(context);
    final isInstitution = session.isInstitutionUser;
    final sectionTitle = isInstitution ? 'Perfil da instituicao' : 'Perfil profissional';
    final sectionSubtitle = isInstitution
        ? 'Dados da instituicao, sessao ativa e visibilidade operacional na plataforma.'
        : 'Validacao, reputacao e informacoes visiveis na plataforma.';
    final helperText = isInstitution
        ? 'Instituicao autenticada para publicar vagas, convidar profissionais e acompanhar respostas.'
        : 'Usuario autenticado para candidaturas e fluxos protegidos.';
    final avatarIcon =
        isInstitution ? Icons.apartment_rounded : Icons.pets_rounded;

    if (!session.isAuthenticated) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(
              title: sectionTitle,
              subtitle: 'Faca login para visualizar os dados da sua sessao.',
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
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
                              session.email ?? 'Usuario autenticado',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              session.roleValue ?? 'Perfil nao identificado',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      InfoBadge(label: session.status ?? 'Ativo'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Sessao atual',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      InfoBadge(label: session.roleValue ?? 'Perfil'),
                      InfoBadge(label: session.status ?? 'Status'),
                      const InfoBadge(label: 'JWT ativo'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    helperText,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use a aba Entrada para trocar de conta ou sair da sessao.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: session.logout,
                    child: const Text('Encerrar sessao'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
