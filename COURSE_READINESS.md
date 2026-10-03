# ReceiptWise — nâng cấp lõi môn học

Ngày kiểm chứng: **2026-10-03**, phiên bản **1.1.0+3**.
Đối chiếu PRD tại commit `c473bc5070e3855c858a3f05e695451b7d0af6a8` của
[repository tham khảo](https://github.com/Vcoch27/receipt-ocr-expense-tracker).
Chưa nhận slide/giao đề gốc; bảng này phản ánh phần lõi PRD, không xác nhận điểm
chấm hoặc toàn bộ phần mở rộng của tác giả tham khảo.

## Đáp ứng chức năng cốt lõi

| Yêu cầu | Triển khai và bằng chứng |
| --- | --- |
| FR-01: Receipt capture | Official image_picker camera/gallery; giữ live scanner, torch/focus/frame/crop. Phục hồi lost picker data Android. |
| FR-02: On-device OCR | ML Kit Latin bundled; không API key, upload hoặc network trong release manifest. Native OCR cần kiểm chứng trên máy. |
| FR-03: Receipt parser | Regex/heuristic merchant, total, DMY/YMD; regression tests với định dạng Việt Nam. |
| FR-04: Review | Mọi kết quả đều qua form chỉnh sửa; OCR lỗi/null vẫn review; không tự lưu. |
| FR-05: Validation | Merchant bắt buộc, amount hữu hạn >0, date hợp lệ, sáu category; guard Save trùng. |
| FR-06: SQLite CRUD | sqflite, ISO timestamps, image path riêng; copy trước insert, rollback và cleanup an toàn. |
| FR-07: History | Newest date first, thumbnail/VND/detail/edit/confirm delete, missing-image fallback. |
| FR-08: State | Provider + ChangeNotifier; snapshot SQLite chia sẻ Home/History/Analytics, refresh sau commit. |
| FR-09: Visualization | Donut và latest-seven-day bars dùng CustomPainter, animation, aggregate ngoài paint. |
| FR-10: Material 3 | Light/Dark/System, layout cuộn, touch targets và kiểm tra keyboard/text scale. |

Provider được chọn vì phần lõi PRD cho phép Provider hoặc Riverpod; không chuyển
repository/services đang hoạt động sang kiến trúc khác. image_picker bổ sung một
đường nhập đúng yêu cầu bên cạnh camera hiện có. Ảnh picker giữ toàn ảnh, chuẩn hóa
EXIF ở độ phân giải gốc; chỉ live scanner dùng khung crop. Manual entry dùng chung
review/save; schema version 1 đã cho phép receipt_image_path null nên không đổi DB.
Appearance hiện lưu theo phiên, khởi động lại theo System.

Không triển khai parser ngân hàng/ví, metadata chuyển khoản, duplicate transaction
warning, Việt/Anh, iOS, cloud hoặc chart package trong đợt này.

## Bàn giao

- GitHub: code, tests, tài liệu, ảnh UI fixture và báo cáo PDF.
- APK release ký bằng key riêng, application ID `com.anhvy.receiptwise`; checksum,
  kích thước và đường dẫn ghi trong README. Không commit APK hoặc key/password.
- [PDF 4 trang](output/pdf/receiptwise_technical_report.pdf), source tái tạo tại
  `docs/build_technical_report.py`; nội dung kiến trúc/OCR/parser/SQL/charts/evidence.
- `docs/screenshots/*.png`: ảnh Flutter render thật từ fixture tổng hợp, không
  được coi là ảnh OCR hoặc camera trên thiết bị vật lý.
- `docs/DEMO_CHECKLIST.md`: kịch bản video và checklist kiểm chứng Android.
- `docs/RELEASE_SIGNING.md`: cấu hình và backup key; không có debug signing fallback.

Application ID mới cài riêng với bản `com.example.receiptwise` trước đó, không tự
migrate giao dịch cũ. Phải backup an toàn `android/receiptwise-release.jks` và
`android/key.properties` ngoài checkout; hai file này bị Git ignore.

## Kiểm chứng

Đã chạy:

```text
dart format .
flutter pub get
flutter analyze
flutter test
flutter build apk --release
apksigner verify --verbose --print-certs <apk>
```

Flutter dùng `--no-version-check`, SDK 3.47.5 / Dart 3.13.4. Analyzer **no issues**,
**96 tests passed**. Test mới kiểm tra Provider với SQLite thật, load stale/dispose,
normalize/import/cancel/OCR failure, nhập tay không ảnh, duplicate picker và luồng
review → save → history → edit → charts → delete. Native capture/OCR được fixture
ở boundary; host tests không chứng minh độ chính xác camera/ML Kit Android.

`integration_test/receipt_flow_test.dart` dùng sqflite native và fixture capture/OCR;
chưa chạy vì không có Android kết nối. PDF đã kiểm tra đủ 4 trang sau render.
Manifest release loại bỏ quyền mạng, audio và shared storage kế thừa; camera
optional cho phép sử dụng nhập tay/gallery khi máy không có camera.

## File tạo mới

- `lib/state/transaction_state.dart`
- `lib/state/appearance_state.dart`
- `lib/services/receipt_import_service.dart`
- `lib/ui/screens/receipt_import_screen.dart`
- `android/app/src/release/AndroidManifest.xml`
- `test/state/transaction_state_test.dart`
- `test/services/receipt_import_service_test.dart`
- `test/receipt_flow_test.dart`
- `test/upgrade_ui_test.dart`
- `test/support/receipt_flow_scenario.dart`
- `integration_test/receipt_flow_test.dart`
- `docs/RELEASE_SIGNING.md`
- `docs/DEMO_CHECKLIST.md`
- `docs/build_technical_report.py`
- `docs/screenshots/home-light.png`
- `docs/screenshots/home-dark.png`
- `docs/screenshots/review.png`
- `docs/screenshots/history.png`
- `docs/screenshots/analytics.png`
- `docs/screenshots/weekly-bars.png`
- `output/pdf/receiptwise_technical_report.pdf`
- `COURSE_READINESS.md`

## File sửa đổi

- `.gitignore`
- `README.md`
- `ARCHITECTURE.md`
- `COMPARISON_REVIEW.md`
- `PRODUCTION_READINESS.md`
- `pubspec.yaml`
- `pubspec.lock`
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `lib/app/receiptwise_app.dart`
- `lib/app/app_shell.dart`
- `lib/models/receipt_review_draft.dart`
- `lib/services/receipt_save_service.dart`
- `lib/services/transaction_management_service.dart`
- `lib/ui/screens/home_screen.dart`
- `lib/ui/screens/transactions_screen.dart`
- `lib/ui/screens/analytics_screen.dart`
- `lib/ui/screens/review_receipt_screen.dart`
- `lib/ui/screens/scanner_screen.dart` (truyền shared save service; giữ camera/OCR)
- `test/review_receipt_screen_test.dart`

## TODO trước nộp

1. Backup private signing files an toàn.
2. Cài signed APK trên Android; thử permission deny/grant, camera/torch/focus,
   rotation/background/resume, crop alignment và ảnh gallery/system camera.
3. Thử OCR lần đầu ở airplane mode, receipt thật, review không tự save, edit/delete,
   restart persistence, small screen/keyboard và charts.
4. Chạy integration test trên Android, bổ sung ảnh thiết bị và video demo thật.
5. Publish APK đã kiểm chứng rồi cập nhật URL APK/video và contributors trong README.

Không có APK/video URL được tạo giả; chưa tuyên bố hoàn thành kiểm thử vật lý.
