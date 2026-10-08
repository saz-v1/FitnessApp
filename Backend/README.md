# FitSwift AI gateway

This is a separate gateway scaffold for a possible future AI update. The current iOS app runs locally and contains no AI client. In a future integration, the provider key stays in the server environment and iOS receives only a short-lived, scoped device/user session token. Requests supply a meal description or a fixed workout focus, not an arbitrary provider prompt or model.

## Status

The gateway implementation and automated tests are included. It is **not deployed** or bundled into the iOS app. There is no existing login or device-attestation service in this project. Enabling cloud calls requires hosting, a trusted session issuer and a new iOS client integration. There is deliberately no unauthenticated route, shared app password, hardcoded bearer token, or token-minting endpoint.

For an account-free app, implement Apple App Attest enrollment/assertion verification on the server, including certificate validation, fresh challenges, app identity checks and replay-counter storage, then issue an RS256 token to that verified device. This attestation verifier/token issuer is not implemented here. Alternatively, use an identity provider with a real native sign-in flow. The gateway accepts signed tokens from the configured issuer; it does not perform enrollment itself. [Apple's validation guide](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server).

## Run and verify

Requires Node.js 22 or newer, with no third-party packages:

```sh
node --test Backend/gateway.test.mjs
node --env-file=Backend/.env Backend/server.mjs
```

Run these commands from the repository root. Copy `.env.example` to a local `.env` and supply the provider key through your host's secret manager for production. The example does not contain usable secrets.

Required configuration:

| Variable | Value |
| --- | --- |
| `ANTHROPIC_API_KEY` | Server-only provider credential |
| `ANTHROPIC_MODEL` | Server-controlled model ID; example uses `claude-haiku-5-5` |
| `AUTH_PUBLIC_KEY_FILE` | Pinned RSA public key from your session issuer, at least 2048 bits |
| `AUTH_ISSUER` | Exact trusted token issuer |
| `AUTH_AUDIENCE` | Exact API audience |
| `PORT` | Loopback port, default 3000 |

Claude 3 Haiku was retired on 20 April 2026. Model selection is now a server setting, so it can be changed without distributing a secret or rebuilding the app. Verify model access in your provider account before deployment. [Model retirements](https://platform.claude.com/docs/en/about-claude/model-deprecations), [Haiku 5.5 migration](https://platform.claude.com/docs/en/models/haiku-5-5/migration-guide).

## Client integration

Client integration is future work. The former `ClaudeService`, endpoint configuration, session/Keychain code and cloud controls have been deleted from the iOS target. There is no current `configureSession` or `makeRequest` client API to call.

Implement a new client only after hosting an HTTPS `/v1/fitness-ai` endpoint and a trusted authentication or App Attest service. Use a non-secret endpoint setting, obtain short-lived scoped sessions after verified enrollment/sign-in, and store any device session securely. Keep provider credentials server-only. Each cloud action must obtain sharing consent and send only the operation-specific fields accepted by the gateway. Updating the app's local-only guards and privacy disclosures is part of that future release.

The current hosted identity public key is pinned and changed through deployment, not downloaded from caller-controlled JWT headers. Tokens must be RS256, carry the exact issuer/audience, a subject, `iat` and `exp` no more than one hour apart, and `scope: fitness:ai`. Prefer five-minute device sessions. Rotate server signing keys with deployment and replace/revoke previously exposed provider keys at Anthropic. A published client secret cannot be made safe through obfuscation or Keychain storage.

## Deployment constraints

- Put the loopback listener behind HTTPS. Apply connection, body-size, unauthenticated IP and daily spending limits at the edge. Block direct access to the loopback process. The server does not trust forwarded IP headers.
- Run a single process: quotas and concurrency are currently in memory. For multiple instances, restarts that preserve quotas, revocation and per-device daily limits, use an atomic shared datastore. The process-wide quota is conservative; behind a proxy all requests may share an IP quota until trusted edge limits are integrated.
- The gateway limits per-user, per-IP and global requests per minute and concurrent provider calls. It fixes the provider endpoint, caps output tokens, forbids redirects, bounds request/response bodies and uses timeouts. Failed/uncertain calorie estimates are not accepted as valid values.
- Never log Authorization headers, request bodies, provider responses, secret environment variables, or health descriptions at the gateway or reverse proxy. This implementation returns generic errors and uses `no-store` responses.
- Publish the actual operator privacy policy, Anthropic data handling terms and contact information before enabling cloud features. Reassess App Privacy declarations when transmitting user information; the current manifest describes the local, unconfigured build.
- Review the attestation/authentication adapter, deployed TLS/configuration and rate limits before launch. Passing local tests is not proof of deployment security.

The provider payload uses a top-level `system` and one user message, as specified by the [Messages API](https://platform.claude.com/docs/en/api/messages/create). JWT signature checks use Node's [crypto verification API](https://nodejs.org/api/crypto.html).
