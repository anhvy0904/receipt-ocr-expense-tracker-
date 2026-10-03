# ReceiptWise production-readiness review

Reviewed on 2026-10-03 without redesigning the application architecture or adding
dependencies. Automated checks pass; physical Android and signed release
verification remain TODO.

## Findings and fixes

- **Camera:** guard repeated retries, release controllers after runtime errors,
  make disposal idempotent, and retain successful captures if focus unlock fails.
  Existing lifecycle and capture serialization remain in place.
- **Cropping:** cleanup failures preserve the original processing error. The
  scanner frame reserves space for scaled controls and disables capture when no
  usable frame fits. Processing remains outside the widget.
- **OCR:** reviewed queued recognition, disposal, debug-only timing, progress and
  failure-to-manual-review behavior. No cloud calls or parsing changes in OCR.
- **Parser:** currency fallback excludes unrelated phone and item numbers on
  currency lines; regression coverage verifies this behavior.
- **Review/edit:** consistent fields, long category handling, scrollable keyboard
  layouts and plain decimal prefills for large amounts. Save remains locked after
  commit while the route closes. Failed saves retain edits and report retry/retake
  recovery without promising an unavailable photo exists.
- **SQLite:** concurrent close calls share completion, reopening waits for close,
  and failed opening does not poison subsequent use. Close the database only when
  repository operations are idle; backgrounding does not close it.
- **History:** duplicate detail navigation is guarded. Existing missing-image,
  loading, empty, error, edit and confirmed-delete handling was reviewed.
- **Analytics:** reviewed SQLite loading, aggregation, extreme amounts, empty and
  zero states, animation and repaint behavior. Aggregation stays outside painters;
  no chart package was added.
- **Material 3:** consistent spacing, semantic colors, input styling and padded
  48-pixel touch targets. Scanner controls and guidance use dark backgrounds for
  contrast against camera content. Small screens and enlarged text are tested.

## Verification

Using Flutter 3.47.5 / Dart 3.13.4:

```text
dart format .
flutter pub get
flutter analyze
flutter test
```

Formatting and dependency resolution succeeded, analysis reported no issues,
and all **78 tests passed**. Tests cover database integration, parser regression,
camera controller failures/retries, duplicate navigation/saves, unmounted save
completion, small-screen keyboard layouts, touch targets and existing chart/OCR
behavior. Automated camera/ML Kit tests use test doubles; native hardware accuracy
and performance have not been established by these checks.

## Files created

- `test/production_ui_test.dart`
- `PRODUCTION_READINESS.md`

## Files modified

- `.gitignore`
- `README.md`
- `ARCHITECTURE.md`
- `lib/app/theme/app_theme.dart`
- `lib/database/app_database.dart`
- `lib/models/receipt_capture_geometry.dart`
- `lib/repository/transaction_repository.dart` (formatting only)
- `lib/services/receipt_camera_service.dart`
- `lib/services/receipt_image_processor.dart`
- `lib/services/receipt_parser.dart`
- `lib/ui/screens/analytics_screen.dart`
- `lib/ui/screens/home_screen.dart`
- `lib/ui/screens/review_receipt_screen.dart`
- `lib/ui/screens/scanner_screen.dart`
- `lib/ui/screens/transaction_detail_screen.dart`
- `lib/ui/screens/transaction_edit_screen.dart`
- `lib/ui/screens/transactions_screen.dart`
- `lib/ui/widgets/placeholder_content.dart` (documentation comment)
- `lib/ui/widgets/scanner_controls.dart`
- `lib/utils/transaction_format.dart`
- `test/repository/transaction_repository_test.dart`
- `test/review_receipt_screen_test.dart`
- `test/services/receipt_camera_service_test.dart`
- `test/services/receipt_parser_test.dart`
- `test/transaction_history_test.dart`

## Release build follow-up (2026-10-03)

Ran `flutter clean`, `flutter pub get`, `flutter analyze`, `flutter test` and
`flutter build apk --release`. Analysis had no issues and all 78 tests passed.
The release build succeeded after two Android build configuration fixes:

- Modified `android/gradle.properties`: disable Kotlin incremental compilation
  because plugin sources in the C: Pub cache and project output on E: caused cache
  relative-path failures.
- Modified `android/app/build.gradle.kts` and created
  `android/app/proguard-rules.pro`: apply R8-generated, class-specific suppression
  rules for optional non-Latin ML Kit options. Latin remains bundled; shrinking
  stays enabled and no extra recognition models were added.
- Updated `README.md`, `ARCHITECTURE.md` and this report to record the build.

Local artifact: `build/app/outputs/flutter-apk/app-release.apk`, 88,051,572 bytes.
This is a release-mode build using the existing debug signing configuration. It
has not been installed on a device or published; production signing remains TODO.

## Remaining TODOs

- Validate Android permission grant/denial, absent camera, torch/focus, all
  orientations and background/resume during capture/OCR/save on physical devices.
- Verify preview-to-crop alignment across camera hardware and first-run offline
  OCR in airplane mode using actual Vietnamese receipts.
- Verify persistence after restart, image cleanup, large-text layouts, chart
  performance and reduced motion on physical Android devices.
- Configure a production application ID and release keystore/signing. Current
  release configuration uses debug signing and is unsuitable for publication.
- Configure production signing and verify the APK; add real screenshots, demo video and APK download
  links. README contains clearly marked TODO placeholders; no URLs were invented.
