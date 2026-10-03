# 1. Project Title: ReceiptWise

## 2. Project Description

ReceiptWise is an Android Flutter application that turns physical receipts into
local expense transactions. Camera capture, receipt cropping, Latin text recognition
and heuristic extraction run on the device. Users review and edit every result
before explicitly saving it. SQLite stores transactions; receipt images stay in
application documents storage. No cloud OCR, Firebase, Supabase, paid OCR API or
chart library is used.

## 3. APK Download

**TODO: public APK download URL not available.**

A release-mode APK was built locally on **2026-10-03**:

- Version: **1.1.0+3**
- File: `build/app/outputs/flutter-apk/app-release.apk`
- Size: **88,386,859 bytes** (84.3 MiB)
- SHA-256: `A99A393013B274E462C49D410B39F4FF02691F778A77DFDB676361BE743BF52D`

The artifact is generated locally and ignored by version control. It uses the
dedicated ReceiptWise release certificate, verified using APK Signature Scheme v2.
It has not been installed or published; verify it on Android before providing a public link.

## 4. Demo Video

**TODO: demo video URL not available.** Record the Android flow from scan and OCR
through review, Save, History, Edit/Delete and Analytics, then add the real URL.

## 5. Screenshots

These images are actual Flutter UI renders from the automated host flow using a
synthetic receipt/OCR fixture. They are **not physical Android screenshots**.
TODO: add camera/receipt evidence captured on a real device.

| Screen | Screenshot |
| --- | --- |
| Home | [Light](docs/screenshots/home-light.png), [Dark](docs/screenshots/home-dark.png) |
| Scanner and receipt frame | TODO: physical-device screenshot |
| Editable Review | [Fixture review](docs/screenshots/review.png) |
| Transaction History | [Fixture history](docs/screenshots/history.png) |
| Category donut and weekly bars | [Donut](docs/screenshots/analytics.png), [Weekly](docs/screenshots/weekly-bars.png) |

The four-page [technical report](output/pdf/receiptwise_technical_report.pdf)
documents architecture, parsing, storage, charts, UI evidence and limitations.

## 6. Features

- SQLite-backed Home summary: all-time spending, latest-seven-day spending,
  transaction count and three most recent transactions; refresh after changes.
- Receipt camera/gallery input using official `image_picker`, Android lost-image
  recovery, and validated manual entry without requiring an image.
- Provider shares one SQLite snapshot across Home, History and Analytics.
- Full-screen back-camera preview, off/torch flash, supported tap-to-focus,
  receipt framing, permission/error handling and lifecycle-aware camera release.
- Orientation-aware framing crop at native resolution, processed in an isolate.
- Offline ML Kit OCR with raw text, blocks and lines; recognition failure still
  opens manual review. Stopwatch timings are printed only in debug builds.
- Vietnamese merchant/amount/date heuristics, editable review fields, six expense
  categories, validation and duplicate-save protection. Nothing saves automatically.
- Local image copy and SQLite insertion only after Save. Failed inserts retain the
  temporary crop and form edits for retry.
- History ordered by transaction date descending, thumbnails, local dates,
  formatted VND amounts, full-image details, validated edits and confirmed deletion.
- Animated category donut and latest-seven-day bars drawn with CustomPainter.
  Empty/zero spending, one category and very large totals are handled.
- Material 3 light/dark/system selection from the Appearance menu, scrollable forms, enlarged-text support,
  consistent spacing, padded touch targets and high-contrast scanner controls.

Categories: **Food, Study, Travel, Gear, Entertainment, Other**.

## 7. Technical Highlights

- Completely on-device Latin OCR, with no API keys or receipt upload.
- Native-resolution receipt cropping in an isolate, accounting for preview cover,
  captured resolution and orientation.
- Explicit user confirmation before persistence; failed insertion retains the
  temporary source for retry and rolls back the uncommitted image copy.
- Serialized camera/OCR work, lifecycle cleanup and duplicate-action guards.
- SQLite date-range queries and UTC ISO-8601 timestamps with local display.
- CustomPainter charts with animation, reduced-motion support and aggregation
  outside the drawing code.
- Material 3 light/dark styling, accessible touch targets and responsive forms.
- Automated tests for SQLite, parsing, async handling, chart drawing and UI layouts.

## 8. Tech Stack

| Component | Requirement / implementation |
| --- | --- |
| Flutter | 3.44 or newer, within the current Flutter 3.x project target |
| Dart | 3.12 or newer; null safety |
| Verified SDK | Flutter 3.47.5 / Dart 3.13.4 |
| Target | Android; this repository includes the Android host |
| Android runtime | API 24 or newer with the supplied Flutter defaults |
| Android compile SDK | API 36 with the supplied Flutter defaults / ML Kit plugin |
| Android build tooling | Android SDK tools and a compatible JDK 17 setup |
| Camera | Official `camera` package |
| Camera/gallery picker | Official `image_picker` package |
| State management | `provider` + ChangeNotifier |
| OCR | `google_mlkit_text_recognition`, bundled native Latin model |
| Persistence | `sqflite`; `sqflite_common_ffi` for host tests only |
| Images/files | `image`, `path_provider`, `path` |
| Charts | Flutter Canvas and CustomPainter only |
| Tests | `flutter_test`, native-channel fakes, FFI SQLite and rendered Canvas checks |

The camera dependency raises the minimum above older Flutter 3.x releases. Use
`pubspec.yaml` and the committed `pubspec.lock` together. Mobile OCR is not supported
by Flutter web/desktop; host unit/widget tests mock the native recognizer instead.

## 9. Architecture

The app uses a small separation of UI, services, repository, database and models.
Widgets own local UI state and use Flutter Navigator for routes. Provider exposes
TransactionState's shared SQLite records, loading/error states and computed
summary/chart data. Services notify state after committed writes; AppearanceState
controls the current theme. No dependency-injection container is needed.

```text
Camera → Capture → Crop → On-device OCR → ReceiptParser → Editable Review
                                                        ↓ explicit Save
                                      Documents image copy → SQLite insert → Home

Camera picker / gallery → normalize image → same OCR and Review flow
Manual entry → same validated Review form (no image required)
Services → SQLite → TransactionState (Provider) → Home / History / Analytics
```

- **UI:** presentation, form validation, confirmation dialogs and loading/error states.
- **Services:** camera/OCR ownership, cropping, parsing, image files, save/delete
  coordination and analytics aggregation.
- **Repository:** transaction CRUD and date-range queries.
- **Database:** a lazy application-level SQLite connection, versioned schema and
  close/open coordination. Keep it open during app use; close only when operations
  are idle. Backgrounding does not close the database during a save.
- **Models:** immutable transactions, OCR results, capture geometry and aggregates.

See [ARCHITECTURE.md](ARCHITECTURE.md) and the
[production-readiness review](PRODUCTION_READINESS.md) for implementation details.
The [comparison review](COMPARISON_REVIEW.md) documents how ReceiptWise differs
from the referenced course project and which receipt-flow gaps were improved.
See [COURSE_READINESS.md](COURSE_READINESS.md) for the latest course-core upgrade,
verification, file changes and remaining device/video acceptance checks.

## 10. Project Structure

```text
lib/
  main.dart
  app/                    MaterialApp, navigation shell, Material 3 theme
  models/                 Transactions, OCR output, receipt geometry, analytics
  database/               AppDatabase and SQLite schema
  repository/             TransactionRepository
  state/                  Provider transaction snapshot and appearance selection
  services/               Camera, OCR, parser, crop, storage, save/delete, home summary, aggregation
  ui/screens/             Home, Scanner, Review, History, Detail, Edit, Analytics
  ui/widgets/             Camera/frame/controls, images, empty states, chart painters
  utils/                  Local-date, VND and analytics display formatting
test/
  models/                 Transaction mapping / timestamp tests
  repository/             Actual SQLite CRUD, dates, ordering and resource tests
  services/               Camera, OCR, parser, crop, storage, aggregation tests
  *_test.dart             Navigation, forms, history, charts and responsive layouts
android/                  Android host and Gradle configuration
integration_test/         Android SQLite flow with mocked camera/OCR boundaries
docs/                     Demo/signing guides, UI fixture screenshots, PDF source
output/pdf/               Four-page technical report
README.md
ARCHITECTURE.md
PRODUCTION_READINESS.md
COMPARISON_REVIEW.md
COURSE_READINESS.md
pubspec.yaml
pubspec.lock
```

## 11. OCR Flow

The scanner captures one image, snapshots framing/orientation and releases the
camera during processing. ReceiptImageProcessor corrects EXIF/fallback orientation,
maps preview cover cropping into still-image coordinates and writes a JPEG crop
at quality 95 under temporary application storage. It preserves native pixels.

OcrService lazily owns a `TextRecognizer(script: TextRecognitionScript.latin)` and
passes the cropped file through `InputImage.fromFilePath`. The Android plugin
bundles `com.google.mlkit:text-recognition:16.0.1`, rather than a runtime-download
Play Services recognizer. It returns full text, native blocks and flattened lines.
Requests are serialized; disposal waits for accepted work and closes the recognizer.

The UI shows processing progress. Errors or empty output open Review anyway for
manual input. Stopwatch duration logs are debug-only, contain no receipt text and
make no fixed latency promise. Review and Save are always explicit user actions.

## 12. Receipt Parsing

ReceiptParser uses local regular expressions and header heuristics:

- Merchant: the first plausible text header, excluding totals, dates, currency
  amounts, common invoice/contact labels and numerical lines.
- Amount: prioritize final totals such as `TỔNG CỘNG`, `TỔNG TIỀN`, `Grand total`
  and `Amount due` over item-level `THÀNH TIỀN`. Recognize `THANH TOÁN` and
  `CỘNG TIỀN` too, with Vietnamese accent folding and whitespace normalization.
  A standalone amount on the next line can follow a total label. Subtotal,
  tendered cash and change do not replace the expense total.
  Without a labeled total, use the largest explicitly currency-tagged candidate.
  Unrelated phone/item numbers are excluded from that fallback.
- Supported examples: `150,000 VND`, `150.000 VND`, `150.000đ`, `150 000 đ`,
  `TỔNG CỘNG: 150.000`, `THÀNH TIỀN: 150,000`.
- Date: match day/month/year or year/month/day with `/`, `-` or `.` and reject
  normalized invalid dates or mixed separators. Prefer date-labelled lines.
  Examples: `01/10/2026`, `2026-10-01`; review displays `DD/MM/YYYY`.

Missing values remain empty. Heuristics can misread unusual receipt layouts, so all
prefills remain editable. Save validates a nonblank merchant, positive finite amount,
valid date and one of the six categories. There is no cloud AI parser.

## 13. Database Design

Database: `receiptwise.db`; schema version: **1**.

```sql
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  merchant TEXT NOT NULL,
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  category TEXT NOT NULL,
  receipt_image_path TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX idx_transactions_date ON transactions (date);
```

DateTime values are stored as UTC ISO-8601 strings with six fractional digits and
converted to local time for display. Date-range queries include both boundary
instants; a midnight end is not implicitly expanded to the rest of that day.

Save first copies the final crop into a unique receipt directory/filename under
application documents storage, then inserts the transaction. SQLite stores only
the path, never image binary data. Failed inserts remove the uncommitted copy where
possible and retain the temporary source for retry. Edits retain image path and
creation timestamp. Confirmed deletion removes the row before the image; missing
files are tolerated and failed file cleanup has a separate retry action.

## 14. CustomPainter Analytics

- `CategoryDonutChart` / `CategoryDonutPainter`: six-category all-time totals,
  percentage/amount legend, neutral zero-spending track and animated `drawArc` sweeps.
- `WeeklyBarChart` / `WeeklyBarPainter`: today plus six preceding local calendar
  days, zero-filled gaps, day labels, amount scale and animated rounded rectangles.
- AnalyticsService queries SQLite through TransactionRepository and aggregates
  outside paint. Integer cents prevent overflow when finite amounts have a total
  larger than double's range. Painters receive finite normalized fractions/heights.
- `shouldRepaint` compares data, progress and colors by value. Flutter widgets
  provide labels, tooltips and semantics. Reduced motion is respected and hidden
  tabs pause animations. Full amounts are available behind compact large-value labels.

No chart library is installed. Legacy nonfinite/negative values contribute zero to
analytics. Charts refresh on activation, saves, edits/deletions and manual refresh.

## 15. Getting Started

Install Flutter and Android SDK tooling, then add Flutter's `bin` directory to PATH.
For the SDK supplied for this workspace, PowerShell can use:

```powershell
$env:Path = 'D:\setup\flutter_windows_3.47.5-stable\flutter\bin;' + $env:Path
Set-Location 'E:\OCR Expense Tracker\OCRExpenseTracker'
flutter doctor -v
flutter doctor --android-licenses
flutter pub get
```

On another machine, use that machine's Flutter path and checkout directory. Resolve
Android SDK/JDK issues reported by `flutter doctor`, install Android SDK 36 and the
NDK version requested by Flutter/Gradle, and connect an Android phone with USB
debugging enabled or start an Android emulator. Dependency resolution and initial
Android builds can download packages; installed receipt OCR itself runs offline.
No API keys, Firebase configuration or account setup are needed. Debug builds need
no private signing configuration. Release builds require your own ignored signing
files as explained in [docs/RELEASE_SIGNING.md](docs/RELEASE_SIGNING.md).

## 16. Running the Project

```powershell
flutter devices
flutter run -d <android-device-id>
```

Allow camera access when requested. If permission is denied, allow it in Android
settings and use Retry. Devices without a camera show an unavailable state.
Scan, review/edit the details and press Save; saved entries appear in Transactions
and Analytics. Retake discards the temporary crop and returns to the camera.
Home also offers Take receipt photo, Choose receipt image and Enter expense
manually. The Appearance menu switches Light / Dark / System; selection is kept
for the running session and resets to System after process restart.

## 17. Testing

Run from the project root:

```powershell
dart format .
flutter pub get
flutter analyze
flutter test
```

For coverage:

```powershell
flutter test --coverage
```

Verification on **2026-10-03** with the supplied SDK: formatting and dependency
resolution succeeded, analyzer reported **no issues**, and **96 tests passed**.
Flutter invocations used `--no-version-check` to avoid checking for SDK updates.
Tests cover real SQLite persistence, async disposal, save rollback, parser formats,
missing images, edit/delete, chart pixels/animation and keyboard/enlarged-text layouts.
Native Android camera/OCR behavior and release APK installation remain device checks.

On an Android device:

```powershell
flutter test integration_test/receipt_flow_test.dart -d <android-device-id>
```

The integration scenario uses native SQLite and fixture capture/OCR boundaries.
It is provided but has not been run on Android here because no device was connected.
See [docs/DEMO_CHECKLIST.md](docs/DEMO_CHECKLIST.md) for native acceptance checks.

## 18. Build APK

Application ID: `com.anhvy.receiptwise`. Release builds use a dedicated private
keystore, configured in ignored `android/key.properties`, with no debug fallback.
See [release signing and backup instructions](docs/RELEASE_SIGNING.md). Back up
the local keystore and properties securely before moving or deleting the checkout.
The new ID installs separately from older `com.example.receiptwise` debug builds;
old records are not migrated.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Default output: `build/app/outputs/flutter-apk/app-release.apk`.
Optional per-ABI APKs: `flutter build apk --release --split-per-abi`.
The release APK was built successfully on 2026-10-03 (88,386,859 bytes).
Its dedicated RSA certificate was verified with Android apksigner. Physical-device
release testing and public distribution remain TODO.

Android build configuration disables Kotlin incremental compilation to avoid
cross-drive cache errors when the project and Pub cache are on different Windows
drives. Narrow R8 rules suppress references to optional non-Latin ML Kit options;
the app uses only the bundled Latin recognizer. If more recognition scripts are
added, include their native dependencies and revisit those rules.

## 19. Permissions

| Permission / capability | Purpose |
| --- | --- |
| Camera | Requested through the official camera plugin when initializing capture. |
| Camera hardware | Declared optional so devices without a camera can show an unavailable state. |
| Internet in debug/profile | Flutter development tooling; receipt OCR does not use it. |
| System photo picker | User-selected receipt images through image_picker; no broad gallery permission is requested by application code. |

If camera permission is denied, enable it in Android settings and use Retry.
Audio capture is disabled. The app stores files in app-owned directories and
does not require broad shared-storage access. Manifest merge rules remove inherited
audio/shared-storage permissions. The release overlay removes Internet and network
state permissions; debug/profile manifests retain Internet for Flutter tooling.
The final merged release manifest was checked after building.

## 20. Privacy

Receipt recognition and parsing run on the device. Application code does not
upload images, extracted text or transactions to a server, and does not integrate
cloud OCR, analytics tracking or an account service.

Captured/cropped images use temporary app storage during scanning. An explicit
Save copies the receipt into application documents storage and writes transaction
fields plus the image path into local SQLite. Deletion removes the transaction
and attempts to remove its image, with retry if file cleanup fails.

Debug OCR logs contain processing duration, not recognized receipt text. SQLite
and receipt files are not separately encrypted by this application. Device
security and Android backup/restore settings still apply; on-device processing
does not guarantee that operating-system backups are disabled.

## 21. Limitations

- Android is the configured application target; web, desktop and iOS application
  support have not been established.
- OCR accuracy depends on focus, lighting, print quality and receipt layout.
  Vietnamese receipts use the Latin recognizer; extraction can be incomplete.
- Merchant and amount selection use heuristics rather than semantic understanding.
  Users must review every prefill before saving.
- Crop mapping assumes a centered relationship between preview and still capture.
  Hardware-specific field-of-view differences need physical-device validation.
- Stored amounts use SQLite REAL; analytics rounds values to integer cents.
- OCR latency varies by device and image; no sub-100 ms guarantee is made.
- Automated tests do not establish native camera/ML Kit behavior, device performance
  or release installation readiness.
- Public APK/video links and physical-device screenshots remain TODO. Host-rendered
  fixture screenshots are documented separately from native-device evidence.

## 22. Future Improvements

The following are proposed or pending work, not implemented features:

- Back up the dedicated release key and verify the signed APK on Android.
- Validate permissions, torch/focus, rotation and background/resume on Android.
- Verify first-run OCR in airplane mode and crop alignment using real receipts.
- Expand receipt-format regression fixtures based on reviewed Vietnamese samples.
- Verify persistence after restart, file cleanup, large fonts, reduced motion and
  chart performance on physical devices.
- Capture actual screenshots and a demo video; publish a verified signed APK and
  add its real download URL.
- Evaluate explicit backup controls and stronger local data protection if required.

Keep future work on-device and retain explicit review before saving.

## 23. Contributors

**TODO:** add confirmed contributor names, roles and profile links.

Contributor identities have not been supplied; no names or affiliations are
assumed.
