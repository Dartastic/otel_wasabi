// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_wasabi_suppression.dart';

const _tracerName = 'dartastic_otel_libs_wasabi';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class WasabiResult {
  const WasabiResult({
    this.bucket,
    this.region,
    this.bytes,
    this.parts,
    this.storageClass,
    this.minimumStoragePolicyViolated,
    this.compliance,
    this.versionId,
    this.requestId,
    this.statusCode,
  });

  /// Bucket name.
  final String? bucket;

  /// `us-east-1` / `us-east-2` / `us-central-1` / `us-west-1` /
  /// `eu-central-1` / `eu-west-1` / `ap-northeast-1` / etc.
  final String? region;

  /// Object bytes.
  final int? bytes;

  /// Multipart parts uploaded.
  final int? parts;

  /// `STANDARD` (Wasabi only has one, but record for S3 SDK compat).
  final String? storageClass;

  /// True when the request will trigger Wasabi's 90-day minimum
  /// storage penalty (deletes within 90 days are billed for the
  /// remainder — common cost surprise).
  final bool? minimumStoragePolicyViolated;

  /// Compliance retention mode: `GOVERNANCE` / `COMPLIANCE` / `null`.
  final String? compliance;

  /// `versionId` for versioned buckets.
  final String? versionId;

  /// `x-amz-request-id`.
  final String? requestId;

  final int? statusCode;
}

class WasabiCallResult<T> {
  const WasabiCallResult({required this.value, this.result});
  final T value;
  final WasabiResult? result;
}

/// Wraps a Wasabi (S3-compatible) call in a CLIENT span. [operation]
/// is one of `ListBuckets`, `CreateBucket`, `DeleteBucket`,
/// `PutObject`, `GetObject`, `DeleteObject`, `HeadObject`,
/// `CopyObject`, `ListObjectsV2`, `CreateMultipartUpload`,
/// `UploadPart`, `CompleteMultipartUpload`, `AbortMultipartUpload`,
/// `PutBucketLifecycleConfiguration`, `PutObjectRetention`,
/// `PutObjectLegalHold`, `GeneratePresignedUrl`.
Future<T> tracedWasabi<T>({
  required String operation,
  required Future<WasabiCallResult<T>> Function() invoke,
  String? region,
}) async {
  if (wasabiInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'wasabi',
    'rpc.method': operation,
    'wasabi.operation': operation,
  };
  if (region != null) m['wasabi.region'] = region;

  final span = _tracer().startSpan(
    'wasabi $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.bucket != null) {
        extras.add(OTel.attributeString(
          'wasabi.bucket',
          r.result!.bucket!,
        ));
      }
      if (r.result!.region != null) {
        extras.add(OTel.attributeString(
          'wasabi.region',
          r.result!.region!,
        ));
      }
      if (r.result!.bytes != null) {
        extras.add(OTel.attributeInt(
          'wasabi.bytes',
          r.result!.bytes!,
        ));
      }
      if (r.result!.parts != null) {
        extras.add(OTel.attributeInt(
          'wasabi.parts',
          r.result!.parts!,
        ));
      }
      if (r.result!.storageClass != null) {
        extras.add(OTel.attributeString(
          'wasabi.storage_class',
          r.result!.storageClass!,
        ));
      }
      if (r.result!.minimumStoragePolicyViolated != null) {
        extras.add(OTel.attributeBool(
          'wasabi.min_storage_violation',
          r.result!.minimumStoragePolicyViolated!,
        ));
      }
      if (r.result!.compliance != null) {
        extras.add(OTel.attributeString(
          'wasabi.compliance',
          r.result!.compliance!,
        ));
      }
      if (r.result!.versionId != null) {
        extras.add(OTel.attributeString(
          'wasabi.version.id',
          r.result!.versionId!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'wasabi.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Wasabi HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
