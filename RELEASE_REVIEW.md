# Security and release review — 8 October 2026

## Current status

All project files listed below were reviewed. The current unsigned local-only iOS Release build succeeds and its executable/bundle pass the local-only guard. The final integrated simulator run passed 32 tests (26 unit and six UI), with no failures or skips. The separate future backend gateway passes nine tests. Signing, physical-device checks and submission metadata are still required before release; hosting is not required for this local-only version.

The owner confirmed both historical Anthropic keys have been revoked and no live keys are configured. Current app source and the built app contain no provider-key signatures. Git history still contains the revoked values; no history rewrite was performed.

The shipping app is fully local-only: the inactive AI client, Keychain credentials, cloud controls and provider/network request code have been deleted. The separate Backend folder is not part of the app target or bundle. It preserves an undeployed starting point for a future update, which will need hosted authentication or device attestation and a new client integration.

## Changes

- **Local-only boundary:** removed all AI and networking implementation from the shipping target, including inactive gateway and Keychain code. Manual logging, graphs, calculations, achievements and reminders work without an account or internet connection. A source and compiled-bundle guard detects reintroduced remote clients or accidentally packaged backend files.
- **Future gateway, outside the app:** pinned-key RS256 verification with issuer, audience, expiry and scope validation; allowlisted operations and fields; bounded payloads and responses; user, IP and global quotas; concurrency and timeout limits; sanitized errors. The server refuses to start without authentication and provider configuration. Future deployment needs HTTPS, a trusted session issuer, current provider/model validation and operational spending limits.
- **Saving:** primary records and achievement unlocks use protected atomic files excluded from backup. Changes publish only after a successful save. Profile drafts preserve history imported while editing. Legacy defaults migrate only after successful persistence. Corrupt or locked saved files remain intact, block writes and can be reloaded after unlocking.
- **Health:** optional, explicit read-only connection; awaited queries and overlap guards; stable imported record IDs; merges preserve manual records and distinct same-day sessions. Sleep intervals are combined across overlapping stages/devices. Manual tracking requires no Health permission.
- **Calculations:** age-aware adult calorie estimates, exact kilogram/pound conversions, precision-preserving unit toggles, correct goal chart conversion, calendar-based streaks and daily totals, unique-day progress, responsive calorie chart bounds, and clamped BMI indicators. Input and decoded-data validation prevent invalid numeric states and exercise-duration crashes.
- **App behavior:** explicit profile Save and useful error feedback, privacy cover while inactive, no automatic notification permission prompt, reminder changes protected against delayed authorization races, generic lock-screen messages, explicit workout deletion, refreshed achievement progress, completed meal-tracking achievements, and consecutive-day weight achievements.
- **Packaging:** bundled required-reason privacy manifest, read-only Health descriptions, removal of credential build settings, ignored local server secret files, and an opaque RGB App Store icon with the original artwork preserved exactly.
- **Performance and remaining bugs:** one-pass chart/day summaries, selection isolated from full-history processing, lazy weight/workout history and one workout grouping per render. Repeated Health imports avoid unnecessary file writes and preserve newer manual weights. Disconnect invalidates pending Health work; invalid Health readings cannot reach integer labels. Exercise decimal input follows the locale, achievement goal tolerance uses kilograms in either unit system, and future entries cannot unlock first-entry achievements.
- **Dark mode and privacy:** softened mint/amber accents and charcoal surfaces while preserving every light-mode colour. A bundled privacy-policy screen is available from Profile even offline.

## File-by-file review inventory

All tracked project files and new files are accounted for here. Local Xcode user-state files and generated build products are not application source. “Reviewed” does not mean that every possible defect can be excluded.

| Files | Review result |
| --- | --- |
| README.md | Local-only setup, storage, optional permissions and separate future backend. |
| LICENSE | Read; ownership/license text preserved. |
| .gitignore | Added local secret, private key and generated-build exclusions. |
| FitnessApp.xcodeproj/project.pbxproj | Removed credential settings and conflicting Health descriptions; verified source/resource membership and build. Owner signing configuration remains required. |
| FitnessApp.xcodeproj/project.xcworkspace/contents.xcworkspacedata | Reviewed workspace structure; no change needed. |
| FitnessApp/FitnessApp.entitlements | Retained basic HealthKit; removed unused Health Records and background-delivery entitlements after the owner encountered a provisioning error. |
| FitnessApp/Info.plist | Removed provider-key configuration and unused write description; reviewed read descriptions and packaging. |
| FitnessApp/PrivacyInfo.xcprivacy | Added defaults required-reason declaration for the current local build; cloud deployment requires disclosure review. |
| FitnessApp/FitnessAppApp.swift | Reviewed startup and injected shared state; isolated Debug UI-test storage. |
| FitnessApp/ContentView.swift | Explicit integration opt-in, active-state recovery and reminder reconciliation, privacy cover. |
| FitnessApp/Models/User.swift | Validated saved measurements/history, stable weight IDs and compatible protected achievement state. |
| FitnessApp/Models/UserManager.swift | Transactional saving/migration, protected storage, profile merge, consistent units, bounded adult estimates and retry after unlock. |
| FitnessApp/Models/WorkoutRecord.swift | Reviewed Codable model and stable workout/exercise identity; validation centralized in User. |
| FitnessApp/Models/FitnessMetrics.swift | Added shared calendar-day totals and unique-day streak calculations. |
| FitnessApp/Models/Achievement.swift | Protected unlock migration, live progress, merged unlocks and corrected consecutive-day/meal/week logic. |
| FitnessApp/Models/HealthKitManager.swift | Awaited queries, guarded refresh, read-only imports, correct units and sleep overlap handling. |
| FitnessApp/Services/ClaudeService.swift | Deleted for the local-only release. |
| FitnessApp/Services/HealthKitService.swift | Read-only, serialized, stable-ID weight merge and propagated persistence failures. |
| FitnessApp/Services/NotificationManager.swift | Explicit authorization, scheduling race handling, denied-permission feedback and privacy-conscious reminder text. |
| FitnessApp/Services/WorkoutAnalyticsService.swift | Deleted; local summaries live in FitnessMetrics. |
| FitnessApp/Views/DashboardView.swift | Unique-day statistics, calendar ranges, calorie progress and stable UI-test identifiers. |
| FitnessApp/Views/ProfileView.swift | Draft editing with explicit validated Save, import-preserving commit, optional Health and accurate privacy explanation. |
| FitnessApp/Views/AddWeightSheet.swift | Numeric/date bounds, canonical kilograms and visible failed-save handling. |
| FitnessApp/Views/WeightDetailView.swift | Correct goal conversion, safe date ranges and explicit record deletion. |
| FitnessApp/Views/BMIDetailView.swift | Invalid/adolescent category handling and bounded chart marker. |
| FitnessApp/Views/CalorieDetailView.swift | Valid manual meal saves, explicit deletion and failed-save feedback; AI controls removed. |
| FitnessApp/Views/CalorieChartView.swift | Whole-calendar-day totals, missing-day zeros and adaptive chart range. |
| FitnessApp/Views/AddWorkoutSheet.swift | Validated duration, exercises, numeric bounds and dates; transactional save feedback. |
| FitnessApp/Views/WorkoutLogView.swift | Explicit deletion, empty states, one grouped snapshot and lazy history; no cloud controls. |
| FitnessApp/Views/WorkoutInsightsView.swift | Redesigned local patterns, summary cards and an interactive session chart with time ranges. |
| FitnessApp/Views/TargetedWorkoutView.swift | Deleted for the local-only release. |
| FitnessApp/Views/HealthDataView.swift | Optional connection action, read-access wording and sleep time-window label. |
| FitnessApp/Views/AchievementsView.swift | Refreshes on saved changes and corrected next-level points. |
| FitnessApp/Views/NotificationSettingsView.swift | Explicit toggles, async scheduling and visible authorization errors. |
| FitnessApp/Assets.xcassets/Contents.json, AccentColor.colorset/Contents.json, AppIcon.appiconset/Contents.json | Reviewed and validated asset metadata. |
| FitnessApp/Assets.xcassets/AppIcon.appiconset/AppIcon~ios-marketing 2.png | Inspected 1024-pixel icon; removed the unused alpha channel without changing any RGB pixel. |
| FitnessApp/Preview Content/Preview Assets.xcassets/Contents.json | Reviewed and validated preview metadata. |
| FitnessAppTests/FitnessAppTests.swift | Thirteen tests for calculations, protected persistence, migration, failed writes, units, history, achievements and offline manual logging. |
| FitnessAppTests/FitnessMetricsTests.swift, NumericInputTests.swift, ImportRegressionTests.swift, AchievementRegressionTests.swift, HealthIntegrationTests.swift | Focused summary/DST, locale, no-op import, achievement and Health-disconnect regressions. |
| FitnessAppUITests/FitnessAppUITests.swift | Six functional flows, including graph ranges, profile unit labels and confirmed workout deletion, with isolated state and stable identifiers. |
| FitnessAppUITests/FitnessAppUITestsLaunchTests.swift | Isolated launch setup; screenshot test verified across four launch configurations. |
| Backend/gateway.mjs | Authenticated fixed-operation gateway, validation, quotas, bounded provider call and error handling. |
| Backend/server.mjs | Loopback server with required configuration, strict route/method/content type, size limits, timeouts and sanitized responses. |
| Backend/gateway.test.mjs | Nine tests covering credential boundary, forged/expired/wrong-key tokens, consent, payloads, quota state, concurrency and upstream failures. |
| Backend/package.json, Backend/.env.example | No runtime dependencies or secrets; declared supported runtime and server-only configuration. |
| Backend/README.md | Deployment instructions and explicit missing session issuer/hosting/operational controls. |
| Tools/check_secrets.py | Current credential-boundary check that reports locations without printing secrets. |
| Tools/check_local_only.py | Source and production-bundle checks for remote-service code and backend packaging. |
| Tools/RegressionChecks.swift | Native harness exercising actual production models, storage, transactions and calculations. |
| Tools/verify.sh | Reproducible local checks; shell syntax validated. Individual equivalent checks were executed for this review. |
| FitnessApp/Views/AppTheme.swift, FitnessApp/Views/ChartComponents.swift | Shared adaptive colours, cards, buttons, graph periods, summary layouts and compact date labels. |
| FitnessApp/Views/PrivacyPolicyView.swift | Offline policy explaining local records, optional Health access, reminders, retention and deletion. |
| FitnessApp/Models/HealthIntegrationPreference.swift, LocalizedDecimal.swift | Invalidates stale Health reads/imports and parses complete decimal input for the current locale. |
| FitnessApp/Models/UITestFixtures.swift | Synthetic records available only in isolated Debug UI-test stores; absent from Release builds. |
| UI_REVIEW.md | Recorded interface/graph changes, visual checks and regression results. |
| SECURITY.md, RELEASE_REVIEW.md | Revocation status, architecture boundaries, review evidence and outstanding release requirements. |

## Earlier verification results

- **Unsigned iOS Release:** build succeeded after the final source changes using installed Xcode and a generic iOS destination. This does not prove signing or App Store archive validation.
- **Final iOS simulator tests:** 17 passed, zero failures or skips, on iPhone 17 Pro / iOS 26.3.1. Includes 14 unit tests and three functional UI tests: optional Health on launch, rejecting zero-calorie meals/canceling entry, and explicit profile Save. Result bundle: /tmp/FitnessAppFinalTests.xcresult.
- **Launch screenshots:** separate launch test passed in all four tested configurations. Result bundle: /tmp/FitnessAppReviewTests.xcresult. That earlier run also exposed two regressions; the exact pound conversion and stable UI identifiers were corrected and verified by the final successful run.
- **Backend:** nine gateway tests passed without a real provider key or live provider request.
- **Native model harness:** production model sources compiled and passed transaction, reload, migration, corrupt-file preservation, repeated unit conversion, chart, streak and achievement checks. This does not exercise iOS file-protection enforcement.
- **Release inspection:** privacy manifest bundled; provider-key signatures absent from the binary; obsolete credential plist setting absent. App icon preserves its original RGB pixels.
- **Static checks:** current credential scan, property-list/asset JSON syntax, verification-script shell syntax and git diff whitespace checks passed.

## Remaining release requirements

1. **Owner signing and archive:** verify the current com.syed.FitnessApp identifier is registered to the owner, select the owner's team/provisioning, archive and validate in App Store Connect. The Health Records capability error is removed; the attempted signed command-line build still encountered codesign errSecInternalComponent, so device signing remains unverified. Review the generated privacy report.
2. **Physical-device checks:** test Health denied/partial/revoked access, overlapping sleep sources, protected saving while locked and recovery after unlocking, app restart, reminder permission denial, notification delivery and unit changes. Simulator results cannot establish these behaviors on a real device.
3. **Privacy and store information:** publish a stable privacy-policy URL with operator identity/contact, configure support information and accurate App Privacy answers, and complete screenshots, age rating and review notes. See [Apple HealthKit privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy) and [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
4. **Legacy data:** original versions mixed kilograms and pounds without recording historical units, and some Health imports had random IDs. Historical units cannot safely be inferred, and older imported samples may be imported once more. Records were preserved rather than guessed or deleted. Migration cannot erase copies already present in old device backups.

For a future AI update, implement and host the trusted session issuer, client enrollment/refresh and HTTPS gateway. Provider credentials must stay server-only. Validate replay controls, quotas, spending caps, provider terms and updated privacy disclosures. Account-free [App Attest](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server) is an option; its verifier is not implemented. This future work is not a dependency of the current local release.

This review does not certify the absence of every defect, production infrastructure security or App Store approval. Fitness estimates remain general guidance rather than clinically validated advice.

## Subsequent UI and graph verification

The redesigned app passed 20 tests (14 unit and six UI) on an isolated iPhone 16e / iOS 26.3.1 simulator. Result bundle: /tmp/FitnessAppGraphsVerifiedTests.xcresult. The unsigned Release build also passed after the final graph label/layout changes. See [UI review](UI_REVIEW.md) for the added time ranges, selection, large-text layouts and remaining signing limitation.

## Final local-only and performance verification

- 32 simulator tests passed (26 unit, six UI), no failures or skips, on isolated iPhone 16e / iOS 26.3.1. Result: /tmp/FitnessAppLocalOnlyTests.xcresult.
- Debug simulator and unsigned iPhone Release builds passed again after the final date-label sizing change. The label sizing change was compile-checked; the 32-test run preceded that final presentation adjustment.
- Current source and the final Release executable/bundle passed credential and local-only checks. No AI client, request implementation, credential configuration or backend script is included.
- The native harness built from production models passed storage, transaction, migration, unit, chart, streak and achievement checks. All nine future-gateway tests also passed without live credentials or requests.
- A native optimized synthetic benchmark with 10,000 workout sessions over 90 days produced the same daily counts: former repeated grouping took 2.753 seconds, the new complete summary took 0.0307 seconds. This measures aggregation on this Mac, not iPhone frame rate or launch time.
- Revised dark dashboard and calorie graph were visually inspected using synthetic data in the isolated test store. Light palette values are unchanged. The ordinary local-only app was installed on the user's simulator without adding fixtures to its journal.

On-device data is not considered collected for App Store privacy answers when it never leaves the device; see [Apple's App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/). The current policy is bundled in the app. A stable hosted policy URL with publisher identity/contact is still required for the store listing.
