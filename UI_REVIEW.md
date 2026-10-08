# UI and graph improvements — 8 October 2026

## Interface

- Shared teal, cream and dark palettes with consistent cards, icon badges, spacing and button sizes.
- Dashboard calorie overview, a progress ring, and direct meal/weight logging.
- Workout logging as a visible primary action, search across types/exercises/notes, clearer session cards and explicit deletion confirmation.
- Profile sections reorganized around measurements and goals, correct unit labels before saving, visible save confirmation and refreshed drafts after imports.
- Consistent navigation stacks, sheet controls, keyboard dismissal and failed-save feedback.
- Full-width achievement cards that allow descriptions to wrap; optional Health connection state instead of an unexplained grid of zeros.
- Reminder settings show their scheduled local times and use clear permission feedback.
- Larger-text layouts adapt, and light/dark contrast uses shared colours.
- Final dark palette uses charcoal surfaces and softer mint/amber accents; all light palette and hero colours are preserved.
- Profile links to an offline privacy policy; the inactive cloud controls and AI screens have been removed.

## Graphs

Calorie, weight and workout graphs include 7/30/90-day ranges and touch selection. Calorie graphs show calendar-day averages and days logged, weight graphs show first-to-last change, and workout graphs show session totals. Plot scales adapt to the selected data; target lines have labels; date labels use compact two-line formatting. Large-text summaries stack vertically while chart labels remain readable.

Missing calorie days explicitly have a zero total. Future entries are excluded. Weight records retain their original timestamps and are displayed in the chosen units. Lines connect measurements rather than inventing a smooth curve.

## Checks

The complete redesigned app passed 14 unit tests and six UI tests on an isolated iPhone 16e simulator, including graph range coverage, unsaved unit labels, profile confirmation, manual meals and cancellation/confirmation of workout deletion. The unsigned iPhone Release build succeeded. The full UI suite was rerun after the final label/layout refinements, together with a final release build.

Sample graph data is limited to Debug builds launched with both --ui-testing and --chart-fixtures and uses an isolated temporary store. Regular launches never add sample data. Visual checks covered light, dark and accessibility text sizes.

The unused Health Records and background-delivery entitlements were removed. The development profile can now be found for the current app identifier; the attempted command-line signed build still encountered a local codesign errSecInternalComponent error. Signing in Xcode and on a physical device remains an owner/device check.

## Final local-only and performance pass

The integrated app passed 32 tests (26 unit, six UI), with zero failures or skips. Result: /tmp/FitnessAppLocalOnlyTests.xcresult. Debug and unsigned Release builds then passed after the final date-label sizing correction, which prevents abbreviated month labels from truncating. The final production bundle passed the local-only guard.

Graphs now aggregate history once and keep touch selection within the chart view. Workout/weight histories use lazy rows, workout groups are built once per render, and redundant Health imports avoid unnecessary file writes. A native synthetic 10,000-session/90-day calculation improved from 2.753 seconds to 0.0307 seconds while preserving counts; this is calculation timing rather than an iPhone frame-rate measurement.

Additional regressions cover locale decimal input, DST/day boundaries, deterministic summaries, Health disconnect/reconnect invalidation, invalid Health readings, repeated imports preserving manual weights, and consistent achievement behavior across units/future dates. Real Health authorization, device locking and notification delivery still require physical-device testing.

## Profile, settings and reminders

- Centred navigation/screen headings, dashboard date and message, calorie total inside its progress ring, overview cards and weekly summaries.
- Separate Settings page for System/Light/Dark appearance, reminders, optional Apple Health access/imports, local journal counts and privacy information.
- Profile fields validate complete localized input; untouched values keep their original precision. Unsaved edits are visible and can be discarded with confirmation.
- Each reminder supports a custom time and everyday, weekday, weekend or selected-day schedules. Permission state, next notification and sound controls are visible.
- Notifications offer Log now and a 15-minute snooze; logging actions route to the corresponding entry form.
- Serialized scheduling prevents old completion from restoring a disabled reminder or replacing a new time. Launch repairs missing schedules without prompting or needlessly re-adding correct requests.

The integrated changes passed 46 tests (38 unit, eight UI), zero failures or skips. Result: /tmp/FitnessAppSettingsVerifiedTests.xcresult. Screenshots of the final dashboard, profile and reminders were inspected. The final small changes to the turn-off button and policy wording were checked by fresh Debug/Release builds. Physical-device notification delivery and action presentation still need an iPhone check.

## Offline references, saved meals and active workouts

- Search 7,793 bundled USDA reference foods, select gram/household portions and see available energy/protein/carbohydrate/fat estimates. Source and preparation are displayed; missing nutrients stay unavailable.
- Save and reuse meals from the logging form or an existing entry. Reuse creates a fresh entry, with adjustable amounts; deleting a template keeps history. Manual calories and custom movements remain available.
- Search 106 movement references by name, aliases, muscles or equipment. References are available from settings, manual workout entry and active sessions.
- Active sessions provide large rep tap controls, quick rep choices, per-set weights, timed intervals, lap splits and undo. Finish saves detailed results; recoverable drafts survive relaunch and failed writes.
- Compact session/rest summaries keep the active controls near the top. Rep buttons have equal heights. Large text uses a vertical session header. Optional rest alerts, custom rest durations, pause/resume and screen-awake preferences are provided; light-mode colours are unchanged.

All 70 unit/functional UI checks passed across the full run and targeted retries (58 unit, 12 UI). The final targeted run passed 60 with no failures/skips: `/tmp/FitnessAppOfflineWorkoutFinalRegression.xcresult`; the other ten UI checks passed in `/tmp/FitnessAppOfflineWorkoutFinalVerification.xcresult`. Final Release/source/bundle/credential checks passed. Food portions, reused meals and compact rep/rest screens were visually inspected. Simulator launch/event delays occurred in earlier attempts and are recorded in the release review. Real-device notification delivery, timer recovery and battery/frame performance still need an iPhone check.

## Yearly weight history and appearance

- The weight chart offers 7 days, 30 days, 90 days and 1 year (365 calendar days). The default remains 30 days; the calorie/workout range pickers retain their existing three choices.
- The previous light and dark colour palettes, caption styles, chart colours and progress ring were restored after review. Cards and buttons have no outline borders.
- Disabled secondary workout controls now use the existing disabled colours, consistent with primary buttons.

The shared calendar range code was checked directly: a measurement 330 days old belongs in the year range and is excluded from the quarter range, and the yearly domain spans 365 calendar days. Debug/unsigned iPhone Release build logs are `/tmp/fitness-contrast-debug.log` and `/tmp/fitness-contrast-release.log`. Earlier `/tmp/FitSwiftContrast*.png` screenshots and contrast calculations describe the reverted colour proposal.

## Combined UK and US food library

- Browse 10,625 offline food references, including 2,832 usable UK CoFID entries alongside the original 7,793 USDA entries.
- Select All, UK or US, with source-specific categories and counts. Each result displays its source and calories per 100 g; details retain the original source code, licence acknowledgement and any drink-density conversion note.
- Saved meals and history retain their original nutrition, with UK/US labels. Existing USDA-only meals remain compatible.

All 61 unit checks and the targeted UK/US filtering, search, portion and meal-save UI flow passed: `/tmp/FitnessAppCombinedFoodsVerifiedTests.xcresult`, `/tmp/FitnessAppCombinedFoodsFinalUI.xcresult`. The UK library and portion screenshots were inspected. The unsigned iPhone Release build and offline guards passed; the update runs in the local simulator. The earlier palette and border removal remain unchanged. The remaining UI flows were not rerun for this catalogue update.
