import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receiptwise/services/receipt_camera_service.dart';
import 'package:receiptwise/ui/widgets/receipt_camera_preview.dart';

const backCamera = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);
const frontCamera = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 90,
);

class FakeController extends CameraController {
  FakeController(CameraDescription description)
    : super(description, ResolutionPreset.high, enableAudio: false);
  final picture = Completer<XFile>();
  int captures = 0;
  bool disposed = false;
  Offset? focusPoint;
  CameraException? initializationError;
  DeviceOrientation? lockedOrientation;
  bool orientationUnlocked = false;
  Object? unlockError;
  Completer<void>? initializationGate;

  @override
  Future<void> lockCaptureOrientation([DeviceOrientation? orientation]) async {
    lockedOrientation = orientation;
  }

  @override
  Future<void> unlockCaptureOrientation() async {
    orientationUnlocked = true;
    if (unlockError != null) throw unlockError!;
  }

  @override
  Future<void> initialize() async {
    await initializationGate?.future;
    if (initializationError != null) throw initializationError!;
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(1920, 1080),
      focusPointSupported: true,
    );
  }

  @override
  Future<void> setFlashMode(FlashMode mode) async {
    value = value.copyWith(flashMode: mode);
  }

  @override
  Future<XFile> takePicture() {
    captures++;
    return picture.future;
  }

  @override
  Future<void> setFocusPoint(Offset? point) async {
    focusPoint = point;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await super.dispose();
  }
}

void main() {
  test(
    'unlock failure preserves a successful photo and disposal is idempotent',
    () async {
      final controller = FakeController(backCamera)
        ..unlockError = PlatformException(code: 'unlock_failed');
      final service = ReceiptCameraService(
        cameraLoader: () async => [backCamera],
        controllerFactory: (_) => controller,
      );
      await service.setActive(true);
      controller.picture.complete(XFile('/temporary/receipt.jpg'));
      expect((await service.capture())!.path, '/temporary/receipt.jpg');
      service.dispose();
      service.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(controller.disposed, isTrue);
    },
  );

  test(
    'duplicate retries initialize only one replacement controller',
    () async {
      final denied = FakeController(backCamera)
        ..initializationError = CameraException('CameraAccessDenied', 'Denied');
      final gate = Completer<void>();
      final replacement = FakeController(backCamera)..initializationGate = gate;
      var creations = 0;
      final service = ReceiptCameraService(
        cameraLoader: () async => [backCamera],
        controllerFactory: (_) => creations++ == 0 ? denied : replacement,
      );
      addTearDown(service.dispose);
      await service.setActive(true);
      final retry = service.retry();
      await service.retry();
      gate.complete();
      await retry;
      expect(creations, 2);
      expect(service.ready, isTrue);
    },
  );

  test('runtime camera errors release the damaged controller', () async {
    final controller = FakeController(backCamera);
    final service = ReceiptCameraService(
      cameraLoader: () async => [backCamera],
      controllerFactory: (_) => controller,
    );
    addTearDown(service.dispose);
    await service.setActive(true);
    controller.value = controller.value.copyWith(
      errorDescription: 'Native camera stopped',
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.disposed, isTrue);
    expect(service.error, contains('Tap Retry'));
  });
  test('prefers back camera and disposes it on suspension', () async {
    late FakeController controller;
    final service = ReceiptCameraService(
      cameraLoader: () async => [frontCamera, backCamera],
      controllerFactory: (camera) => controller = FakeController(camera),
    );
    addTearDown(service.dispose);
    await service.setActive(true);
    expect(controller.description, backCamera);
    expect(service.ready, isTrue);
    expect(service.torchOn, isFalse);
    await service.toggleFlash();
    expect(service.torchOn, isTrue);
    await service.toggleFlash();
    expect(service.torchOn, isFalse);
    await service.focus(const Offset(.25, .75));
    expect(controller.focusPoint, const Offset(.25, .75));
    await service.setActive(false);
    expect(controller.disposed, isTrue);
    expect(service.ready, isFalse);
    await service.setActive(true);
    expect(service.ready, isTrue);
    expect(controller.disposed, isFalse);
  });

  test('double capture takes one picture and disposal waits for it', () async {
    final controller = FakeController(backCamera);
    final service = ReceiptCameraService(
      cameraLoader: () async => [backCamera],
      controllerFactory: (_) => controller,
    );
    addTearDown(service.dispose);
    await service.setActive(true);
    final first = service.capture(
      orientation: DeviceOrientation.landscapeRight,
    );
    expect(await service.capture(), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(controller.captures, 1);
    final suspended = service.setActive(false);
    await Future<void>.delayed(Duration.zero);
    expect(controller.captures, 1);
    expect(controller.disposed, isFalse);
    controller.picture.complete(XFile('/temporary/receipt.jpg'));
    expect((await first)!.path, '/temporary/receipt.jpg');
    expect(controller.lockedOrientation, DeviceOrientation.landscapeRight);
    expect(controller.orientationUnlocked, isTrue);
    await suspended;
    expect(controller.disposed, isTrue);
  });

  test(
    'empty camera list and denied permission provide recoverable errors',
    () async {
      final unavailable = ReceiptCameraService(cameraLoader: () async => []);
      addTearDown(unavailable.dispose);
      await unavailable.setActive(true);
      expect(unavailable.error, contains('No camera'));
      final controller = FakeController(backCamera)
        ..initializationError = CameraException('CameraAccessDenied', 'Denied');
      final denied = ReceiptCameraService(
        cameraLoader: () async => [backCamera],
        controllerFactory: (_) => controller,
      );
      addTearDown(denied.dispose);
      await denied.setActive(true);
      expect(denied.error, contains('permission was denied'));
      expect(controller.disposed, isTrue);
    },
  );

  test('focus mapping accounts for preview cropping', () {
    expect(
      focusPointForPreview(const Offset(150, 300), const Size(300, 600), .75),
      const Offset(.5, .5),
    );
    final left = focusPointForPreview(
      const Offset(0, 300),
      const Size(300, 600),
      .75,
    );
    expect(left.dx, closeTo(1 / 6, .000001));
    expect(left.dy, .5);
  });
}
