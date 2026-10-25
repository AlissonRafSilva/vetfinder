const { test } = require('node:test');
const assert = require('node:assert/strict');
const { validateConfig, checkSandbox } = require('../scripts/check-asaas-sandbox.cjs');

const config = {
  ASAAS_ENVIRONMENT: 'sandbox', ASAAS_API_URL: 'https://api-sandbox.asaas.com/v3',
  ASAAS_API_KEY: '$aact_hmlg_test_secret_not_for_logging',
};

test('the gateway diagnostic refuses production or arbitrary hosts before sending secrets', async () => {
  let requests = 0;
  for (const change of [
    { ASAAS_ENVIRONMENT: 'production' },
    { ASAAS_API_URL: 'https://other.example/v3' },
    { ASAAS_API_KEY: '$aact_prod_test' },
  ]) {
    await assert.rejects(() => checkSandbox({ ...config, ...change }, {
      fetchImpl: async () => { requests++; },
    }));
  }
  assert.equal(requests, 0);
  assert.equal(validateConfig(config), config.ASAAS_API_KEY);
});

test('the diagnostic reads hasAuthToken without reporting tokens or customer identities', async () => {
  const output = [];
  const events = ['PAYMENT_CREATED','PAYMENT_UPDATED','PAYMENT_CONFIRMED','PAYMENT_RECEIVED',
    'PAYMENT_OVERDUE','PAYMENT_DELETED','PAYMENT_REFUNDED','PAYMENT_PARTIALLY_REFUNDED',
    'PAYMENT_SPLIT_DONE','PAYMENT_SPLIT_CANCELLED','PAYMENT_SPLIT_DIVERGENCE_BLOCK','PAYMENT_SPLIT_DIVERGENCE_BLOCK_FINISHED'];
  const fetchImpl = async (url, options) => {
    assert.equal(options.headers.access_token, config.ASAAS_API_KEY);
    assert.equal(options.body, undefined);
    const body = url.includes('/myAccount/') ? {general:'APPROVED'} :
      url.includes('/accounts?') ? {totalCount:1, data:[{email:'private@example.test',apiKey:config.ASAAS_API_KEY}]} :
      { data: [{url:'https://vetfinder-api.onrender.com/v1/payments/asaas/webhook', enabled:true,
        interrupted:false, hasAuthToken:true, events, authToken:'private_webhook_secret'}] };
    return {ok:true, json: async () => body};
  };
  const result = await checkSandbox(config, {
    fetchImpl, quote: async () => ({chargeAmount:259.49,gatewayFeeAmount:1.99}), emit: (value) => output.push(value),
  });
  assert.equal(result.ready, true);
  for (const secret of [config.ASAAS_API_KEY,'private@example.test','private_webhook_secret']) {
    assert.equal(output.join('').includes(secret), false);
  }
});
