import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Serializes camera operations so lifecycle disposal cannot race capture/init.
class ReceiptCameraService extends ChangeNotifier {
  ReceiptCameraService({
    Future<List<CameraDescription>> Function()? cameraLoader,
    CameraController Function(CameraDescription)? controllerFactory,
  }) : _cameraLoader = cameraLoader ?? availableCameras,
       _controllerFactory = controllerFactory ?? _createController;

  final Future<List<CameraDescription>> Function() _cameraLoader;
  final CameraController Function(CameraDescription) _controllerFactory;

  static CameraController _createController(CameraDescription camera) =>
      CameraController(camera, ResolutionPreset.max, enableAudio: false);
  CameraController? _controller;
  Future<void> _pending = Future.value();
  bool _active = false;
  bool _closed = false;
  bool _capturing = false;
  bool _changingFlash = false;
  bool _initializing = false;
  bool _retrying = false;
  String? _error;

  CameraController? get controller => _controller;
  bool get capturing => _capturing;
  bool get initializing => _initializing;
  bool get changingFlash => _changingFlash;
  String? get error => _error;
  bool get ready =>
      !_closed &&
      _active &&
      (_controller?.value.isInitialized ?? false) &&
      !(_controller?.value.hasError ?? true);
  bool get torchOn => _controller?.value.flashMode == FlashMode.torch;

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> setActive(bool active) {
    _active = active && !_closed;
    _notify();
    return _serialize(() async {
      if (!_active || _closed) {
        await _release();
      } else if (_error == null) {
        await _initialize();
      }
    });
  }

  Future<void> retry() async {
    if (_closed || _retrying || _initializing) return;
    _retrying = true;
    try {
      await _serialize(() async {
        if (!_active || _closed) return;
        _error = null;
        await _release();
        await _initialize();
      });
    } finally {
      _retrying = false;
    }
  }

  Future<void> _initialize() async {
    if (_controller?.value.isInitialized ?? false) return;
    _initializing = true;
    _notify();
    try {
      final cameras = await _cameraLoader();
      if (!_active || _closed) return;
      if (cameras.isEmpty) {
        _error = 'No camera is available on this device.';
        return;
      }
      final back = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      final camera = back.isEmpty ? cameras.first : back.first;
      final next = _controllerFactory(camera);
      _controller = next;
      // initialize requests CAMERA permission through the official plugin.
      await next.initialize();
      if (!_active || _closed) {
        await _release();
        return;
      }
      next.addListener(_onCameraChanged);
      try {
        await next.setFlashMode(FlashMode.off);
      } on CameraException catch (error) {
        debugPrint('Camera flash off unavailable: ${error.code}');
      }
    } on CameraException catch (error) {
      _error = switch (error.code) {
        'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
          'Camera permission was denied. Allow camera access in your phone settings, then tap Retry.',
        'CameraAccessRestricted' =>
          'Camera access is restricted on this device. Check your phone settings.',
        _ =>
          'Could not start the camera. Close other camera apps and tap Retry.',
      };
      await _release();
    } catch (error) {
      debugPrint('Camera initialization failed: $error');
      _error = 'Camera unavailable. Try again on a supported Android device.';
      await _release();
    } finally {
      _initializing = false;
      _notify();
    }
  }

  void _onCameraChanged() {
    if (_controller?.value.hasError ?? false) {
      _error = 'The camera stopped working. Tap Retry to restart it.';
      unawaited(_serialize(_release));
    }
    _notify();
  }

  Future<XFile?> capture({DeviceOrientation? orientation}) async {
    if (!ready || _capturing || _changingFlash) return null;
    _capturing = true;
    _notify();
    try {
      return await _serialize(() async {
        if (!ready) return null;
        final camera = _controller!;
        await camera.lockCaptureOrientation(
          orientation ?? camera.value.deviceOrientation,
        );
        try {
          return await camera.takePicture();
        } finally {
          try {
            await camera.unlockCaptureOrientation();
          } catch (error) {
            if (kDebugMode) {
              debugPrint('Could not unlock capture orientation: $error');
            }
          }
        }
      });
    } finally {
      _capturing = false;
      _notify();
    }
  }

  Future<void> toggleFlash() async {
    if (!ready || _capturing || _changingFlash) return;
    _changingFlash = true;
    _notify();
    try {
      await _serialize(() async {
        if (!ready) return;
        await _controller!.setFlashMode(
          torchOn ? FlashMode.off : FlashMode.torch,
        );
      });
    } finally {
      _changingFlash = false;
      _notify();
    }
  }

  Future<bool> focus(Offset point) {
    return _serialize(() async {
      if (!ready || _capturing || !_controller!.value.focusPointSupported) {
        return false;
      }
      await _controller!.setFocusPoint(point);
      return true;
    });
  }

  Future<void> _release() async {
    final old = _controller;
    _controller = null;
    if (old == null) return;
    old.removeListener(_onCameraChanged);
    try {
      await old.dispose();
    } catch (error) {
      debugPrint('Camera disposal failed: $error');
      if (!_closed) {
        _error ??=
            'Could not release the camera. Close the scanner and try again.';
      }
    }
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _active = false;
    unawaited(_serialize(_release));
    super.dispose();
  }
}
