# Credential exposure and security boundaries

The source review on 8 October 2026 found **two distinct Anthropic provider-key signatures** in `FitnessApp/Services/ClaudeService.swift` across **38 historical file revisions**. Key values are deliberately omitted from reports and test output. The current iOS sources and compiled release no longer include provider credentials.

## Credential status

The owner confirmed on 8 October 2026 that both exposed keys have already been revoked and that no live API keys are currently configured. Historical values remain in Git history but are no longer live credentials. History cleanup is optional housekeeping; a replacement key must be server-only.

## Incident-response reference

1. Revoke both exposed keys in the Anthropic console. Treat them as compromised whether or not the repository was public. Review API usage and billing for unexpected requests. A source fix, Keychain storage or obfuscation cannot revoke an already distributed credential.
2. Create a replacement only for the hosted gateway and supply it through the hosting secret manager. Never put it in the iOS app, repository, plist or build settings.
3. If the repository was shared, consider removing the exposed keys from history using a dedicated history-cleaning tool after coordinating with collaborators. History rewriting and force-pushing are intentionally not performed by this review because they replace commit identities and affect other checkouts. Copies, forks and previous app downloads can still retain the secret, so revocation comes first.
4. Do not paste credentials into chat, issue trackers or logs.

## Current implementation

- The shipping iOS app is local-only. The inactive AI client, gateway session/Keychain code and cloud screens have been removed entirely from the app target. It contains no provider keys, networking implementation, account service, ads or analytics. Manual records, calculations, summaries and reminders need no internet connection.
- Apple Health integration remains optional and accesses the local Health store through system permission controls. Opening the system Settings app for notification permission is the only remaining external-app navigation.
- The separate `Backend/` scaffold is outside the app target and is not shipped. It keeps any future provider credential in the server environment, validates pinned-key RS256 tokens and exact issuer/audience/scope, validates a small operation-specific payload, controls the provider model/output budget, limits requests/concurrency and sanitizes errors. No endpoint issues tokens to anonymous callers.
- A trusted authentication or App Attest enrollment/assertion service is not yet implemented or deployed. Restoring AI later requires a new client integration, hosted gateway and trusted session issuer, explicit sharing consent and revised privacy disclosures.
- Fitness records and achievement unlocks are saved with iOS complete file protection and backup exclusion. Read/write failures preserve the saved file and do not publish a failed change.
- `python3 Tools/check_secrets.py` checks current client/server source for known credential signatures and direct provider credential paths in iOS. It reports locations without echoing a secret. This is a regression check, not a complete secret detector.
- `python3 Tools/check_local_only.py` checks the shipping source and project configuration for remote services and backend files. Its optional `--app-bundle` argument also checks a built app's executable and packaged contents. `Tools/verify.sh` runs both checks before building and checks the release bundle afterward.

Before enabling cloud AI, review the hosted authentication/attestation adapter, TLS deployment, edge quotas, provider privacy terms and updated App Privacy declarations. Local tests cannot prove security of infrastructure that does not yet exist.
