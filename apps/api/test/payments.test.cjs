const { test } = require('node:test');
const assert = require('node:assert/strict');
const { ConfigService } = require('@nestjs/config');
const { Prisma, PaymentStatus, SplitStatus, EngagementStatus } = require('@prisma/client');
const { AsaasService } = require('../src/modules/asaas/asaas.service');
const { AsaasWebhookController } = require('../src/modules/asaas/asaas-webhook.controller');
const { AsaasWebhookService } = require('../src/modules/asaas/asaas-webhook.service');
const { AsaasPaymentReconciliationService } = require('../src/modules/asaas/asaas-payment-reconciliation.service');
const { asaasPaymentStatus, asaasSplitStatus } = require('../src/modules/asaas/asaas-payment-state');
const { PaymentsService } = require('../src/modules/payments/payments.service');
const { EngagementsService } = require('../src/modules/engagements/engagements.service');
const { Global, Module } = require('@nestjs/common');
const { Test } = require('@nestjs/testing');
const { PrismaService } = require('../src/common/database/prisma.service');
const { PaymentsModule } = require('../src/modules/payments/payments.module');
const { PlatformConfigService } = require('../src/modules/platform/platform-config.service');

const paymentId = '00000000-0000-4000-8000-000000000001';
const engagementId = '00000000-0000-4000-8000-000000000002';
const user = { userId: 'clinic-user', role: 'CLINIC' };
const decimal = (value) => new Prisma.Decimal(value);
const quote = { serviceAmount: 257.5, chargeAmount: 259.49, gatewayFeeAmount: 1.99 };

test('the payment module resolves the gateway, webhook and reconciliation dependencies', async () => {
  class TestDependencies {}
  Global()(TestDependencies);
  Module({
    providers: [
      { provide: PrismaService, useValue: {} },
      { provide: ConfigService, useValue: new ConfigService({ PAYMENT_PROVIDER: 'disabled' }) },
    ],
    exports: [PrismaService, ConfigService],
  })(TestDependencies);
  const module = await Test.createTestingModule({ imports: [TestDependencies, PaymentsModule] }).compile();
  assert.ok(module.get(PaymentsService));
  assert.ok(module.get(AsaasPaymentReconciliationService));
  await module.close();
});

function payment(overrides = {}) {
  return {
    id: paymentId, engagementId, provider: 'asaas', providerPaymentId: 'pay_test',
    status: PaymentStatus.PENDING, providerStatus: 'PENDING', checkoutUrl: null,
    grossAmount: decimal(257.5), platformFeeAmount: decimal(7.5), netAmount: decimal(250),
    paidAt: null, refundedAt: null, createdAt: new Date(),
    providerPayload: {
      ...quote, pricingModel: 'INSTITUTION_PAYS_GATEWAY_FEE',
      professionalWalletId: 'wallet_test', environment: 'sandbox',
    },
    splits: [
      { id: 'platform-split', recipientType: 'PLATFORM', amount: decimal(7.5), status: SplitStatus.PENDING, processedAt: null },
      { id: 'professional-split', recipientType: 'PROFESSIONAL', amount: decimal(250), status: SplitStatus.PENDING, processedAt: null },
    ],
    ...overrides,
  };
}

function charge(overrides = {}) {
  return {
    id: 'pay_test', externalReference: paymentId, status: 'RECEIVED',
    value: 259.49, netValue: 257.5, billingType: 'PIX', customer: 'customer_test',
    invoiceUrl: 'https://example.test/invoice',
    split: [{ id: 'asaas_split', walletId: 'wallet_test', fixedValue: 250,
      status: 'AWAITING_CREDIT', externalReference: `payment-split-${paymentId}` }],
    ...overrides,
  };
}

function reconciliationFixture(initial = payment(), gateway = {}) {
  const state = {
    payment: initial, engagement: { id: engagementId, status: EngagementStatus.PENDING_PAYMENT },
    event: { id: 'event-local', processingStatus: 'RECEIVED' }, writes: 0,
  };
  const tx = {
    $queryRaw: async () => [],
    payment: {
      findUnique: async () => state.payment,
      findUniqueOrThrow: async () => state.payment,
      update: async ({ data }) => { state.writes++; Object.assign(state.payment, data); return state.payment; },
    },
    paymentSplit: {
      update: async ({ where, data }) => Object.assign(state.payment.splits.find(item => item.id === where.id), data),
    },
    engagement: {
      updateMany: async ({ where, data }) => {
        if (typeof where.status === 'string' && state.engagement.status !== where.status) return { count: 0 };
        Object.assign(state.engagement, data); return { count: 1 };
      },
    },
    asaasWebhookEvent: {
      findUnique: async () => state.event,
      update: async ({ data }) => Object.assign(state.event, data),
    },
  };
  const prisma = { ...tx, $transaction: async (work) => work(tx) };
  return { state, prisma, service: new AsaasPaymentReconciliationService(prisma, gateway) };
}

test('late payment events cannot undo a receipt or a refund', () => {
  for (const status of ['PENDING', 'CONFIRMED', 'OVERDUE', 'DELETED']) {
    assert.equal(asaasPaymentStatus(PaymentStatus.PAID, status), PaymentStatus.PAID);
  }
  assert.equal(asaasPaymentStatus(PaymentStatus.REFUNDED, 'RECEIVED'), PaymentStatus.REFUNDED);
  assert.equal(asaasPaymentStatus(PaymentStatus.PARTIALLY_REFUNDED, 'RECEIVED'), PaymentStatus.PARTIALLY_REFUNDED);
  assert.equal(asaasPaymentStatus(PaymentStatus.PAID, 'REFUNDED'), PaymentStatus.REFUNDED);
  assert.equal(asaasPaymentStatus(PaymentStatus.PAID, 'CHARGEBACK_REQUESTED'), PaymentStatus.FAILED);
  assert.equal(asaasPaymentStatus(PaymentStatus.FAILED, 'RECEIVED'), PaymentStatus.PAID);
});

test('a completed split remains transferred after an older payment notification', () => {
  assert.equal(asaasSplitStatus({ current: SplitStatus.TRANSFERRED,
    paymentStatus: PaymentStatus.PAID, providerStatus: 'PENDING' }), SplitStatus.TRANSFERRED);
  assert.equal(asaasSplitStatus({ current: SplitStatus.SCHEDULED,
    paymentStatus: PaymentStatus.PAID, splitDone: true }), SplitStatus.TRANSFERRED);
  assert.equal(asaasSplitStatus({ current: SplitStatus.TRANSFERRED,
    paymentStatus: PaymentStatus.REFUNDED, providerStatus: 'DONE' }), SplitStatus.FAILED);
});

test('reconciliation rejects a different amount, reference or destination before writing', async () => {
  for (const invalid of [charge({ value: 180 }), charge({ externalReference: 'another-payment' }),
    charge({ split: [{ ...charge().split[0], walletId: 'someone-else' }] }),
    charge({ split: [...charge().split, { walletId: 'unexpected-recipient', fixedValue: 5 }] }),
    charge({ split: [{ ...charge().split[0], percentualValue: 97 }] }),
    charge({ billingType: 'CREDIT_CARD' })]) {
    const fixture = reconciliationFixture();
    await assert.rejects(fixture.service.applyCharge(paymentId, invalid), /diverg/);
    assert.equal(fixture.state.writes, 0);
  }
});

test('an early webhook can associate the charge before the creation response is stored', async () => {
  const fixture = reconciliationFixture(payment({ providerPaymentId: null, providerStatus: 'CREATING' }));
  await fixture.service.applyCharge(paymentId, charge());
  assert.equal(fixture.state.payment.providerPaymentId, 'pay_test');
  assert.equal(fixture.state.payment.status, PaymentStatus.PAID);
  const paidAt = fixture.state.payment.paidAt;
  await fixture.service.applyCharge(paymentId, charge({ status: 'PENDING' }));
  assert.equal(fixture.state.payment.status, PaymentStatus.PAID);
  assert.equal(fixture.state.payment.providerStatus, 'RECEIVED');
  assert.equal(fixture.state.payment.paidAt, paidAt);
});

test('payment confirmation does not reopen a completed contract', async () => {
  const fixture = reconciliationFixture();
  fixture.state.engagement.status = EngagementStatus.COMPLETED;
  await fixture.service.applyCharge(paymentId, charge());
  assert.equal(fixture.state.engagement.status, EngagementStatus.COMPLETED);
});

test('a refund does not reinterpret the returned balance as a new gateway fee', async () => {
  const fixture = reconciliationFixture(payment({ status: PaymentStatus.PAID }));
  await fixture.service.applyCharge(paymentId, charge({ status: 'REFUNDED', netValue: 0 }));
  assert.equal(fixture.state.payment.status, PaymentStatus.REFUNDED);
  assert.equal(fixture.state.payment.providerPayload.gatewayFeeAmount, 1.99);
  assert.notEqual(fixture.state.payment.providerPayload.financialDivergence, true);
});

test('a changed gateway net value requires reconciliation instead of confirming the contract', async () => {
  const fixture = reconciliationFixture();
  await fixture.service.applyCharge(paymentId, charge({ netValue: 179 }));
  assert.equal(fixture.state.payment.providerPayload.financialDivergence, true);
  assert.equal(fixture.state.payment.splits[1].status, SplitStatus.FAILED);
  assert.equal(fixture.state.engagement.status, EngagementStatus.DISPUTED);
});

test('split settlement stores the provider reference and processes an event once', async () => {
  const fixture = reconciliationFixture();
  const context = { eventType: 'PAYMENT_SPLIT_DONE', splitId: 'asaas_split', webhookEventId: 'event-local' };
  await fixture.service.applyCharge(paymentId, charge(), context);
  assert.equal(fixture.state.payment.splits[1].status, SplitStatus.TRANSFERRED);
  assert.equal(fixture.state.payment.splits[1].transferReference, 'asaas_split');
  assert.ok(fixture.state.payment.splits[1].processedAt instanceof Date);
  assert.equal(fixture.state.event.processingStatus, 'PROCESSED');
  const writes = fixture.state.writes;
  await fixture.service.applyCharge(paymentId, charge(), context);
  assert.equal(fixture.state.writes, writes);
});

test('an unrelated split event cannot mark the professional as paid', async () => {
  const fixture = reconciliationFixture();
  await fixture.service.applyCharge(paymentId, charge(), {
    eventType: 'PAYMENT_SPLIT_DONE', splitId: 'another-split',
  });
  assert.equal(fixture.state.payment.splits[1].status, SplitStatus.SCHEDULED);
});

test('refresh queries Asaas and recovers an interrupted creation by external reference', async () => {
  let recoveredReference;
  const fixture = reconciliationFixture(payment({ providerPaymentId: null }), {
    findChargeByExternalReference: async (reference) => { recoveredReference = reference; return charge(); },
  });
  const result = await fixture.service.refresh(paymentId);
  assert.equal(recoveredReference, paymentId);
  assert.equal(result.status, PaymentStatus.PAID);
});

test('an abandoned creation can be retried only after the lease and a negative Asaas lookup', async () => {
  for (const elapsed of [60_000, 6 * 60_000]) {
    let lookedUp = false;
    const fixture = reconciliationFixture(payment({
      providerPaymentId: null, providerStatus: 'CREATING',
      providerPayload: { ...payment().providerPayload,
        creationStartedAt: new Date(Date.now() - elapsed).toISOString() },
    }), { findChargeByExternalReference: async () => { lookedUp = true; return undefined; } });
    const result = await fixture.service.refresh(paymentId);
    assert.equal(lookedUp, true);
    assert.equal(result.status, elapsed > 5 * 60_000 ? PaymentStatus.FAILED : PaymentStatus.PENDING);
  }
});

test('a gateway outage cannot release the creation lease for a duplicate charge', async () => {
  const fixture = reconciliationFixture(payment({ providerPaymentId: null, providerStatus: 'CREATING' }), {
    findChargeByExternalReference: async () => { throw new Error('gateway unavailable'); },
  });
  await assert.rejects(fixture.service.refresh(paymentId), /unavailable/);
  assert.equal(fixture.state.writes, 0);
});

test('an old receipt cannot hide a chargeback without an authoritative gateway refresh', async () => {
  const fixture = reconciliationFixture();
  await fixture.service.applyCharge(paymentId, charge({ status: 'CHARGEBACK_REQUESTED' }),
    { eventType: 'PAYMENT_CHARGEBACK_REQUESTED' });
  await fixture.service.applyCharge(paymentId, charge(), { eventType: 'PAYMENT_RECEIVED' });
  assert.equal(fixture.state.payment.status, PaymentStatus.FAILED);
  assert.equal(fixture.state.payment.providerStatus, 'CHARGEBACK_REQUESTED');
  assert.equal(fixture.state.payment.splits[1].status, SplitStatus.FAILED);
  assert.equal(fixture.state.engagement.status, EngagementStatus.DISPUTED);
});

function asaas() {
  return new AsaasService(new ConfigService({
    ASAAS_API_KEY: 'sandbox-test-only', ASAAS_ENVIRONMENT: 'sandbox',
    ASAAS_API_URL: 'https://api-sandbox.asaas.com/v3', PAYMENT_PROVIDER: 'asaas',
    ASAAS_WEBHOOK_TOKEN: 'x'.repeat(32), ASAAS_WEBHOOK_URL: 'https://example.test/webhook',
    ASAAS_WEBHOOK_EMAIL: 'test@example.test',
  }));
}

test('the clinic covers the simulated fixed fee and preserves the service amount', async (t) => {
  const simulated = [];
  t.mock.method(globalThis, 'fetch', async (_url, init) => {
    const value = JSON.parse(init.body).value;
    simulated.push(value);
    return Response.json({ pix: { netValue: value - 1.99 } });
  });
  assert.deepEqual(await asaas().quotePixCharge(257.5), quote);
  assert.deepEqual(simulated, [257.5, 259.49]);
});

test('the clinic also covers a percentage fee without subtracting from the professional', async (t) => {
  t.mock.method(globalThis, 'fetch', async (_url, init) => {
    const value = JSON.parse(init.body).value;
    return Response.json({ pix: { netValue: Math.round(value * 0.99 * 100) / 100 } });
  });
  const result = await asaas().quotePixCharge(257.5);
  assert.equal(result.serviceAmount, 257.5);
  assert.equal(result.chargeAmount, 260.1);
  assert.equal(result.gatewayFeeAmount, 2.6);
});

test('a missing gateway fee cannot silently become a zero-cost quote', async (t) => {
  t.mock.method(globalThis, 'fetch', async () => Response.json({ pix: {} }));
  await assert.rejects(asaas().quotePixCharge(180), /tarifa/);
});

test('an existing charge is reused only if the amount and fixed split match', async (t) => {
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async (_url, init) => {
    calls++;
    assert.equal(init.method, 'GET');
    return Response.json({ data: [charge()] });
  });
  const result = await asaas().createPixCharge({ customerId: 'customer_test', externalReference: paymentId,
    description: 'Test', value: 259.49, dueDate: '2026-12-01', professionalWalletId: 'wallet_test',
    professionalAmount: 250, splitExternalReference: `payment-split-${paymentId}` });
  assert.equal(result.id, 'pay_test');
  assert.equal(calls, 1);
});

test('the webhook requires the secret token before processing any event', () => {
  let called = false;
  const controller = new AsaasWebhookController(new ConfigService({ ASAAS_WEBHOOK_TOKEN: 'x'.repeat(32) }),
    { receive: () => { called = true; } });
  assert.throws(() => controller.receive('incorrect', {}), /autorizado/);
  assert.equal(called, false);
});

test('a new Asaas charge fixes the professional split at the full requested 250', async (t) => {
  let posted;
  t.mock.method(globalThis, 'fetch', async (_url, init) => {
    if (init.method === 'GET') return Response.json({ data: [] });
    posted = JSON.parse(init.body);
    return Response.json(charge({ status: 'PENDING' }));
  });
  await asaas().createPixCharge({
    customerId: 'customer_test', externalReference: paymentId, description: 'Test',
    value: 259.49, dueDate: '2026-12-01', professionalWalletId: 'wallet_test',
    professionalAmount: 250, splitExternalReference: `payment-split-${paymentId}`,
  });
  assert.equal(posted.value, 259.49);
  assert.equal(posted.split.length, 1);
  assert.equal(posted.split[0].fixedValue, 250);
  assert.equal(posted.split[0].percentualValue, undefined);
});

test('the webhook matches a fast payment event by the local reference', async () => {
  let search;
  let reconciled;
  const prisma = {
    asaasWebhookEvent: { create: async () => ({ id: 'event-local' }) },
    payment: { findFirst: async (query) => { search = query; return { id: paymentId }; } },
  };
  const service = new AsaasWebhookService(prisma, {
    applyCharge: async (...args) => { reconciled = args; },
  });
  await service.receive({ id: 'evt_test', event: 'PAYMENT_RECEIVED', payment: charge() });
  assert.equal(search.where.provider, 'asaas');
  assert.deepEqual(search.where.OR, [{ providerPaymentId: 'pay_test' }, { id: paymentId }]);
  assert.equal(reconciled[0], paymentId);
});

function checkoutFixture() {
  const state = { payment: null, chargeCalls: 0, chargeInput: null, quotes: 0 };
  const engagement = {
    id: engagementId, professionalUserId: 'professional-user', status: EngagementStatus.PENDING_PAYMENT,
    grossAmount: decimal(257.5), platformFeeAmount: decimal(7.5), netAmount: decimal(250),
    institution: { id: 'institution', userId: user.userId, legalName: 'Test clinic',
      tradeName: 'Test clinic', cnpj: 'test-document', contactPhone: null,
      user: { email: 'clinic@example.test' }, address: null },
  };
  const prisma = {
    $queryRaw: async () => [],
    engagement: { findUnique: async () => ({ ...engagement, payment: state.payment }) },
    asaasAccount: { findUnique: async () => ({ asaasWalletId: 'wallet_test', accountStatus: 'ACTIVE', onboardingStatus: 'APPROVED' }) },
    payment: {
      create: async ({ data }) => {
        if (state.payment) throw new Prisma.PrismaClientKnownRequestError('unique', { code: 'P2002', clientVersion: '5.22.0' });
        state.payment = payment({ ...data, providerPaymentId: null }); return state.payment;
      },
      findUniqueOrThrow: async () => state.payment,
      findUnique: async () => state.payment,
      update: async ({ data }) => { Object.assign(state.payment, data); return state.payment; },
      updateMany: async ({ data }) => { Object.assign(state.payment, data); return { count: 1 }; },
    },
    paymentSplit: {
      createMany: async () => ({ count: 2 }),
      update: async ({ where, data }) => Object.assign(state.payment.splits.find(item => item.id === where.id), data),
    },
    $transaction: async (work) => work(prisma),
  };
  const gateway = {
    isEnabled: () => true, getEnvironment: () => 'sandbox',
    quotePixCharge: async (subtotal) => { assert.equal(subtotal, 257.5); state.quotes++; return quote; },
    ensureCustomer: async () => ({ id: 'customer_test' }),
    createPixCharge: async (input) => { state.chargeCalls++; state.chargeInput = input; return charge({ status: 'PENDING' }); },
    getPixQrCode: async () => ({ payload: 'test-pix' }),
  };
  prisma.engagement.updateMany = async ({ where, data }) => {
    if (typeof where.status === 'string' && engagement.status !== where.status) return { count: 0 };
    Object.assign(engagement, data); return { count: 1 };
  };
  const reconciliation = new AsaasPaymentReconciliationService(prisma, gateway);
  return { state, engagement, gateway, service: new PaymentsService(prisma, {}, gateway, reconciliation) };
}

test('fee consent is required before creating the charge', async () => {
  const fixture = checkoutFixture();
  await assert.rejects(fixture.service.create({ engagementId }, user), /Confirme/);
  assert.equal(fixture.state.payment, null);
  assert.equal(fixture.state.chargeCalls, 0);
});

test('the quote presents 250 for the professional plus 7.50 commission and the simulated gateway fee', async () => {
  const fixture = checkoutFixture();
  const result = await fixture.service.quote({ engagementId }, user);
  assert.equal(result.serviceAmount, 250);
  assert.equal(result.professionalAmount, 250);
  assert.equal(result.platformFeeAmount, 7.5);
  assert.equal(result.subtotalAmount, 257.5);
  assert.equal(result.chargeAmount, 259.49);
  assert.equal(result.gatewayFeeAmount, 1.99);
  assert.equal(result.platformFeePayer, 'INSTITUTION');
  assert.equal(fixture.state.chargeCalls, 0);
});

test('a changed fee cannot be charged using the clinic previous consent', async () => {
  const fixture = checkoutFixture();
  await assert.rejects(fixture.service.create({ engagementId, expectedChargeAmount: 181 }, user), /tarifa/);
  assert.equal(fixture.state.payment, null);
  assert.equal(fixture.state.chargeCalls, 0);
});

test('only the owning clinic can create a payment', async () => {
  const fixture = checkoutFixture();
  await assert.rejects(fixture.service.create({ engagementId, expectedChargeAmount: 259.49 },
    { ...user, userId: 'someone-else' }), /Voce nao pode/);
  assert.equal(fixture.state.chargeCalls, 0);
});

test('cancelled contracts cannot be charged', async () => {
  const fixture = checkoutFixture();
  fixture.engagement.status = EngagementStatus.CANCELLED;
  await assert.rejects(fixture.service.create({ engagementId, expectedChargeAmount: 259.49 }, user), /aguardando/);
  assert.equal(fixture.state.chargeCalls, 0);
});

test('duplicate checkout requests create one external charge and preserve the agreed split', async () => {
  const fixture = checkoutFixture();
  const request = { engagementId, expectedChargeAmount: 259.49 };
  const responses = await Promise.all([fixture.service.create(request, user), fixture.service.create(request, user)]);
  assert.equal(fixture.state.chargeCalls, 1);
  assert.equal(responses[0].payment.id, responses[1].payment.id);
  assert.equal(fixture.state.chargeInput.value, 259.49);
  assert.equal(fixture.state.chargeInput.professionalAmount, 250);
  assert.equal(fixture.state.payment.platformFeeAmount.toNumber(), 7.5);
  assert.equal(fixture.state.payment.providerPayload.gatewayFeePayer, 'INSTITUTION');
  assert.equal(fixture.state.payment.providerPayload.platformFeePayer, 'INSTITUTION');
  assert.equal(fixture.state.payment.providerPayload.serviceAmount, 250);
  assert.equal(fixture.state.payment.providerPayload.subtotalAmount, 257.5);
});

function engagementFixture(startAt = new Date(Date.now() + 3_600_000)) {
  const state = { claims: 0, contracts: 0, claim: null, contract: null };
  const prisma = {
    opportunity: {
      findUnique: async () => ({ id: 'opportunity', title: 'Test shift', status: 'OPEN',
        institutionId: 'institution', opportunityType: 'SHIFT', startAt,
        institution: { userId: user.userId, verificationStatus: 'APPROVED' } }),
      updateMany: async (query) => {
        state.claim = query;
        return { count: state.claims++ === 0 ? 1 : 0 };
      },
    },
    engagement: {
      findFirst: async () => null,
      create: async ({ data }) => { state.contracts++; state.contract = data; return { id: engagementId, ...data }; },
    },
    opportunityApplication: {
      findUnique: async () => ({ id: 'application', opportunityId: 'opportunity',
        professionalUserId: 'professional', status: 'ACCEPTED' }),
      update: async () => ({}),
    },
    user: { findUnique: async () => ({ id: 'professional', role: 'VETERINARIAN' }) },
    $transaction: async (work) => work(prisma),
  };
  const platform = new PlatformConfigService(new ConfigService({ PLATFORM_FEE_RATE: '0.03' }));
  const service = new EngagementsService(prisma, platform, { createForUser: async () => ({}) });
  const request = { opportunityId: 'opportunity', professionalUserId: 'professional',
    sourceType: 'APPLICATION', sourceId: 'application', grossAmount: 250 };
  return { state, service, request };
}

test('a started shift cannot become a new payable contract', async () => {
  const fixture = engagementFixture(new Date(Date.now() - 60_000));
  await assert.rejects(fixture.service.create(fixture.request, user), /ja comecou/);
  assert.equal(fixture.state.contracts, 0);
});

test('closing a 250 shift preserves the professional amount and adds the platform commission', async () => {
  const fixture = engagementFixture();
  await fixture.service.create({ ...fixture.request, platformFeeAmount: 0 }, user);
  assert.equal(fixture.state.contract.netAmount, 250);
  assert.equal(fixture.state.contract.platformFeeAmount, 7.5);
  assert.equal(fixture.state.contract.grossAmount, 257.5);
});

test('commission uses decimal rounding and never reduces the professional amount', () => {
  const platform = new PlatformConfigService(new ConfigService({ PLATFORM_FEE_RATE: '0.03' }));
  assert.deepEqual(platform.calculateEngagementAmounts(10.5), {
    netAmount: 10.5, platformFeeAmount: 0.32, grossAmount: 10.82,
  });
});

test('competing closures must atomically claim an open future shift', async () => {
  const fixture = engagementFixture();
  const responses = await Promise.allSettled([
    fixture.service.create(fixture.request, user), fixture.service.create(fixture.request, user),
  ]);
  assert.equal(responses.filter(item => item.status === 'fulfilled').length, 1);
  assert.equal(fixture.state.contracts, 1);
  assert.equal(fixture.state.claim.where.status, 'OPEN');
  assert.ok(fixture.state.claim.where.startAt.gt instanceof Date);
});
