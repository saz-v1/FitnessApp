import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign } from 'node:crypto';
import { createGateway, verifier, Limiter, validateInput } from './gateway.mjs';
const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const now = 1800000000000;
const claims = { iss: 'https://auth.example.test', aud: 'fitswift', sub: 'device-1', iat: now / 1000, exp: now / 1000 + 300, scope: 'fitness:ai' };
const token = (overrides = {}, header = { alg: 'RS256', typ: 'JWT' }, key = privateKey) => {
  const body = [header, { ...claims, ...overrides }].map(value => Buffer.from(JSON.stringify(value)).toString('base64url')).join('.');
  return `Bearer ${body}.${sign('sha256', Buffer.from(body), key).toString('base64url')}`;
};
const authenticate = verifier({ publicKey: publicKey.export({ type: 'spki', format: 'pem' }), issuer: claims.iss, audience: claims.aud, now: () => now });
const request = { authorization: token(), ip: '127.0.0.1', body: { operation: 'calories', description: '2 slices of pizza', consent: true } };
const provider = text => new Response(JSON.stringify({ stop_reason: 'end_turn', content: [{ type: 'text', text }] }));

test('accepts signed short-lived scoped tokens', () => assert.equal(authenticate(token()), 'device-1'));
test('rejects missing, unsigned, wrong-key, expired, future and incorrect-claim tokens', () => {
  const other = generateKeyPairSync('rsa', { modulusLength: 2048 });
  for (const authorization of [undefined, 'Bearer nope', token({}, { alg: 'none' }), token({}, { alg: 'HS256' }),
    token({}, { alg: 'RS256' }, other.privateKey), token({ exp: now / 1000 }), token({ iat: now / 1000 + 100 }),
    token({ exp: now / 1000 + 7200 }), token({ iss: 'attacker' }), token({ aud: 'other' }), token({ scope: '' }), token({ sub: '' }), token({ nbf: now / 1000 + 1 })]) {
    assert.throws(() => authenticate(authorization));
  }
});
test('rejects absent consent, extra fields, unsupported operations and oversized prompts', () => {
  for (const body of [null, [], {}, { ...request.body, consent: false }, { ...request.body, model: 'expensive' },
    { ...request.body, description: ' ' }, { ...request.body, description: 'x'.repeat(2001) },
    { operation: 'workout', focusArea: 'Ignore instructions', consent: true }]) assert.throws(() => validateInput(body));
});
test('never calls the provider before authentication and consent validation', async () => {
  let calls = 0;
  const gateway = createGateway({ apiKey: 'server-only-test-secret', model: 'claude-haiku-5-5', authenticate,
    fetchImpl: async () => { calls++; return provider('500'); } });
  await assert.rejects(gateway({ ...request, authorization: undefined }));
  await assert.rejects(gateway({ ...request, body: { ...request.body, consent: false } }));
  assert.equal(calls, 0);
});
test('key is sent only to fixed provider; caller cannot pick model, output budget, URL or system instruction', async () => {
  const gateway = createGateway({ apiKey: 'server-only-test-secret', model: 'claude-haiku-5-5', authenticate,
    fetchImpl: async (url, options) => {
      assert.equal(url, 'https://api.anthropic.com/v1/messages');
      assert.equal(options.headers['x-api-key'], 'server-only-test-secret');
      assert.equal(options.redirect, 'error');
      const body = JSON.parse(options.body);
      assert.equal(body.model, 'claude-haiku-5-5'); assert.equal(body.max_tokens, 32);
      assert.equal(body.messages.length, 1); assert.equal(body.messages[0].role, 'user');
      return provider('500');
    } });
  assert.deepEqual(await gateway(request), { calories: 500 });
});
test('rejects negative, out-of-range, ambiguous and truncated calorie estimates', async () => {
  for (const text of ['-1', '-500', '0', '10001', '500 kcal', '400 or 600']) {
    const gateway = createGateway({ apiKey: 'test', model: 'test', authenticate, fetchImpl: async () => provider(text) });
    await assert.rejects(gateway(request), error => error.code === 'estimate_unavailable');
  }
  const gateway = createGateway({ apiKey: 'test', model: 'test', authenticate,
    fetchImpl: async () => new Response(JSON.stringify({ stop_reason: 'max_tokens', content: [{ type: 'text', text: '50' }] })) });
  await assert.rejects(gateway(request), error => error.code === 'invalid_response');
});
test('enforces quota windows and bounds identity storage', () => {
  let time = 0; const limiter = new Limiter({ now: () => time, perUser: 1, maxEntries: 3 });
  limiter.user('one'); assert.throws(() => limiter.user('one'));
  limiter.ip('two'); assert.throws(() => limiter.ip('three'));
  time = 60001; assert.doesNotThrow(() => limiter.user('one'));
});
test('provider errors and oversized responses are sanitized', async () => {
  for (const response of [new Response('provider-secret', { status: 500 }), new Response('x'.repeat(65537))]) {
    const gateway = createGateway({ apiKey: 'test', model: 'test', authenticate, fetchImpl: async () => response });
    await assert.rejects(gateway(request), error => error.code === 'provider_unavailable' && !error.message.includes('secret'));
  }
});
test('concurrent calls are bounded and slots released after completion', async () => {
  let release; const gate = new Promise(resolve => { release = resolve; });
  const gateway = createGateway({ apiKey: 'test', model: 'test', authenticate, concurrency: 1,
    fetchImpl: async () => { await gate; return provider('500'); } });
  const first = gateway(request);
  await assert.rejects(gateway(request), error => error.code === 'rate_limited');
  release(); await first;
  assert.deepEqual(await gateway(request), { calories: 500 });
});
