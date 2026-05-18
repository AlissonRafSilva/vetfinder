import {
  AccountStatus,
  AvailabilityType,
  InstitutionType,
  OpportunityStatus,
  OpportunityType,
  PrismaClient,
  UrgencyLevel,
  UserRole,
  VerificationStatus,
} from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

const specialties = [
  { name: 'Clinica Geral', slug: 'clinica-geral' },
  { name: 'Cirurgia', slug: 'cirurgia' },
  { name: 'Anestesiologia', slug: 'anestesiologia' },
  { name: 'Emergencia e Intensivismo', slug: 'emergencia-intensivismo' },
  { name: 'Dermatologia', slug: 'dermatologia' },
  { name: 'Cardiologia', slug: 'cardiologia' },
  { name: 'Ortopedia', slug: 'ortopedia' },
  { name: 'Diagnostico por Imagem', slug: 'diagnostico-por-imagem' },
  { name: 'Felinos', slug: 'felinos' },
  { name: 'Animais Silvestres', slug: 'animais-silvestres' },
  { name: 'Estagio Geral', slug: 'estagio-geral' },
];

async function upsertSpecialties() {
  for (const specialty of specialties) {
    await prisma.specialty.upsert({
      where: { slug: specialty.slug },
      create: specialty,
      update: {
        name: specialty.name,
        active: true,
      },
    });
  }
}

async function seedDemoData() {
  const passwordHash = await bcrypt.hash('vetfinder123', 10);

  await prisma.user.upsert({
    where: { email: 'admin.demo@vetfinder.app' },
    update: {
      passwordHash,
      role: UserRole.ADMIN,
      status: AccountStatus.ACTIVE,
    },
    create: {
      email: 'admin.demo@vetfinder.app',
      passwordHash,
      role: UserRole.ADMIN,
      status: AccountStatus.ACTIVE,
    },
  });

  const clinicAddress = await prisma.address.create({
    data: {
      zipCode: '01310-100',
      street: 'Avenida Paulista',
      number: '900',
      district: 'Bela Vista',
      city: 'Sao Paulo',
      state: 'SP',
      country: 'BR',
      lat: -23.5616840,
      lng: -46.6561390,
    },
  });

  const shiftAddress = await prisma.address.create({
    data: {
      zipCode: '04538-132',
      street: 'Rua Gomes de Carvalho',
      number: '1356',
      district: 'Vila Olimpia',
      city: 'Sao Paulo',
      state: 'SP',
      country: 'BR',
      lat: -23.5950600,
      lng: -46.6853330,
    },
  });

  const overnightAddress = await prisma.address.create({
    data: {
      zipCode: '04038-002',
      street: 'Rua Borges Lagoa',
      number: '1180',
      district: 'Vila Clementino',
      city: 'Sao Paulo',
      state: 'SP',
      country: 'BR',
      lat: -23.5994700,
      lng: -46.6450580,
    },
  });

  const clinicUser = await prisma.user.upsert({
    where: { email: 'clinica.demo@vetfinder.app' },
    update: {
      phone: '11940000001',
      passwordHash,
      role: UserRole.CLINIC,
      status: AccountStatus.ACTIVE,
    },
    create: {
      email: 'clinica.demo@vetfinder.app',
      phone: '11940000001',
      passwordHash,
      role: UserRole.CLINIC,
      status: AccountStatus.ACTIVE,
    },
  });

  await prisma.institution.upsert({
    where: { userId: clinicUser.id },
    update: {
      institutionType: InstitutionType.CLINIC,
      legalName: 'Clinica Veterinaria VetFinder Demo Ltda',
      tradeName: 'VetFinder Demo',
      cnpj: '12.345.678/0001-99',
      description: 'Clinica demonstracao para testes do marketplace.',
      contactName: 'Paula Mendes',
      contactPhone: '11940000001',
      verificationStatus: VerificationStatus.APPROVED,
      addressId: clinicAddress.id,
    },
    create: {
      userId: clinicUser.id,
      institutionType: InstitutionType.CLINIC,
      legalName: 'Clinica Veterinaria VetFinder Demo Ltda',
      tradeName: 'VetFinder Demo',
      cnpj: '12.345.678/0001-99',
      description: 'Clinica demonstracao para testes do marketplace.',
      contactName: 'Paula Mendes',
      contactPhone: '11940000001',
      verificationStatus: VerificationStatus.APPROVED,
      addressId: clinicAddress.id,
    },
  });

  const veterinarianUser = await prisma.user.upsert({
    where: { email: 'veterinario.demo@vetfinder.app' },
    update: {
      phone: '11950000002',
      passwordHash,
      role: UserRole.VETERINARIAN,
      status: AccountStatus.ACTIVE,
    },
    create: {
      email: 'veterinario.demo@vetfinder.app',
      phone: '11950000002',
      passwordHash,
      role: UserRole.VETERINARIAN,
      status: AccountStatus.ACTIVE,
    },
  });

  await prisma.profile.upsert({
    where: { userId: veterinarianUser.id },
    update: {
      fullName: 'Dra Marina Lopes',
      city: 'Sao Paulo',
      state: 'SP',
      bio: 'Veterinaria volante com foco em urgencia e pequenos animais.',
      isVisible: true,
    },
    create: {
      userId: veterinarianUser.id,
      fullName: 'Dra Marina Lopes',
      city: 'Sao Paulo',
      state: 'SP',
      bio: 'Veterinaria volante com foco em urgencia e pequenos animais.',
      isVisible: true,
    },
  });

  await prisma.veterinarianProfile.upsert({
    where: {
      crmvNumber_crmvState: {
        crmvNumber: '12345',
        crmvState: 'SP',
      },
    },
    update: {
      userId: veterinarianUser.id,
      verificationStatus: VerificationStatus.APPROVED,
      baseShiftRate: 700,
      yearsExperience: 6,
      emergencyCare: true,
      canTravel: true,
      maxDistanceKm: 25,
    },
    create: {
      userId: veterinarianUser.id,
      crmvNumber: '12345',
      crmvState: 'SP',
      verificationStatus: VerificationStatus.APPROVED,
      baseShiftRate: 700,
      yearsExperience: 6,
      emergencyCare: true,
      canTravel: true,
      maxDistanceKm: 25,
    },
  });

  const internAddress = await prisma.address.create({
    data: {
      zipCode: '04023-062',
      street: 'Rua Botucatu',
      number: '740',
      district: 'Vila Clementino',
      city: 'Sao Paulo',
      state: 'SP',
      country: 'BR',
      lat: -23.5987630,
      lng: -46.6451200,
    },
  });

  const internUser = await prisma.user.upsert({
    where: { email: 'estagiario.demo@vetfinder.app' },
    update: {
      phone: '11960000003',
      passwordHash,
      role: UserRole.INTERN,
      status: AccountStatus.ACTIVE,
    },
    create: {
      email: 'estagiario.demo@vetfinder.app',
      phone: '11960000003',
      passwordHash,
      role: UserRole.INTERN,
      status: AccountStatus.ACTIVE,
    },
  });

  await prisma.profile.upsert({
    where: { userId: internUser.id },
    update: {
      fullName: 'Lucas Ferreira',
      city: 'Sao Paulo',
      state: 'SP',
      bio: 'Estagiario de medicina veterinaria com interesse em internacao e clinica medica.',
      isVisible: true,
      addressId: internAddress.id,
    },
    create: {
      userId: internUser.id,
      fullName: 'Lucas Ferreira',
      city: 'Sao Paulo',
      state: 'SP',
      bio: 'Estagiario de medicina veterinaria com interesse em internacao e clinica medica.',
      isVisible: true,
      addressId: internAddress.id,
    },
  });

  await prisma.internProfile.upsert({
    where: { userId: internUser.id },
    update: {
      universityName: 'Universidade VetFinder Demo',
      coursePeriod: '8 periodo',
      expectedGraduationDate: new Date('2026-12-15T00:00:00.000Z'),
      verificationStatus: VerificationStatus.APPROVED,
    },
    create: {
      userId: internUser.id,
      universityName: 'Universidade VetFinder Demo',
      coursePeriod: '8 periodo',
      expectedGraduationDate: new Date('2026-12-15T00:00:00.000Z'),
      verificationStatus: VerificationStatus.APPROVED,
    },
  });

  await prisma.availabilitySlot.deleteMany({
    where: { userId: internUser.id },
  });

  await prisma.availabilitySlot.createMany({
    data: [
      {
        userId: internUser.id,
        availabilityType: AvailabilityType.RECURRING,
        weekday: 1,
        startTime: '08:00',
        endTime: '14:00',
      },
      {
        userId: internUser.id,
        availabilityType: AvailabilityType.RECURRING,
        weekday: 3,
        startTime: '13:00',
        endTime: '19:00',
      },
      {
        userId: internUser.id,
        availabilityType: AvailabilityType.RECURRING,
        weekday: 5,
        startTime: '08:00',
        endTime: '18:00',
      },
    ],
  });

  const clinic = await prisma.institution.findUniqueOrThrow({
    where: { userId: clinicUser.id },
    select: { id: true },
  });

  const emergencySpecialty = await prisma.specialty.findUniqueOrThrow({
    where: { slug: 'emergencia-intensivismo' },
  });

  const generalSpecialty = await prisma.specialty.findUniqueOrThrow({
    where: { slug: 'clinica-geral' },
  });

  const internshipSpecialty = await prisma.specialty.findUniqueOrThrow({
    where: { slug: 'estagio-geral' },
  });

  await prisma.professionalSpecialty.upsert({
    where: {
      userId_specialtyId: {
        userId: veterinarianUser.id,
        specialtyId: emergencySpecialty.id,
      },
    },
    update: {},
    create: {
      userId: veterinarianUser.id,
      specialtyId: emergencySpecialty.id,
    },
  });

  await prisma.professionalSpecialty.upsert({
    where: {
      userId_specialtyId: {
        userId: internUser.id,
        specialtyId: internshipSpecialty.id,
      },
    },
    update: {},
    create: {
      userId: internUser.id,
      specialtyId: internshipSpecialty.id,
    },
  });

  const opportunities = [
    {
      title: 'Plantao noturno de 12h',
      description:
        'Necessidade imediata para cobertura de plantao noturno com atendimento de caes e gatos.',
      opportunityType: OpportunityType.SHIFT,
      specialtyId: emergencySpecialty.id,
      startAt: new Date('2026-04-22T19:00:00.000Z'),
      endAt: new Date('2026-04-23T07:00:00.000Z'),
      durationHours: 12,
      grossAmount: 850,
      urgencyLevel: UrgencyLevel.HIGH,
      addressId: overnightAddress.id,
      requiresVerifiedProfile: true,
    },
    {
      title: 'Cobertura clinica de pequenos animais',
      description:
        'Cobertura temporaria para consultas de rotina, triagem e apoio ao time fixo durante horario comercial.',
      opportunityType: OpportunityType.COVERAGE,
      specialtyId: generalSpecialty.id,
      startAt: new Date('2026-04-23T11:00:00.000Z'),
      endAt: new Date('2026-04-23T21:00:00.000Z'),
      durationHours: 10,
      grossAmount: 550,
      urgencyLevel: UrgencyLevel.MEDIUM,
      addressId: shiftAddress.id,
      requiresVerifiedProfile: true,
    },
    {
      title: 'Estagio supervisionado em internacao',
      description:
        'Vaga de estagio com foco em internacao, observacao clinica e suporte assistido a equipe medica.',
      opportunityType: OpportunityType.INTERNSHIP,
      specialtyId: internshipSpecialty.id,
      startAt: new Date('2026-04-24T16:00:00.000Z'),
      endAt: new Date('2026-04-24T21:00:00.000Z'),
      durationHours: 5,
      grossAmount: 180,
      urgencyLevel: UrgencyLevel.LOW,
      addressId: clinicAddress.id,
      requiresVerifiedProfile: false,
    },
  ];

  for (const opportunity of opportunities) {
    const existing = await prisma.opportunity.findFirst({
      where: {
        institutionId: clinic.id,
        title: opportunity.title,
      },
      select: { id: true },
    });

    if (existing) {
      await prisma.opportunity.update({
        where: { id: existing.id },
        data: {
          ...opportunity,
          institutionId: clinic.id,
          status: OpportunityStatus.OPEN,
        },
      });
      continue;
    }

    await prisma.opportunity.create({
      data: {
        ...opportunity,
        institutionId: clinic.id,
        status: OpportunityStatus.OPEN,
      },
    });
  }
}

async function main() {
  await upsertSpecialties();
  await seedDemoData();

  console.log('Seed concluido com especialidades, contas demo e oportunidades abertas.');
  console.log('Admin demo: admin.demo@vetfinder.app / vetfinder123');
  console.log('Clinica demo: clinica.demo@vetfinder.app / vetfinder123');
  console.log('Veterinario demo: veterinario.demo@vetfinder.app / vetfinder123');
  console.log('Estagiario demo: estagiario.demo@vetfinder.app / vetfinder123');
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
