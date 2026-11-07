// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_wasabi/otel_wasabi.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_wasabi-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('PutObject records bucket + region + bytes', () async {
    await tracedWasabi<String>(
      operation: 'PutObject',
      region: 'us-east-1',
      invoke: () async => const WasabiCallResult(
        value: 'ok',
        result: WasabiResult(
          bucket: 'backups',
          region: 'us-east-1',
          bytes: 10485760,
          storageClass: 'STANDARD',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('wasabi PutObject')!);
    expect(a['wasabi.bucket'], 'backups');
    expect(a['wasabi.region'], 'us-east-1');
    expect(a['wasabi.bytes'], 10485760);
  });

  test('DeleteObject within 90 days flags minimum-storage violation', () async {
    await tracedWasabi<String>(
      operation: 'DeleteObject',
      invoke: () async => const WasabiCallResult(
        value: 'ok',
        result: WasabiResult(minimumStoragePolicyViolated: true),
      ),
    );
    final a = attrsOf(spans.findSpanByName('wasabi DeleteObject')!);
    expect(a['wasabi.min_storage_violation'], true);
  });

  test('compliance retention recorded', () async {
    await tracedWasabi<String>(
      operation: 'PutObjectRetention',
      invoke: () async => const WasabiCallResult(
        value: 'ok',
        result: WasabiResult(compliance: 'COMPLIANCE'),
      ),
    );
    final a = attrsOf(spans.findSpanByName('wasabi PutObjectRetention')!);
    expect(a['wasabi.compliance'], 'COMPLIANCE');
  });

  test('suppression skips spans', () async {
    await runWithoutWasabiInstrumentationAsync(() async {
      await tracedWasabi<String>(
        operation: 'ListBuckets',
        invoke: () async => const WasabiCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('wasabi '), isEmpty);
  });
}
