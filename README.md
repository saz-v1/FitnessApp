# FitSwift

Local-only SwiftUI fitness journal for iOS 18.6 and later. It tracks meals, weights and workouts, displays summaries and achievements on the device, and optionally imports Apple Health data. No account, API key, backend or internet connection is required.

Open `FitnessApp.xcodeproj` in Xcode. Select your registered app identifier and signing team for device builds. Run the unit and UI test targets before archiving.

## Project structure

**FitSwift** is the app's display name. The Xcode project, app target and scheme are named **FitnessApp**. The repository separates the shipping iOS app, its tests, reference-data tools and a possible future server:

```text
FitnessApp/
├── FitnessApp.xcodeproj/       Xcode targets, build settings and workspace
├── FitnessApp/                Shipping iOS app
│   ├── FitnessAppApp.swift    SwiftUI entry point
│   ├── ContentView.swift      Tabs, shared state and app lifecycle
│   ├── Models/                Records, validation, calculations and managers
│   ├── Services/              Health imports, notifications and workout storage
│   ├── Views/                 Screens, logging forms and reusable UI
│   ├── Resources/             Bundled food and exercise JSON
│   ├── Assets.xcassets/       App icon and accent-colour assets
│   ├── Preview Content/       Assets for Xcode previews
│   ├── Info.plist             App property-list source
│   ├── FitnessApp.entitlements
│   └── PrivacyInfo.xcprivacy  Privacy manifest
├── FitnessAppTests/           Model, persistence and service unit tests
├── FitnessAppUITests/         App flows and launch screenshot tests
├── Tools/                     Checks and catalogue-generation scripts
├── Backend/                   Separate, undeployed future AI gateway
├── README.md                  Project guide
├── CATALOG_SOURCES.md         Data provenance, licences and regeneration
├── SECURITY.md                Credential history and security boundaries
├── RELEASE_REVIEW.md          Verification evidence and release requirements
├── UI_REVIEW.md               Interface changes and visual review
├── LICENSE                    Project licence
└── .gitignore                 Local settings, builds and secret-file exclusions
```

The app uses SwiftUI, Swift Charts, Foundation, Combine, HealthKit, UserNotifications and small UIKit helpers. The project uses Swift 5 language mode and has no third-party package dependencies in the iOS targets. Node.js and Python are development tools for the separate server and data/check scripts; they are not needed to run the app.

## App architecture

`FitnessAppApp.swift` creates the app's window and opens `ContentView`. In Debug UI-test launches, it also resets test preferences unless preservation is requested. `ContentView.swift` owns the Dashboard, Workouts and Profile tabs, injects `UserManager` and `WorkoutSessionStore` into child views, applies the selected appearance, routes reminder actions to logging forms and covers the interface while the app is inactive.

SwiftUI views observe published state from the managers. A form prepares and validates a change, then asks its manager to save it. `UserManager` writes a candidate journal before publishing the new `User`; `WorkoutSessionStore` follows the same pattern for its smaller active-workout draft. Failed writes leave the previous published state in place and expose an error. Returning to the foreground retries unreadable storage, reconciles notifications and refreshes Apple Health when connected.

The directories describe responsibilities: some observable managers are in `Models/`, and several related views share a source file. Personal records are Codable JSON; reference catalogues are read-only JSON bundled with the app.

### Models and shared logic

| File in `FitnessApp/Models/` | Responsibility |
| --- | --- |
| `User.swift` | Profile, goals, unit preference, journal arrays and achievement IDs. Also defines `WeightRecord` and `CalorieRecord` and validates profile/history data. |
| `UserManager.swift` | Shared observable journal, protected persistence, legacy migration, profile commits, unit conversion, saved meals, stable Health imports and duplicate-safe workout saving. Provides BMI, adult calorie and goal estimates. |
| `ProfileEditor.swift` | Editable profile draft with localized input validation, change detection and exact preservation of untouched measurements. |
| `WorkoutRecord.swift` | Saved workout type, intensity, duration, optional exercises, notes and calories burned. Exercise records can retain detailed completed sets. |
| `SavedMeal.swift` | Reusable `SavedMeal` templates and `MealFood` portions. Stores source IDs and nutrient snapshots so catalogue updates do not rewrite earlier meals. |
| `WorkoutSession.swift` | Active session, tracked exercises, completed sets and timestamp clocks. Defines rep, timed and lap data, pause/resume behavior, validation and conversion into a saved workout. |
| `ActivityCatalog.swift` | Food/exercise reference types and their shared loader. Validates and combines resources off the main thread, caches food lookup/search keys and supports bounded searches and source/category filters. |
| `FitnessMetrics.swift` | Calendar-day calorie totals, workout summaries and unique-day streaks shared by charts, dashboard cards and achievements. Excludes future entries from summaries. |
| `Achievement.swift` | Achievement definitions and `AchievementManager`, including progress, unlocks, points and levels. Unlock IDs are persisted through `UserManager`. |
| `HealthKitManager.swift` | Optional read-only Health authorization, independent activity reads, availability/refresh state, latest measurements, overlapping sleep intervals and stable workout-history imports. Empty or failing categories do not discard successful readings. |
| `HealthIntegrationPreference.swift` | Connection preference and revision checks that prevent a pending Health read from applying after disconnection or reconnection. |
| `ReminderSettings.swift` | Meal/workout/weight reminder kinds, validated times and weekdays, notification identifiers and legacy preference migration. |
| `LocalizedDecimal.swift` | Complete, locale-aware decimal parsing for measurements and amounts; rejects malformed, ambiguous and nonfinite input. |
| `UITestFixtures.swift` | Synthetic chart records for isolated Debug UI-test launches. Excluded from Release builds. |

### Services

| File in `FitnessApp/Services/` | Responsibility |
| --- | --- |
| `HealthKitService.swift` | Explicit import of the last year of Health weight history. Preserves Health sample IDs, normalizes kilograms and merges through `UserManager` with visible failure feedback. |
| `HealthKitReader.swift` | Injectable read-only Health query adapter. Uses calendar-day statistics for cumulative values and date-bounded sample queries, with common no-data error classification. |
| `NotificationManager.swift` | System notification adapter, permission state, custom reminder scheduling, next-delivery information, sound, snooze and logging routes. Serializes changes and guards against stale scheduling completions. |
| `WorkoutSessionStore.swift` | Protected active-session storage and user actions: select movements, record reps/laps, complete sets, pause, rest, finish or discard. Recovers drafts, avoids duplicate journal saves and manages optional local rest alerts. |

`HealthKitManager` supplies activity and workout readings; `HealthKitService` handles the separate weight-history import. Both consult `HealthIntegrationPreference`. Disabling the connection stops new reads and invalidates pending work; previously imported journal entries remain saved.

### Views and navigation

| File in `FitnessApp/Views/` | Responsibility |
| --- | --- |
| `DashboardView.swift` | Daily calorie progress, quick meal/weight actions, Health activity, weight/BMI/goal summaries, weekly activity and achievement navigation. |
| `CalorieDetailView.swift` | Calorie summary, graph and today's meal history. Meal rows show saved portions, support saving a meal template and offer confirmed deletion. |
| `CalorieChartView.swift` | Selectable daily calorie chart, adaptive scale and target/readout presentation. |
| `SavedMealsView.swift` | Saved-meal library, `SaveMealPresetSheet` and `AddCalorieSheet`. Handles manual calories, food portions, template reuse and optional template creation while logging. |
| `WeightDetailView.swift` | Weight history, goal line, change summary and selectable graph, including the one-year range. |
| `AddWeightSheet.swift` | Validated weight/date entry, canonical kilogram conversion and save feedback. |
| `BMIDetailView.swift` | BMI explanation and bounded visual scale, with age/measurement handling for unavailable adult categories. |
| `WorkoutLogView.swift` | Workout tab, grouped history, session/statistic cards, confirmed deletion and `WorkoutDetailView` with saved set/lap details. |
| `AddWorkoutSheet.swift` | Manual workout entry and `AddExerciseSheet`, with duration, type, intensity, reference/custom exercises and validation. |
| `ActiveWorkoutView.swift` | Live session setup, movement selection, rep/set/lap controls, interval and rest displays, pause/resume, recovery, finish/discard and screen-awake preference. |
| `WorkoutInsightsView.swift` | Local workout patterns, session summaries and selectable activity graph. |
| `ReferenceLibraryViews.swift` | `FoodLibraryView`, `FoodPortionView`, `ExerciseLibraryView` and `ExerciseReferenceView`. Provides local search, filters, source information and selection into meals/workouts. |
| `ProfileView.swift` | Explicit profile Save, unsaved-change handling, measurement units, goals and navigation to settings/privacy. |
| `SettingsView.swift` | Appearance, reminders, optional Health controls, journal counts, saved meals, offline libraries, privacy and app version. Also defines `AppAppearance`. |
| `NotificationSettingsView.swift` | Reminder permission/status controls and editors for custom times, selected days, sound and disabling reminders. |
| `HealthDataView.swift` | Optional Health connection, refresh and activity readings with error and availability information. |
| `AchievementsView.swift` | Achievement progress, categories, points and levels refreshed from saved journal changes. |
| `PrivacyPolicyView.swift` | Bundled, offline explanation of local storage and optional system integrations. |
| `AppTheme.swift` | Shared light/dark colours, cards, buttons, icon badges, headers, empty states and screen/form modifiers. |
| `ChartComponents.swift` | Calendar-based graph periods, range picker, date labels, selected-value readouts and summary layouts. |

The three main tabs each provide their own navigation. Settings and the reference libraries are reached through Profile; libraries are also available from meal/workout entry and active sessions. Logging forms use sheets, while history and reference detail screens use navigation links. `AddCalorieSheet` lives in `SavedMealsView.swift`; there is no separate file with that name.

### Resources and app configuration

| Path | Purpose |
| --- | --- |
| `FitnessApp/Resources/foods.json` | 7,793 USDA SR Legacy entries with source IDs, per-100-g nutrition and available source portion weights. |
| `FitnessApp/Resources/foods-uk.json` | 2,832 usable CoFID 2021 entries with UK source codes and available nutrition. Preserves source definitions and explicitly handles drink-density conversions. |
| `FitnessApp/Resources/exercises.json` | 106 original movement references with IDs, names, muscles, equipment, instructions, aliases and default rep/time/lap tracking. |
| `FitnessApp/Assets.xcassets/` | App icon, accent-colour asset and asset-catalogue metadata. Runtime screen colours are centralized in `AppTheme.swift`. |
| `FitnessApp/Preview Content/` | Xcode preview asset catalogue. Contains no personal journal data. |
| `FitnessApp/Info.plist` | Property-list source combined with Xcode-generated settings. Display name, Health read description and scene/orientation settings are defined in the project build settings. |
| `FitnessApp/FitnessApp.entitlements` | Basic HealthKit capability. Health Records and background-delivery entitlements are absent. |
| `FitnessApp/PrivacyInfo.xcprivacy` | App-local UserDefaults required-reason declaration; no tracking or remotely collected data types are declared. |
| `FitnessApp.xcodeproj/project.pbxproj` | App/test targets, signing, deployment target, generated plist settings, resources and build configuration. Uses filesystem-synchronized groups for the app and test directories; `Info.plist` is excluded from normal resource membership. |
| `FitnessApp.xcodeproj/project.xcworkspace/` | Workspace metadata used by Xcode. Local `xcuserdata/` settings are ignored by Git. |

## Main data flows

**Meals:** enter calories manually or select a reference food and portion. The selected food becomes a `MealFood` snapshot; saving creates a `CalorieRecord` in the journal and can also create a `SavedMeal` template. Reusing a template creates a new journal entry. Food-portion calories are calculated from the saved per-100-g value and gram amount, with household portions converted using the source's gram weights.

**Workouts:** a manual form saves a `WorkoutRecord` directly. A live workout first creates a `WorkoutSession` draft; rep/lap/set actions update that protected draft. Finishing converts completed sets into a journal record with the session's stable ID. If a save is interrupted, retrying cannot create another record with that ID. Timestamp clocks reconstruct elapsed time after relaunch and exclude paused time.

**Weight and profile:** weight entry converts the chosen display unit to kilograms before appending a `WeightRecord`. Profile edits use a separate draft; committing copies profile fields into the latest journal so records imported while editing are preserved. Profile height, current weight and goal follow the selected display units; weight history and completed-set weights use kilograms.

**Health and reminders:** Health reads require the connection preference and system authorization, then either update visible readings or merge validated records. Each category completes independently, so missing Watch data cannot block iPhone steps or workout imports. A dash indicates an empty/unshared reading; an actual zero remains a valid reading. Refresh is available on the Health screen, in settings and by pulling down the dashboard. Reminder preferences produce local calendar notifications; their logging actions return to `ContentView`, which opens the corresponding entry sheet. Workout rest alerts use the active session's remaining rest deadline.

## Security and data

Primary records and achievement unlocks use atomic local files with complete iOS file protection and backup exclusion. Legacy UserDefaults records migrate after successful writes. Failed changes are not published, and unreadable saved files are preserved. Reminder preferences stay in app-local UserDefaults, declared in the privacy manifest. Weight-history values are kilograms; unit toggles preserve measurement precision. Older mixed-unit records require review because their original unit was not recorded.

Apple Health access is optional and starts after an explicit connection action. Local tracking works without it. Profile edits use an explicit Save button. Personal information is covered when the app is inactive to reduce app-switcher exposure. This is a fitness journal, not clinically validated medical software.

Running on an iPhone does not automatically grant Health read access. Enable the connection in FitSwift and choose the readings to share in Apple's permission sheet. If steps are missing, review FitSwift's app permissions inside Apple Health and enable Steps, then return to FitSwift and refresh. HealthKit deliberately does not reveal whether missing data means no samples or denied read access. Stand time displays cumulative time spent standing, separately from the Apple Watch Stand ring's completed hours.

Normal launches use the app's Application Support directory:

```text
PrivateFitnessData/
├── user.json              Profile, histories, saved meals and achievement IDs
└── active-workout.json    Recoverable workout draft, or a cleared null value
```

These files and their directory are excluded from backups. Appearance, connection, reminder and workout preferences use app-local UserDefaults. Bundled reference files contain public data and are separate from the journal. There is no cloud sync or built-in journal export/restore; deleting the app removes its local journal.

## Local-only release and future AI

The shipping iOS target contains no AI client, provider integration, remote gateway, authentication credentials or networking implementation. Manual logging, calculations, graphs, reminders and workout summaries run locally. The in-app privacy policy describes this behavior. Both historical exposed keys have already been revoked; no live key is configured.

The separate [Backend](Backend/README.md) folder preserves a possible future gateway and its tests. It is outside the iOS target and is not bundled into the app. It is not deployed, and its trusted authentication or device-attestation enrollment service still needs implementation. Adding AI later requires hosting, authenticated access, server-only provider secrets, consent, updated privacy disclosures and an app update. The provider model can be configured on that future server.

Never put a provider key in Xcode, a plist, source code or the client Keychain. A future provider key belongs in the hosted server's secret manager. A local-only architecture can be submitted to the App Store, but release still requires valid distribution signing, accurate App Store privacy information, a public privacy-policy URL and physical-device verification. See the release review for outstanding checks; this repository does not imply App Store approval.

| File in `Backend/` | Responsibility |
| --- | --- |
| `gateway.mjs` | Pinned-key RS256 session verification, issuer/audience/scope checks, fixed calorie/workout operations, validated payloads, request/concurrency limits and bounded provider responses. |
| `server.mjs` | Loopback HTTP entry point with required server configuration, strict route/method checks, request-size/time limits and sanitized responses. Production deployment requires HTTPS in front of it. |
| `gateway.test.mjs` | Gateway regressions using mocked provider requests; checks authentication, input, consent, quotas, concurrency and upstream failures without a live key. |
| `package.json` | Private Node.js package, Node 22+ requirement and start/test commands; no third-party runtime dependencies. |
| `.env.example` | Non-secret configuration template. Actual local `.env` and signing-key files are ignored by Git. |
| `README.md` | Future server configuration, authentication requirements and deployment limitations. |

No backend command is required for local app development. The former `ClaudeService` and its client session methods have been deleted; restoring cloud features requires a new iOS integration as well as a trusted server-side session issuer.

## Running locally

Use macOS with Xcode, an installed iOS simulator runtime and the `FitnessApp` scheme. The deployment target is iOS 18.6. Open the project, select an iPhone simulator and run with **Command-R**. No secrets or downloaded datasets are needed: the checked-in JSON resources are included in the build.

For a physical iPhone, choose your own development team and registered bundle identifier under Signing & Capabilities. The current app identifier is `com.syed.FitnessApp`; test targets have separate identifiers. Basic HealthKit remains available as an optional integration. Real Health permissions, protected saving while locked and notification delivery require device checks.

If command-line tools point to the standalone developer-tools installation, select the Xcode developer directory for that shell:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## Checks

```sh
python3 Tools/check_secrets.py
python3 Tools/check_local_only.py
node --test Backend/gateway.test.mjs
xcodebuild -scheme FitnessApp -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/FitSwiftRelease CODE_SIGNING_ALLOWED=NO build
python3 Tools/check_local_only.py --app-bundle /tmp/FitSwiftRelease/Build/Products/Release-iphoneos/FitnessApp.app
```

Run Xcode tests on an available iPhone simulator; verify HealthKit and device-lock behavior on a physical device. See [release review](RELEASE_REVIEW.md) for the current verification results and remaining launch requirements.

After building, run `python3 Tools/check_local_only.py --app-bundle /path/to/FitnessApp.app` to check the compiled app for old service implementations and accidentally bundled backend files. The source and bundle checks are regression guards, not proof against every possible security issue.

Run the Xcode tests with **Command-U**, or choose an available simulator for the command-line test destination:

```sh
xcrun simctl list devices available
xcodebuild -scheme FitnessApp -configuration Debug -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID' CODE_SIGNING_ALLOWED=NO test
```

Replace `YOUR_SIMULATOR_UDID` with an installed simulator's identifier. The unsigned Release command verifies compilation and packaging; it does not create a signed App Store archive. `bash Tools/verify.sh` runs the source guards, server tests, native Swift regression harness, unsigned Release build and compiled-bundle guard together. It requires Xcode, Python 3 and Node 22+; simulator tests are separate. `NODE_BIN` can select another installed Node executable for that script.

### Test targets

`FitnessAppTests/` uses Swift Testing (`@Test`) for models and service behavior. `FitnessAppUITests/` uses XCTest/XCUITest to interact with the app. Tests inject temporary storage, isolated preferences or notification doubles where appropriate.

| Unit-test file | Coverage |
| --- | --- |
| `FitnessAppTests.swift` | Calculations, valid/invalid profiles, protected persistence, migration, corrupt files, failed writes, unit precision, profile/history merging and offline record reload. |
| `FitnessMetricsTests.swift` | Calendar summaries, daylight-saving boundaries, future/invalid records and bounded empty ranges. |
| `NumericInputTests.swift` | Local decimal separators and rejection of malformed or ambiguous amounts. |
| `ImportRegressionTests.swift` | Idempotent Health imports, manual-weight preservation and avoiding redundant writes. |
| `HealthIntegrationTests.swift` | Explicit connection, invalidation after disconnect/reconnect and safe Health-value bounds. |
| `HealthRefreshTests.swift` | Valid iPhone steps with missing Watch categories, partial failures, empty versus zero readings, stale refresh rejection, calendar boundaries, stable measurement imports and overlapping sleep stages. Uses synthetic query results without personal Health data. |
| `AchievementRegressionTests.swift` | Future-entry exclusions and goal tolerance across display units. |
| `ProfileEditorTests.swift` | Exact untouched values, localized edits, incomplete input and optional goal removal. |
| `ReminderTests.swift` | Schedule migration, custom days/times, permission denial, delayed completion, sound, snooze, routing and scheduling errors. |
| `OfflineCatalogTests.swift` | Bundled counts/IDs, local filters, gram calculations, UK/US provenance, drink density, duplicate source codes, legacy decoding and saved-meal persistence. |
| `WorkoutSessionTests.swift` | Timestamp clocks, individual sets/weights, pause/rest, lap splits, draft reload, failed writes and duplicate-safe recovery. |
| `WorkoutRestAlertTests.swift` | Rest permission, pause/resume, sound changes and cancellation of delayed/stale alerts. |

`FitnessAppUITests.swift` covers launch without a Health prompt, manual meals, profile save/discard, unit labels, confirmed workout deletion, chart ranges, reminder preferences, saved-meal reuse, UK/US food selection, live sets/rest and timed laps. `FitnessAppUITestsLaunchTests.swift` captures launch screenshots across the runner's enabled configurations. Current results and physical-device gaps are recorded in [release review](RELEASE_REVIEW.md), rather than inferred from the presence of a test file.

Debug launch arguments support interface review:

| Argument | Behavior |
| --- | --- |
| `--ui-testing` | Uses an isolated temporary journal and workout draft; resets test preferences for a fresh run. |
| `--chart-fixtures` | Adds synthetic records only when combined with `--ui-testing`. |
| `--preserve-test-preferences` | Avoids clearing preferences and the isolated workout draft during a manual UI-test review launch. |

Regular launches never add fixtures. Release builds omit the fixture and test-storage branches. Simulator tests cannot establish real Health authorization, lock-state file protection, Focus behavior or notification delivery on a physical iPhone.

### Development tools

| File in `Tools/` | Purpose |
| --- | --- |
| `check_secrets.py` | Checks current sources/configuration for known provider-key signatures and forbidden client credential paths without echoing secret values. |
| `check_local_only.py` | Checks iOS sources/project settings and optionally a compiled app for remote-service code or accidentally bundled backend files. |
| `RegressionChecks.swift` | Native model regression harness for persistence, migration, calculations, units, history and achievements. Runs separately from simulator UI tests. |
| `verify.sh` | Runs the combined guards, gateway tests, native harness and unsigned Release/bundle checks. Cleans its temporary build directory afterward. |
| `build_food_catalog.py` | Generates the USDA snapshot from a locally downloaded official SR Legacy JSON ZIP using Python's standard library. |
| `build_cofid_catalog.py` | Generates the UK snapshot from the official CoFID workbook using `openpyxl`, with explicit missing-value, density and duplicate-code handling. |

Catalogue generation is a development step, not an app startup task. The UK importer requires `openpyxl` in the chosen Python environment. After obtaining the documented source versions, run from the repository root:

```sh
python3 Tools/build_food_catalog.py /path/to/FoodData_Central_sr_legacy_food_json_2018-04.zip
python3 Tools/build_cofid_catalog.py /path/to/McCance_Widdowsons_Composition_of_Foods_Integrated_Dataset_2021.xlsx
```

Each command writes its corresponding file in `FitnessApp/Resources/`; `--output` can select a different destination for review. Preserve the source/version attribution and stable IDs when updating a snapshot, rerun catalogue tests and review changed values before shipping. [Catalogue sources](CATALOG_SOURCES.md) records exact download versions, hashes, licences, exclusions and conversion rules.

## Interface and graphs

The app uses a shared visual style across its dashboard, forms, history, Health and achievements screens. Meal, weight and workout logging are directly accessible. Calorie, weight and workout graphs support 7/30/90-day ranges, touch selection and readable summaries; weight graphs also offer a one-year (365-day) range. See [UI review](UI_REVIEW.md) for the changes and verification results.

## Profile, settings and reminders

Profile edits show unsaved changes, support confirmed discard, preserve exact unedited measurements and validate complete numeric input before saving. App settings are a separate page with System/Light/Dark appearance, optional Apple Health controls, local journal counts and privacy information. Dashboard headings, calorie totals, overview cards and main screen headings are centred.

Each reminder has a custom time and day selection, including everyday, weekdays, weekends or selected days. Sound can be disabled; permission status and the next reminder time are shown. Notifications support **Log now** and a **15-minute snooze**. Tapping one opens the corresponding meal, workout or weight form. All notifications remain local and contain no fitness records.

Scheduling is serialized and guarded against stale completion after edits or disabling reminders. Saved choices survive permission denial and are restored when iOS allows notifications; launch never prompts for permission. Device time, Focus and iOS notification settings govern delivery. Verify real delivery and notification actions on a physical iPhone.

## Saved meals, reference libraries and active workouts

Meal logging supports manual calories or searchable food portions. The combined offline library contains 10,625 entries: 7,793 US USDA SR Legacy foods and 2,832 UK CoFID foods, with All/UK/US filters and visible sources. Energy and available protein/carbohydrate/fat values retain their source definitions; similar foods and raw/cooked preparations stay distinct. Save a meal for next time while logging, or save an existing meal from its history row. Saved meals can be reused with changed amounts and a fresh journal date; deleting a template keeps earlier entries. The original nutrient snapshot, source and stable food ID are stored with each portion, including compatibility with earlier USDA-only meals.

The exercise library includes 106 original movement references with muscles, equipment, search aliases and instructions. Both manual logging and active sessions can select a known movement; custom movements remain available. See [catalogue sources](CATALOG_SOURCES.md) for provenance, licences, data versions and regeneration.

**Workouts → Start a workout** opens a live session. Choose a session type, intensity and rest duration; select movements, tap rep/lap controls, set weights, complete sets or time intervals. Individual set counts/weights and exact lap splits are retained in the saved workout. Pause excludes elapsed time. Rest starts after set completion, can be skipped, and supports optional local alerts after explicit permission. Permission, Focus and the existing reminder sound preference govern alerts. An optional keep-awake setting applies only while the workout screen is open; closing it restores normal screen locking.

Timers use persisted timestamps rather than a background ticking task. A small protected active-session file is written only for user actions, separately from journal history, and restored after relaunch. Closing the session screen keeps the session running; finish saves the workout, while discard requires confirmation. Finished sessions remain retryable if writing fails, and stable session IDs prevent duplicate saves after recovery. These are tap-based controls, without camera/sensor counting or AI. Reference searches and all tracking remain offline.

The existing workout history **Edit** button is currently a deletion mode. Weight/meal/workout history does not yet have full record-editing forms.

## Further documentation

| Document | Contents |
| --- | --- |
| [CATALOG_SOURCES.md](CATALOG_SOURCES.md) | US/UK food and exercise provenance, licensing, snapshot generation and nutrition/storage conventions. |
| [SECURITY.md](SECURITY.md) | Historical revoked credentials, current local-only boundaries and requirements for any future cloud integration. |
| [RELEASE_REVIEW.md](RELEASE_REVIEW.md) | File review inventory, build/test evidence, signing status and outstanding App Store/device requirements. |
| [UI_REVIEW.md](UI_REVIEW.md) | Interface and graph changes, reminder/workout flows, appearance decisions and visual verification. |
| [Backend/README.md](Backend/README.md) | Separate future gateway setup, authentication and deployment constraints. |
| [LICENSE](LICENSE) | Project licence. Reference-data licences are documented separately in `CATALOG_SOURCES.md`. |
