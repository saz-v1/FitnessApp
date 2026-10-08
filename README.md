# FitSwift

Local-only SwiftUI fitness journal for iOS 18.6 and later. It tracks meals, weights and workouts, displays summaries and achievements on the device, and optionally imports Apple Health data. No account, API key, backend or internet connection is required.

Open `FitnessApp.xcodeproj` in Xcode. Select your registered app identifier and signing team for device builds. Run the unit and UI test targets before archiving.

## Security and data

Primary records and achievement unlocks use atomic local files with complete iOS file protection and backup exclusion. Legacy UserDefaults records migrate after successful writes. Failed changes are not published, and unreadable saved files are preserved. Reminder preferences stay in app-local UserDefaults, declared in the privacy manifest. Weight-history values are kilograms; unit toggles preserve measurement precision. Older mixed-unit records require review because their original unit was not recorded.

Apple Health access is optional and starts after an explicit connection action. Local tracking works without it. Profile edits use an explicit Save button. Personal information is covered when the app is inactive to reduce app-switcher exposure. This is a fitness journal, not clinically validated medical software.

## Local-only release and future AI

The shipping iOS target contains no AI client, provider integration, remote gateway, authentication credentials or networking implementation. Manual logging, calculations, graphs, reminders and workout summaries run locally. The in-app privacy policy describes this behavior. Both historical exposed keys have already been revoked; no live key is configured.

The separate [Backend](Backend/README.md) folder preserves a possible future gateway and its tests. It is outside the iOS target and is not bundled into the app. It is not deployed, and its trusted authentication or device-attestation enrollment service still needs implementation. Adding AI later requires hosting, authenticated access, server-only provider secrets, consent, updated privacy disclosures and an app update. The provider model can be configured on that future server.

Never put a provider key in Xcode, a plist, source code or the client Keychain. A future provider key belongs in the hosted server's secret manager. A local-only architecture can be submitted to the App Store, but release still requires valid distribution signing, accurate App Store privacy information, a public privacy-policy URL and physical-device verification. See the release review for outstanding checks; this repository does not imply App Store approval.

## Checks

```sh
python3 Tools/check_secrets.py
python3 Tools/check_local_only.py
node --test Backend/gateway.test.mjs
xcodebuild -scheme FitnessApp -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Run Xcode tests on an available iPhone simulator; verify HealthKit and device-lock behavior on a physical device. See [release review](RELEASE_REVIEW.md) for the current verification results and remaining launch requirements.

After building, run `python3 Tools/check_local_only.py --app-bundle /path/to/FitnessApp.app` to check the compiled app for old service implementations and accidentally bundled backend files. The source and bundle checks are regression guards, not proof against every possible security issue.

## Interface and graphs

The app now uses a shared visual style across its dashboard, forms, history, Health and achievements screens. Meal, weight and workout logging are directly accessible. Calorie, weight and workout graphs support 7/30/90-day ranges, touch selection and readable summaries. See [UI review](UI_REVIEW.md) for the changes and verification results.
