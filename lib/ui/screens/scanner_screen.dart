import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

import '../../models/receipt_capture_geometry.dart';
import '../../models/receipt_review_draft.dart';
import '../../models/transaction_model.dart';
import '../../models/ocr_result.dart';
import '../../services/ocr_service.dart';
import '../../services/receipt_camera_service.dart';
import '../../services/receipt_image_service.dart';
import '../../services/receipt_image_processor.dart';
import '../../services/receipt_save_service.dart';
import '../widgets/receipt_camera_preview.dart';
import '../widgets/receipt_frame_overlay.dart';
import '../widgets/scanner_controls.dart';
import '../widgets/placeholder_content.dart';
import 'review_receipt_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({this.saveService, super.key});
  final ReceiptSaveService? saveService;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final _camera = ReceiptCameraService();
  final _ocr = OcrService();
  bool _recognizing = false;
  bool _previewing = false;
  bool _captureFlow = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  ReceiptCaptureGeometry? _captureGeometry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    unawaited(_camera.setActive(_lifecycle == AppLifecycleState.resumed));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    unawaited(
      _camera.setActive(state == AppLifecycleState.resumed && !_previewing),
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _capture() async {
    final geometry = _captureGeometry;
    if (_captureFlow ||
        !_camera.ready ||
        geometry == null ||
        geometry.frame.isEmpty) {
      return;
    }
    setState(() => _captureFlow = true);
    String? temporaryPath;
    String? croppedPath;
    bool accepted = false;
    try {
      final photo = await _camera.capture(orientation: geometry.orientation);
      if (photo == null) return;
      temporaryPath = photo.path;
      if (!mounted) return;
      _previewing = true;
      await _camera.setActive(false);
      if (!mounted) return;
      croppedPath = await ReceiptImageProcessor().cropReceipt(
        sourcePath: photo.path,
        geometry: geometry,
      );
      if (!mounted) return;
      setState(() => _recognizing = true);
      OcrResult? result;
      bool ocrFailed = false;
      try {
        result = await _ocr.recognizeText(croppedPath);
      } catch (_) {
        ocrFailed = true;
      }
      if (!mounted) return;
      setState(() => _recognizing = false);
      final selected = await Navigator.of(context).push<TransactionModel>(
        MaterialPageRoute(
          builder: (_) => ReviewReceiptScreen(
            saveService: widget.saveService,
            draft: ReceiptReviewDraft(
              imagePath: croppedPath!,
              ocrResult: result,
              ocrFailed: ocrFailed,
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (selected != null) {
        accepted = true;
        Navigator.of(context).pop(selected);
      }
    } catch (_) {
      _message('Could not prepare the receipt crop. Please retake it.');
    } finally {
      if (temporaryPath != null) {
        try {
          await ReceiptImageService().discardTemporaryPhoto(temporaryPath);
        } catch (error) {
          debugPrint('Temporary receipt cleanup failed: $error');
        }
      }
      if (croppedPath != null) {
        try {
          await ReceiptImageService().discardTemporaryPhoto(croppedPath);
        } catch (error) {
          debugPrint('Temporary receipt crop cleanup failed: $error');
        }
      }
      _previewing = false;
      if (mounted) {
        setState(() {
          _captureFlow = false;
          _recognizing = false;
        });
        if (!accepted) {
          await _camera.setActive(_lifecycle == AppLifecycleState.resumed);
        }
      }
    }
  }

  Future<void> _toggleFlash() async {
    try {
      await _camera.toggleFlash();
    } catch (_) {
      _message('Torch is unavailable on this camera.');
    }
  }

  Future<void> _focus(Offset point) async {
    if (_captureFlow) return;
    try {
      if (!await _camera.focus(point)) {
        _message('Tap to focus is unavailable on this camera.');
      }
    } catch (_) {
      _message('Could not focus here. Try tapping again.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.dispose();
    unawaited(
      _ocr.dispose().catchError((Object error) {
        if (kDebugMode) {
          debugPrint('OCR recognizer cleanup failed: $error');
        }
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _camera,
      builder: (context, child) {
        return PopScope(
          canPop: !_captureFlow,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: LayoutBuilder(
              builder: (context, constraints) {
                final frame = receiptFrameForViewport(
                  constraints.biggest,
                  MediaQuery.paddingOf(context),
                  controlsHeight: ScannerControls.bottomHeight(
                    context,
                    constraints.maxWidth,
                  ),
                );
                if (_camera.ready) {
                  final controller = _camera.controller!;
                  _captureGeometry = ReceiptCaptureGeometry(
                    viewport: constraints.biggest,
                    frame: frame,
                    previewSize: orientedReceiptPreviewSize(controller.value),
                    orientation: receiptPreviewOrientation(controller.value),
                    sensorOrientation: controller.description.sensorOrientation,
                    mirroredPreview:
                        controller.description.lensDirection ==
                        CameraLensDirection.front,
                  );
                } else {
                  _captureGeometry = null;
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_camera.ready) ...[
                      ReceiptCameraPreview(
                        controller: _camera.controller!,
                        onFocus: _focus,
                      ),
                      ReceiptFrameOverlay(frame: frame),
                      if (frame.isEmpty)
                        const Center(
                          child: ColoredBox(
                            color: Colors.black87,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Rotate your phone to frame the receipt.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ] else if (_camera.error != null)
                      ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 72),
                            child: PlaceholderContent(
                              icon: Icons.camera_alt_outlined,
                              title: 'Camera unavailable',
                              description: _camera.error!,
                              action: FilledButton(
                                onPressed: _captureFlow ? null : _camera.retry,
                                child: const Text('Retry'),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _captureFlow
                                  ? (_recognizing
                                        ? 'Reading receipt…'
                                        : 'Cropping receipt…')
                                  : 'Starting camera…',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ScannerControls(
                      ready: _camera.ready,
                      captureEnabled: !frame.isEmpty,
                      busy: _captureFlow,
                      torchOn: _camera.torchOn,
                      changingFlash: _camera.changingFlash,
                      onClose: () => Navigator.of(context).pop(),
                      onFlash: _toggleFlash,
                      onCapture: _capture,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
