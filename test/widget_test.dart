import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newsroom/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.kncc.newsroom/widget');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    // Set up method channel mock
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      if (methodCall.method == 'updateWidget') {
        return null;
      }
      throw PlatformException(
        code: 'notImplemented',
        message: 'Method ${methodCall.method} not implemented',
      );
    });
  });

  tearDown(() {
    // Clear mock handler and log after each test
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    log.clear();
  });

  test('updateWidget method channel test', () async {
    // Invoke the method channel
    await channel.invokeMethod('updateWidget');

    // Verify the method call was made with correct name
    expect(log, hasLength(1));
    expect(log.first.method, 'updateWidget');
  });

  test('non-existent method channel test', () async {
    // Test calling a method that doesn't exist
    expect(
      () => channel.invokeMethod('nonExistentMethod'),
      throwsA(isA<PlatformException>().having(
        (e) => e.code,
        'code',
        'notImplemented',
      )),
    );
  });
} 