# Đối chiếu ReceiptWise và repository tham khảo

Ngày đối chiếu: 2026-10-03. Repository tham khảo:
[Vcoch27/receipt-ocr-expense-tracker](https://github.com/Vcoch27/receipt-ocr-expense-tracker),
commit `c473bc5070e3855c858a3f05e695451b7d0af6a8`.
Đã đọc README, PRD và mã nguồn liên quan; không chạy ứng dụng tham khảo.

Người dùng chọn **hoàn thiện luồng hóa đơn và các thiếu sót thực tế, giữ kiến trúc
hiện tại**. Phạm vi này không bao gồm việc chuyển sang Riverpod/image_picker,
ảnh chuyển khoản hoặc giao diện Việt/Anh.

## Kết luận

Hai ứng dụng có cùng luồng chính: lấy ảnh → ML Kit trên thiết bị → parser →
review bắt buộc → SQLite → lịch sử/chỉnh sửa/xóa → biểu đồ CustomPainter.
Không phải mọi yêu cầu và phần mở rộng đều giống nhau. PRD của repository kia
đặt thêm yêu cầu thư viện và sản phẩm bàn giao phục vụ môn học; những yêu cầu đó
khác với các lựa chọn ban đầu của ReceiptWise. Chưa có slide/giao đề gốc để xác
nhận PRD của họ có phải tiêu chí chấm điểm áp dụng cho người dùng hay không.

## Bảng đối chiếu

| Hạng mục | Repository tham khảo | ReceiptWise sau cập nhật |
| --- | --- | --- |
| Chụp hóa đơn | Camera qua image_picker | CameraPreview trực tiếp, torch, focus, khung và crop qua camera chính thức |
| OCR trên máy | ML Kit Latin | ML Kit Latin, không cloud/API key |
| Parser merchant/amount/date | Regex, nhãn không dấu, tổng dòng kế tiếp, DMY/YMD | Đã bổ sung nhãn không dấu, tổng dòng kế tiếp, DMY/YMD và ưu tiên tổng cuối |
| Review trước lưu | Bắt buộc | Bắt buộc, mọi trường sửa được, raw OCR xem trong bộ nhớ |
| OCR lỗi | Nhập tay trong review | Nhập tay trong review |
| Nhập chi tiêu tay độc lập | Có | Chưa có; khác với fallback nhập tay của hóa đơn |
| CRUD SQLite, lưu ảnh riêng | Có | Có; path trong DB, ảnh documents, ISO-8601 |
| Lịch sử/detail/edit/delete | Có | Có, xác nhận xóa, xử lý ảnh thiếu và retry cleanup |
| Home tổng quan | Có tổng và gần đây | Đã bổ sung tổng chi tiêu, 7 ngày, số giao dịch, 3 giao dịch gần nhất |
| Biểu đồ CustomPainter | Donut, tuần hiện tại | Donut, 7 ngày gần nhất theo yêu cầu ReceiptWise |
| Material 3 / dark / responsive | Có, lựa chọn appearance | Có, tự theo hệ thống, form cuộn và touch target |
| State management | Riverpod 2 theo PRD môn học | Widget state + service/repository, refresh khi dữ liệu đổi; giữ kiến trúc đã chọn |
| Ảnh ngân hàng/ví, duplicate warning | Phần mở rộng riêng | Không trong phạm vi lần này |
| Gallery import / Việt-Anh / iOS host | Có mã nguồn tương ứng | Không trong phạm vi Android hóa đơn ban đầu |
| Tests | Unit/widget + integration boundary giả | Unit/widget, SQLite thật trong host tests; chưa có test Android vật lý |
| APK | README mô tả ký riêng và thử máy Samsung | Build được; đang debug signing, chưa kiểm thử native trên máy |
| Video/screenshot/PDF | Có ảnh/PDF; video chưa bundled | README TODO ảnh/video; chưa có báo cáo PDF |

Các thông tin kiểm thử thiết bị của repository tham khảo là mô tả của tác giả
trong README, không phải kết quả kiểm chứng độc lập của lần đối chiếu này.

Nguồn: [README tham khảo](https://github.com/Vcoch27/receipt-ocr-expense-tracker/blob/c473bc5070e3855c858a3f05e695451b7d0af6a8/README.md),
[PRD tham khảo](https://github.com/Vcoch27/receipt-ocr-expense-tracker/blob/c473bc5070e3855c858a3f05e695451b7d0af6a8/MiniProject3_Receipt_OCR_Expense_Tracker_PRD.md).

## Cải tiến đã triển khai

- Parser nhận các nhãn có/không dấu: TỔNG CỘNG, TỔNG TIỀN, THÀNH TIỀN,
  THANH TOÁN, CỘNG TIỀN, Grand total, Amount due, Total.
- Nhãn tổng tách khỏi số tiền có thể lấy dòng kế tiếp nếu đó là số tiền đứng riêng.
  Không lấy dòng ngày, số điện thoại có nhãn hoặc mô tả sản phẩm để suy tổng.
- Tổng cuối có ưu tiên hơn thành tiền từng dòng; tiền thừa, tiền khách đưa,
  subtotal/tạm tính không thay thế tổng chi tiêu trong currency fallback.
- Ngày dạng yyyy-MM-dd được kiểm tra chặt và hiển thị theo DD/MM/YYYY; nhãn
  ngày giao dịch được ưu tiên hơn ngày không nhãn. Giá trị chưa biết vẫn null.
- Home tải dữ liệu SQLite qua HomeSummaryService, dùng lại quy tắc tổng hợp
  AnalyticsService, gồm loading/error/retry/empty và refresh sau save/edit/delete.
- Tổng dùng BigInt cents như Analytics để tránh tràn số; giá trị lớn có tooltip
  đầy đủ, recent transactions dùng ảnh fallback khi thiếu.
- Giữ nguyên schema, OCR, camera, navigator và chart painters. Không thêm package.

## File tạo mới

- `lib/models/home_summary.dart`
- `lib/services/home_summary_service.dart`
- `test/home_screen_test.dart`
- `COMPARISON_REVIEW.md`

## File sửa đổi

- `lib/services/receipt_parser.dart`
- `lib/ui/screens/home_screen.dart`
- `lib/app/app_shell.dart`
- `test/services/receipt_parser_test.dart`
- `pubspec.yaml` (phiên bản 1.0.1+2)
- `README.md`
- `ARCHITECTURE.md`

## Kiểm chứng và TODO

Đã chạy `dart format .`, `flutter pub get`, `flutter analyze`, `flutter test` và
`flutter build apk --release`: analyzer không có issue, **86 tests passed** và
APK **1.0.1+2** build thành công. Kích thước/checksum APK mới được ghi trong README.
Regression mới kiểm tra tổng tách dòng/ưu tiên tổng/ngày ISO và dashboard:
7 ngày, recent limit, retry/empty, revision refresh, disposal và màn hình nhỏ.

Vẫn cần máy Android để kiểm chứng camera/crop/OCR offline, persistence sau khởi
động lại và APK mới. Cần production signing, application ID, ảnh/video thật.
Nếu đề chấm bắt buộc Riverpod/image_picker/PDF, cần đối chiếu đề gốc và xử lý
trong phạm vi riêng; bản cập nhật này không tuyên bố đạt toàn bộ PRD môn học kia.
