const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  AsaasAccountsService,
} = require('../src/modules/asaas/asaas-accounts.service');

function fixture({
  externalPayment = false,
  gatewayUnavailable = false,
  racingPayment = false,
  productionPayment = false,
} = {}) {
  const state = {
    pendingSplits: 1,
    activePayments: 0,
    deleted: false,
    audited: false,
    refreshed: 0,
    locked: false,
  };
  const account = {
    id: 'account',
    environment: 'SANDBOX',
    accountStatus: 'ACTIVE',
    onboardingStatus: 'APPROVED',
  };
  const prisma = {
    $queryRaw: async () => {
      state.locked = true;
      if (racingPayment) state.activePayments = 1;
    },
    asaasAccount: {
      findUnique: async () => account,
      findFirst: async () => null,
      delete: async () => {
        assert.equal(state.locked, true);
        state.deleted = true;
      },
    },
    payment: {
      findMany: async () => [
        {
          id: 'failed-payment',
          providerPayload: productionPayment
            ? { environment: 'production' }
            : null,
        },
      ],
      count: async () => state.activePayments,
    },
    paymentSplit: { count: async () => state.pendingSplits },
    auditLog: {
      create: async () => {
        state.audited = true;
      },
    },
    $transaction: async (work) => work(prisma),
  };
  const reconciliation = {
    refresh: async () => {
      state.refreshed++;
      if (gatewayUnavailable) throw new Error('gateway unavailable');
      if (externalPayment) state.activePayments = 1;
      else state.pendingSplits = 0;
    },
  };
  return {
    state,
    service: new AsaasAccountsService(
      prisma,
      { getEnvironment: () => 'sandbox', isEnabled: () => true },
      reconciliation,
    ),
  };
}

test('Sandbox reset reconciles an old failed creation before checking pending splits', async () => {
  const { service, state } = fixture();
  await service.resetMine({ userId: 'professional' });
  assert.equal(state.refreshed, 1);
  assert.equal(state.deleted, true);
  assert.equal(state.audited, true);
});

test('Sandbox reset remains blocked when the old charge exists at Asaas', async () => {
  const { service, state } = fixture({ externalPayment: true });
  await assert.rejects(
    () => service.resetMine({ userId: 'professional' }),
    /pendentes/,
  );
  assert.equal(state.deleted, false);
});

test('a gateway outage cannot be interpreted as permission to reset a wallet', async () => {
  const { service, state } = fixture({ gatewayUnavailable: true });
  await assert.rejects(
    () => service.resetMine({ userId: 'professional' }),
    /unavailable/,
  );
  assert.equal(state.deleted, false);
});

test('an intervening payment lease blocks a Sandbox reset even after recovery', async () => {
  const { service, state } = fixture({ racingPayment: true });
  await assert.rejects(
    () => service.resetMine({ userId: 'professional' }),
    /pendentes/,
  );
  assert.equal(state.deleted, false);
});

test('Sandbox reset never reconciles a payment explicitly tagged as production', async () => {
  const { service, state } = fixture({ productionPayment: true });
  await assert.rejects(
    () => service.resetMine({ userId: 'professional' }),
    /pendentes/,
  );
  assert.equal(state.refreshed, 0);
  assert.equal(state.deleted, false);
});
