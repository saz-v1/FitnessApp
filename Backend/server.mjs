import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { createGateway, verifier, GatewayError } from './gateway.mjs';

function required(name) {
  const value = process.env[name];
  if (!value?.trim()) throw new Error(`Missing server configuration: ${name}`);
  return value;
}
const gateway = createGateway({ apiKey: required('ANTHROPIC_API_KEY'), model: required('ANTHROPIC_MODEL'),
  authenticate: verifier({ publicKey: readFileSync(required('AUTH_PUBLIC_KEY_FILE'), 'utf8'),
    issuer: required('AUTH_ISSUER'), audience: required('AUTH_AUDIENCE') }) });
const port = Number(process.env.PORT ?? 3000);
if (!Number.isSafeInteger(port) || port < 1 || port > 65535) throw new Error('Invalid PORT');

const server = createServer({ maxHeaderSize: 16384 }, async (req, res) => {
  const send = (status, body) => {
    if (res.destroyed || res.writableEnded) return;
    res.writeHead(status, { 'content-type': 'application/json', 'cache-control': 'no-store',
      'x-content-type-options': 'nosniff', ...(status === 429 ? { 'retry-after': '60' } : {}) });
    res.end(JSON.stringify(body));
  };
  try {
    if (req.url !== '/v1/fitness-ai') throw new GatewayError(404, 'not_found');
    if (req.method !== 'POST') throw new GatewayError(405, 'method_not_allowed');
    if ((req.headers['content-type'] ?? '').split(';')[0].trim().toLowerCase() !== 'application/json') throw new GatewayError(415, 'unsupported_media_type');
    // Bound requests before buffering. The TLS edge must enforce its own IP rate
    // limits; forwarded headers are deliberately not trusted by this process.
    const contentLength = req.headers['content-length'];
    if (contentLength !== undefined && (!/^\d+$/.test(contentLength) || Number(contentLength) > 8192)) throw new GatewayError(413, 'request_too_large');
    let size = 0; const chunks = [];
    for await (const chunk of req) {
      size += chunk.length;
      if (size > 8192) throw new GatewayError(413, 'request_too_large');
      chunks.push(chunk);
    }
    let body;
    try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); }
    catch { throw new GatewayError(400, 'invalid_request'); }
    send(200, await gateway({ authorization: req.headers.authorization, ip: req.socket.remoteAddress ?? 'unknown', body }));
  } catch (error) {
    // Never return or log tokens, health descriptions, provider errors or keys.
    send(error instanceof GatewayError ? error.status : 500,
      { error: error instanceof GatewayError ? error.code : 'internal_error' });
    req.resume();
  }
});
server.requestTimeout = 10000;
server.headersTimeout = 10000;
server.timeout = 30000;
server.keepAliveTimeout = 5000;
server.maxConnections = 100;
server.on('clientError', (_, socket) => socket.destroy());
// Bind locally behind an HTTPS reverse proxy. No public plaintext listener.
server.listen(port, '127.0.0.1');
