const fs = require('node:fs');
const path = require('node:path');
const dotenv = require('dotenv');

const sandboxUrl = 'https://api-sandbox.asaas.com/v3';
const webhookUrl = 'https://vetfinder-api.onrender.com/v1/payments/asaas/webhook';
const requiredEvents = [
  'PAYMENT_CREATED', 'PAYMENT_UPDATED', 'PAYMENT_CONFIRMED', 'PAYMENT_RECEIVED',
  'PAYMENT_OVERDUE', 'PAYMENT_DELETED', 'PAYMENT_REFUNDED', 'PAYMENT_PARTIALLY_REFUNDED',
  'PAYMENT_SPLIT_DONE', 'PAYMENT_SPLIT_CANCELLED',
  'PAYMENT_SPLIT_DIVERGENCE_BLOCK', 'PAYMENT_SPLIT_DIVERGENCE_BLOCK_FINISHED',
];

function validateConfig(config) {
  if (config.ASAAS_ENVIRONMENT?.trim().toLowerCase() !== 'sandbox' ||
      config.ASAAS_API_URL?.trim().replace(/\/+$/, '') !== sandboxUrl) {
    throw new Error('SANDBOX_CONFIGURATION_REQUIRED');
  }
  const key = config.ASAAS_API_KEY?.trim();
  if (!key || key.startsWith('$aact_prod_')) throw new Error('SANDBOX_KEY_REQUIRED');
  return key;
}

async function checkSandbox(config, { fetchImpl = fetch, quote, emit = console.log } = {}) {
  const key = validateConfig(config);
  const request = async (endpoint) => {
    const response = await fetchImpl(sandboxUrl + endpoint, {
      headers: { access_token: key, Accept: 'application/json', 'User-Agent': 'VetFinder/sandbox-diagnostic' },
      signal: AbortSignal.timeout(25000),
    });
    if (!response.ok) throw new Error(`ASAAS_HTTP_${response.status}`);
    return response.json();
  };
  const status = await request('/myAccount/status/');
  const allowedStatuses = ['APPROVED', 'PENDING', 'AWAITING_APPROVAL', 'REJECTED'];
  emit(JSON.stringify({ check: 'authentication', ok: true,
    general: allowedStatuses.includes(status.general) ? status.general : 'UNKNOWN' }));
  const accounts = await request('/accounts?limit=1');
  emit(JSON.stringify({ check: 'parent_account_access', ok: true,
    subaccountCount: Number.isInteger(accounts.totalCount) ? accounts.totalCount : null }));
  if (!quote) {
    const { ConfigService } = require('@nestjs/config');
    const { AsaasService } = require('../src/modules/asaas/asaas.service');
    const service = new AsaasService(new ConfigService({ ...config, PAYMENT_PROVIDER: 'asaas' }));
    quote = (amount) => service.quotePixCharge(amount);
  }
  const amounts = await quote(257.5);
  emit(JSON.stringify({ check: 'pix_quote', professionalAmount: 250, platformFeeAmount: 7.5,
    chargeAmount: amounts.chargeAmount, gatewayFeeAmount: amounts.gatewayFeeAmount }));
  const hooks = await request('/webhooks?limit=100');
  const matching = (hooks.data ?? []).filter((hook) => hook.url === webhookUrl);
  const hook = matching[0];
  const missingEvents = requiredEvents.filter((event) => !hook?.events?.includes(event));
  const ready = status.general === 'APPROVED' && matching.length === 1 && hook.enabled === true &&
    hook.interrupted === false && hook.hasAuthToken === true && missingEvents.length === 0;
  emit(JSON.stringify({ check: 'webhook', ready, matches: matching.length,
    hasAuthToken: hook?.hasAuthToken === true, missingEvents }));
  return { ready };
}

async function main() {
  // Read this file explicitly so stale shell variables cannot override a new key.
  const filename = path.resolve(__dirname, '../.env.asaas.local');
  try {
    const source = fs.readFileSync(filename, 'utf8');
    const definitions = source.split(/\r?\n/).filter((line) => /^\s*(export\s+)?ASAAS_API_KEY\s*=/.test(line));
    if (definitions.length !== 1) throw new Error('ONE_KEY_DEFINITION_REQUIRED');
    const config = dotenv.parse(source);
    validateConfig(config);
    console.log(JSON.stringify({ check: 'source', file: filename, modifiedUtc: fs.statSync(filename).mtime.toISOString() }));
    const result = await checkSandbox(config);
    if (!result.ready) process.exitCode = 2;
  } catch (error) {
    // Do not print exception messages, provider payloads, tokens or customer records.
    const safeCodes = /^(SANDBOX_CONFIGURATION_REQUIRED|SANDBOX_KEY_REQUIRED|ONE_KEY_DEFINITION_REQUIRED|ASAAS_HTTP_\d{3})$/;
    const code = safeCodes.test(error.message) ? error.message : 'DIAGNOSTIC_FAILED';
    console.error(JSON.stringify({ check: 'failure', code }));
    process.exitCode = 2;
  }
}

module.exports = { validateConfig, checkSandbox };
if (require.main === module) main();
