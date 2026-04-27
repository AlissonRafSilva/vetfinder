import '../domain/opportunity_summary.dart';

const mockOpportunities = [
  OpportunitySummary(
    id: 'opp-1',
    title: 'Plantao noturno de 12h',
    institution: 'Hospital Vet Leste',
    specialty: 'Emergencia e intensivismo',
    shiftLabel: 'Hoje, 19h as 7h',
    amountLabel: 'R\$ 850',
    distanceLabel: '4,2 km',
    urgencyLabel: 'Urgente',
  ),
  OpportunitySummary(
    id: 'opp-2',
    title: 'Cobertura clinica de pequenos animais',
    institution: 'Clinica Bicho Bem',
    specialty: 'Clinica geral',
    shiftLabel: 'Amanha, 8h as 18h',
    amountLabel: 'R\$ 550',
    distanceLabel: '7,8 km',
    urgencyLabel: 'Alta demanda',
  ),
  OpportunitySummary(
    id: 'opp-3',
    title: 'Estagio supervisionado em internacao',
    institution: 'Hospital Pet 24h',
    specialty: 'Estagio geral',
    shiftLabel: 'Seg a sex, 13h as 18h',
    amountLabel: 'Bolsa a combinar',
    distanceLabel: '11 km',
    urgencyLabel: 'Novo',
  ),
];
