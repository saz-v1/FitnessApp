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
