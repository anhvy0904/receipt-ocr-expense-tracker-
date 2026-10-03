import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receiptwise/services/ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('google_mlkit_text_recognizer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late OcrService service;
  late List<MethodCall> calls;

  final line = <String, Object?>{
    'text': 'TỔNG CỘNG: 150.000',
    'rect': {'left': 0.0, 'top': 0.0, 'right': 100.0, 'bottom': 20.0},
    'recognizedLanguages': <String>[],
    'points': <Object>[],
    'elements': <Object>[],
  };
  final response = {
    'text': 'TỔNG CỘNG: 150.000',
    'blocks': [
      {
        ...line,
        'lines': [line],
      },
    ],
  };

  setUp(() {
    service = OcrService();
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'vision#startTextRecognizer' ? response : null;
    });
  });
  tearDown(() async {
    await service.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'uses Latin file input and returns raw text, blocks and flattened lines',
    () async {
      final result = await service.recognizeText('/temporary/receipt.jpg');
      expect(result.fullText, 'TỔNG CỘNG: 150.000');
      expect(result.blocks.single.text, result.fullText);
      expect(result.lines.single.text, result.fullText);
      expect(calls.single.arguments['script'], 0);
      expect(
        calls.single.arguments['imageData']['path'],
        '/temporary/receipt.jpg',
      );
      expect(() => result.lines.clear(), throwsUnsupportedError);
    },
  );

  test('empty recognition is a valid result', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return call.method == 'vision#startTextRecognizer'
          ? {'text': '', 'blocks': []}
          : null;
    });
    final result = await service.recognizeText('/temporary/blank.jpg');
    expect(result.fullText, isEmpty);
    expect(result.blocks, isEmpty);
    expect(result.lines, isEmpty);
  });

  test('failure propagates, next recognition and cleanup still work', () async {
    int attempts = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'vision#startTextRecognizer') {
        if (attempts++ == 0) {
          throw PlatformException(code: 'recognition_failed');
        }
        return response;
      }
      return null;
    });
    await expectLater(
      service.recognizeText('/bad.jpg'),
      throwsA(isA<PlatformException>()),
    );
    expect((await service.recognizeText('/good.jpg')).lines, hasLength(1));
    await service.dispose();
    await service.dispose();
    expect(
      calls.where((call) => call.method == 'vision#closeTextRecognizer'),
      hasLength(1),
    );
    await expectLater(service.recognizeText('/closed.jpg'), throwsStateError);
  });

  test('disposal waits for pending recognition', () async {
    final started = Completer<void>();
    final finish = Completer<void>();
    bool closed = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'vision#startTextRecognizer') {
        started.complete();
        await finish.future;
        return response;
      }
      closed = true;
      return null;
    });
    final recognition = service.recognizeText('/receipt.jpg');
    await started.future;
    final disposal = service.dispose();
    expect(closed, isFalse);
    finish.complete();
    await recognition;
    await disposal;
    expect(closed, isTrue);
  });
}
