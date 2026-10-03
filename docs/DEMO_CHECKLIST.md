# Android demonstration checklist

Status: **TODO - no physical Android device was connected during the upgrade.**
Record actual device results and a real video URL; do not present fixture tests
or host screenshots as native-device evidence.

## Setup

- Back up release signing files securely; build the release APK.
- Connect Android with USB debugging; run `adb devices -l`.
- Install the APK with `adb install -r build/app/outputs/flutter-apk/app-release.apk`.
- Run `flutter test integration_test/receipt_flow_test.dart -d DEVICE_ID`.
  This test uses real Android SQLite and mocked image/OCR boundaries.
- Prepare a clear Vietnamese paper receipt; avoid publishing private receipt data.

## Suggested 2-3 minute video

1. Show Home and switch Light / Dark / System appearance.
2. Scan a physical receipt. Demonstrate frame, torch and focus when supported.
3. Show OCR processing and editable review; correct one value before Save.
4. Show the saved item in History, image/detail and an edit.
5. Show animated category donut and latest-seven-day bars.
6. Choose a gallery receipt with image_picker, review and Save.
7. Enter a manual expense; demonstrate invalid amount/merchant validation.
8. Confirm deletion and show updated summary/history/charts.
9. Force-stop/restart; show remaining transactions still exist.

## Reliability / privacy checks

- First launch and OCR in airplane mode, with no runtime OCR download.
- Camera denial, permanent denial/settings retry, absent camera and cancellation.
- Rotate and background/resume during capture; check crop alignment and OCR quality.
- Gallery cancellation, unsupported/corrupt image, activity destruction recovery.
- OCR failure still allows manual review; no automatic SQLite insertion.
- Double-tap capture/save/retry; keyboard and enlarged-text layouts on a small screen.
- Missing receipt image and retry after file-deletion failure.
- No image/raw OCR text or signing passwords in logs or the published demo.

## Evidence to add

- Device model / Android version / test date: **TODO**.
- Native camera + offline OCR results: **TODO**.
- Real device screenshots: **TODO**.
- Demo video URL: **TODO**.
- Public release APK URL and verified signature/checksum: **TODO**.
