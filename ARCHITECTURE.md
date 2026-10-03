# Application architecture

Keep responsibilities in small, concrete classes. Use Flutter widgets and local
state for the skeleton; no routing or state-management package is needed.

```text
lib/
  main.dart                   Application entry point
  app/
    receiptwise_app.dart      MaterialApp configuration
    app_shell.dart            Four-destination navigation shell
    theme/app_theme.dart      Shared Material 3 light/dark themes
  ui/
    screens/                 Screen presentation and user interactions
    widgets/                 Shared presentation widgets
  models/transaction_model.dart    Immutable transaction and SQLite mapping
  models/receipt_capture_geometry.dart    Shared frame and capture-time geometry
  models/ocr_result.dart    Raw OCR text, blocks, and flattened lines
  models/receipt_review_draft.dart    Input to editable receipt review
  services/ocr_service.dart    Bundled Latin recognition and resource ownership
  services/receipt_parser.dart    Local merchant, amount and date heuristics
  services/receipt_save_service.dart    Copy-before-insert and rollback handling
  services/transaction_management_service.dart    Update and row-first receipt deletion
  utils/transaction_format.dart    Local dates and VND display formatting
  models/spending_analytics.dart    Immutable category/day aggregates
  services/analytics_service.dart    SQLite snapshot and integer-cent aggregation
  utils/analytics_format.dart    Full/compact analytics amounts
  ui/widgets/category_donut_chart.dart    Animated widget and drawing-only painter
  ui/widgets/weekly_bar_chart.dart    Animated widget and drawing-only painter
  services/receipt_camera_service.dart    Camera controller and serialized operations
  services/receipt_image_service.dart    Selected photo storage and cache cleanup
  services/receipt_image_processor.dart    Isolate-based orientation correction and crop
  repository/transaction_repository.dart    Local transaction operations
  database/app_database.dart    Lazy SQLite connection and versioned schema
test/
  app_navigation_test.dart    Navigation and constrained-layout checks
  models/transaction_model_test.dart    Serialization and timestamp checks
  repository/transaction_repository_test.dart    Real SQLite data-layer checks
  services/receipt_camera_service_test.dart    Lifecycle, capture, focus checks
  services/receipt_image_processor_test.dart    Geometry, EXIF, and temporary crop checks
```

Review Save connects to the local data layer through ReceiptSaveService. Camera,
cropping, offline OCR, local receipt parsing and explicit saving are implemented.

## Local transactions

`AppDatabase.instance` lazily opens `receiptwise.db` in sqflite's private database
directory. Schema version 1 creates the requested `transactions` table and an
index on `date`. Opening concurrently reuses one connection, failed opens can be
retried, and `close()` allows reopening later. Only close while operations are idle.
Schema changes in later tasks must increment the version and supply migrations.

`TransactionModel` stores DateTime fields as UTC ISO-8601 strings with six
fractional digits, keeping SQLite text comparisons accurate at microsecond
boundaries. Read timestamps are UTC; UI code should convert to local time for
display. The nullable image field contains a path only.

`TransactionRepository` provides:

- `insertTransaction(record)`: requires no ID and returns the generated integer ID.
- `updateTransaction(record)`: requires an ID and returns the affected row count.
  A null image path clears an existing path.
- `deleteTransaction(id)`: returns the affected row count, leaving image file
  management to services.
- `getTransactionById(id)`: returns the record or null if absent.
- `getAllTransactions()`: returns date-descending records, with descending IDs
  breaking equal-date ties.
- `getTransactionsBetweenDates(start, end)`: uses inclusive boundary instants and
  the same ordering; reversed bounds throw ArgumentError. An end at midnight
  does not implicitly include the rest of that calendar day.

No repository operation is called automatically by OCR. Saving a reviewed
receipt requires the user to press Save and pass form validation. Tests
inject an FFI SQLite factory, use isolated in-memory databases, and verify file
persistence with a temporary database. FFI is a development dependency only;
the Android application uses sqflite.

## Navigation

`AppShell` owns the selected destination. Home, Transactions, and Analytics stay
in an `IndexedStack`. Scanner opens a full-screen Navigator route from the
navigation bar or Home; it is not instantiated in an offstage tab. Returning
from Scanner preserves the preceding tab unless a transaction was saved, in which
case Home displays its permanent receipt image and success feedback.

ReviewReceiptScreen follows crop and OCR. History pushes TransactionDetailScreen,
which pushes TransactionEditScreen. ReceiptPreviewScreen remains
available as a standalone image preview; it is no longer part of the scan route.

## Receipt camera flow

- ReceiptCameraService selects the back camera when available, otherwise the
  first available camera. The official camera plugin requests permission during
  initialization; audio is disabled, so no microphone permission is needed.
- Android declares CAMERA permission with optional camera hardware. Devices
  without cameras reach the unavailable state instead of being excluded from
  installation. The selected camera package requires Android SDK 24 or newer
  and Flutter 3.44 / Dart 3.12 or newer.
- CameraPreview fills the route using cover cropping. Focus taps are mapped
  back through that crop into normalized preview coordinates, and focus is
  requested only if the controller reports support.
- ReceiptFrameOverlay paints a vertical receipt rectangle with a dark exterior.
  Its rectangle comes from the same geometry function used to crop captured photos.
- ScannerControls provides Close, off/torch toggle, and Capture. Duplicate
  capture is guarded both by the screen and the service.
- Camera operations are serialized. Inactive/paused/hidden/detached lifecycle
  states release the camera; resumed recreates it. The controller is also
  released while reviewing a photo and on scanner disposal. Permission and
  initialization failures show a Retry state with instructions where needed.
- Cropped images go through OcrService while Scanner shows a processing indicator.
  ReviewReceiptScreen opens on success, empty output, or recognition failure.
  Retake/back discards the crop and restarts the camera. Successful Save returns
  the committed transaction through Scanner to AppShell and selects Home.
- Original captures and temporary crops are cleaned after review dismissal,
  including rejection, processing failure and successful commit. Save failure
  keeps review open with its temporary crop intact. Documents copies referenced
  by saved transactions are never removed when AppShell is disposed or replaced.

## Receipt cropping

Capture records the rendered viewport, exact framing rectangle, oriented preview
resolution, lens mirroring, device orientation, and sensor orientation. The camera
locks capture orientation to this snapshot while taking the picture, preventing
rotation during capture from invalidating the geometry. Capture requests the
maximum resolution supported by the camera.

ReceiptImageProcessor decodes and crops in an isolate. It normalizes EXIF rotation
and reflection (including formats whose decoder already applies EXIF). For
untagged images with swapped dimensions it uses the captured device and sensor
orientation. The crop mapping first inverts CameraPreview's centered BoxFit.cover
crop, then maps through the preview's central sensor region into the upright
still image. Front-camera preview mirroring is inverted as well. This handles
preview/still aspect ratio and pixel resolution differences independently.

Crop coordinates are rounded outward and clamped to native pixel bounds. The
rectangular crop includes the rounded guide's corners, preserves native pixels
without resizing, and is encoded as JPEG quality 95. Stale full-image EXIF
dimensions, orientation, and thumbnail metadata are removed. Output is written
only under an isolated receiptwise_scan_ directory in application temporary
storage. No documents-directory write or SQLite insert happens before explicit Save.

The mapping assumes centered preview/still sensor regions as exposed by the
camera plugin; device-specific field-of-view differences still require Android
hardware verification. Temporary receipts are copied to documents storage only
after explicit review confirmation.

## Offline OCR and review

OcrService lazily owns a TextRecognizer using TextRecognitionScript.latin. Android's
plugin dependency bundles com.google.mlkit:text-recognition:16.0.1; no Play Services
model-download dependency is used. Recognition reads the temporary cropped file
with InputImage.fromFilePath and performs no network, API-key or Firebase calls.
The plugin requires compile SDK 36, covered by this Flutter SDK's defaults.

recognizeText returns OcrResult with fullText, native TextBlocks and flattened
TextLines in recognition order, preserving their coordinates. It does not parse
receipt values. Calls are serialized; errors propagate to the UI, which opens
manual review. Disposal rejects new calls, waits for accepted work and closes the
recognizer once. Stopwatch spans each recognition attempt and logs milliseconds
only with kDebugMode. No receipt contents or performance guarantees are logged.

ReceiptParser uses OCR text to suggest the first plausible merchant header, labeled
total (or largest currency-tagged amount), and first valid day/month/year date.
Vietnamese grouping separators and total labels are supported without cloud AI.
Heuristics are best-effort and every value remains editable; missing values stay
empty. Review defaults to Other and offers the six required categories, with raw
OCR text shown as reference. All form fields stay mounted in a scrollable Column.

Save requires a nonblank merchant, finite positive amount, strictly valid date,
and category. ReceiptSaveService asks ReceiptImageService to copy the final crop
under an atomically unique receipt directory in application documents storage.
The JPEG filename contains the timestamp and unique directory suffix. SQLite
receives only the image path plus transaction fields and ISO timestamps. There is
no resizing or image binary in the database. Save/back/Retake are guarded while
work is pending; the service also rejects concurrent saves. After commit the
review and scanner routes return to Home, which displays success feedback.

If copying fails, no insert is attempted. If insertion fails, the new uncommitted
documents copy is removed and the original temporary crop is retained for retry.
Rollback-cleanup errors preserve the primary error and log in debug mode; a copy
may remain if the filesystem denies cleanup. Temporary image cleanup occurs only
after review is safely dismissed or saving has committed. Camera and OCR services
remain unchanged by the save integration.

Automated service tests mock ML Kit's method channel, and a widget test covers
manual entry after failure. All 44 tests passed on 2026-10-02, including real SQLite
save integration, rollback, editable prefills and validation. Verify native OCR
on Android, including first-run airplane-mode recognition, empty receipts, errors,
background/resume and physical receipt accuracy. Mock timings are not native latency.

## Transaction history and management

TransactionsScreen lazily loads TransactionRepository.getAllTransactions when
visible, on reactivation, after scanner saves, after returning from detail and on
refresh. Repository ordering is transaction date descending with descending IDs
breaking ties. Async request generations prevent older refreshes overwriting newer
results. Loading/error/retry and "No transactions yet" states are explicit. Rows
wrap in an InkWell rather than relying on a fixed tile height. VND values use dot
grouping, optional comma fractional digits, and the ₫ suffix; dates are local.

TransactionDetailScreen loads by ID, shows a zoomable full image and all record
fields, and handles absent records. ReceiptImage uses filesystem image widgets
with null/missing/corrupt-file placeholders; thumbnails request a small decode
without modifying the stored file. Edit validates merchant, positive finite amount,
strict date and required category using existing helpers without changing parsing.
It updates the same row and preserves the image path and createdAt timestamp.

Deletion requires a confirmation dialog. TransactionManagementService deletes
the database row before deleting an existing image under application documents.
Database errors leave the image intact. Missing image files are successful cleanup.
Empty app-owned receipt directories can be removed after their image is deleted.
If cleanup fails after row deletion, detail shows a separate Retry image deletion
state; this retries only the file operation. Done/back can leave this state, so a
file may remain if the user dismisses it or the app closes before cleanup completes.
Busy guards disable duplicate actions. History reloads after detail closes, and
AppShell clears/updates the latest Home receipt when that transaction changes.

History/management tests use fake repositories for UI interactions and real SQLite
plus temporary documents directories for filesystem/database guarantees. All 55
tests passed on 2026-10-02. Android device and restart behavior remain to verify.

## Analytics

AnalyticsScreen activates lazily and uses AnalyticsService.load to query the
repository's SQLite snapshot. AppShell invalidates analytics after inserts, edits
and deletion; opening the tab or manual refresh also reloads. Async request tokens
prevent stale requests overwriting newer results. Category totals include all saved
transactions; the weekly series includes today and six preceding local calendar
days, filling absent days with zero and excluding older/future dates. Dates are
converted from stored UTC into local calendar days before grouping.

AnalyticsService aggregates the six fixed categories, mapping unknown legacy
categories to Other. Positive finite transaction amounts are converted into rounded
integer cents using BigInt. Totals can exceed double's range without becoming
infinite. Fraction/height normalization uses integer division before converting to
double; no unsafe large total is passed to Canvas. Invalid/nonpositive legacy
amounts contribute zero. Empty transactions and zero spending have explicit states.

CategoryDonutChart animates a drawing-only CategoryDonutPainter from zero to full
sweep using TweenAnimationBuilder. It draws a neutral track and category arcs with
Canvas.drawArc, Paint and Rect. The legend provides category, percentage and amount;
a single category fills the ring. WeeklyBarChart animates normalized heights through
WeeklyBarPainter, which draws grid lines and rounded rectangles. Flutter widgets
outside paint provide day labels, amount scales, tooltips and accessible descriptions.
The latest-seven-day range is shown explicitly. Charts respect disabled animations
and inactive tabs use TickerMode. Painter shouldRepaint compares progress, drawing
data and colors by value; painter lists are immutable snapshots.

Large analytics amounts use compact units or scientific notation with complete VND
amounts in tooltips. Scale/chart height grows for enlarged text. No chart library or
new dependency is used, and no aggregation/database calls happen in CustomPainter.
All 66 tests passed on 2026-10-02, including real SQLite integration, extreme/zero
totals, rendered pixels, animations, repaint decisions and responsive layouts.

## Production-readiness review (2026-10-03)

The existing layers and navigation remain intact. Camera retries are guarded and
damaged controllers are released; focus cleanup cannot discard a successful
capture. Database close requests share one future, and reopening waits for close.
Transaction navigation and committed saves remain guarded against duplicate taps.

Scanner framing reserves the actual scaled control height. Forms use consistent
Material 3 spacing, 48-pixel minimum touch targets, scrollable keyboard layouts and
category labels that fit narrow screens. Large amounts use plain decimal form
values. Currency fallback parses currency-tagged amounts rather than unrelated
phone or item numbers. OCR and chart drawing keep their existing layer boundaries.

The review passed formatting, dependency resolution, analysis and all 78 tests.
See [PRODUCTION_READINESS.md](PRODUCTION_READINESS.md) for changed files and device
and release checks that remain unverified.

## Future layer boundaries

- UI displays service/repository results and gathers explicit user confirmation.
- Models represent parsed receipts, categories, and stored transactions.
- Services capture receipts, run Google ML Kit Text Recognition on-device,
  parse merchant/amount/date with heuristics, and manage receipt image files.
- Repository exposes transaction operations and maps models to database rows.
- Database owns sqflite initialization, schema versions, and SQL operations.

Keep SQLite, filesystem, and ML Kit calls outside widget build methods. Avoid a
generic repository framework, dependency injection container, or extra layers
unless a later feature requires them.

## Deferred requirements

- Release APK compilation succeeded on 2026-10-03. Verify installation on Android,
  choose a production application ID, and configure release signing before publishing.
- Verify camera permission grant/deny, absent camera, off/torch, supported focus,
  rotation, duplicate capture, Retake/Use Receipt, and background/resume on Android
  hardware. Automated tests passed on 2026-10-02.
- Verify parser accuracy and capture-to-save/restart persistence on real Android
  receipts; OCR results must never save automatically.
- Verify crop alignment and OCR readability on physical Android devices, including
  all four orientations and devices with different preview/still aspect ratios.
- Verify history, edit, delete and locked-file cleanup retry on Android, including
  persistence after restart.
- Verify analytics animation performance, reduced motion, tooltips and date-boundary
  behavior on physical Android devices.

Do not introduce Firebase, Supabase, cloud OCR, paid OCR APIs, or third-party
chart packages.
