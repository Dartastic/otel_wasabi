// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_wasabi/otel_wasabi.dart';

/// Traces Wasabi (S3-compatible) calls with OpenTelemetry.
///
/// `otel_wasabi` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Wasabi (S3-compatible) call in
/// [tracedWasabi]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'wasabi-example');

  // Wraps a Wasabi (S3-compatible) call in a CLIENT span.
  final wasabiId = await tracedWasabi<String>(
    operation: 'create',
    region: 'us-east-1',
    invoke: () async {
      // Make the Wasabi (S3-compatible) call here, then report what it returned.
      const id = 'wasabi_8f3a2c';
      return const WasabiCallResult(
          value: id,
          result: WasabiResult(
              bucket: 'invoices',
              region: 'us-east-1',
              bytes: 512,
              parts: 1,
              storageClass: 'STANDARD',
              minimumStoragePolicyViolated: true,
              compliance: 'GOVERNANCE',
              versionId: 'version_8f3a2c',
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedWasabi create returned $wasabiId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutWasabiInstrumentationAsync.
  await runWithoutWasabiInstrumentationAsync(
    () => tracedWasabi<String>(
      operation: 'create',
      region: 'us-east-1',
      invoke: () async {
        const id = 'wasabi_8f3a2c';
        return const WasabiCallResult(
            value: id,
            result: WasabiResult(
                bucket: 'invoices',
                region: 'us-east-1',
                bytes: 512,
                parts: 1,
                storageClass: 'STANDARD',
                minimumStoragePolicyViolated: true,
                compliance: 'GOVERNANCE',
                versionId: 'version_8f3a2c',
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
