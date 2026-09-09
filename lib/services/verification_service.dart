import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../utils/app_logger.dart';

/// Driving Licence + Vehicle RC verification — the single Flutter client.
///
/// Mirrors the backend contract in `src/verification/verification-contract.ts`
/// and the Web client in `wheelboard-fe/src/lib/verificationApi.ts`. The app
/// never contacts the KYC provider: it uploads the document (or the
/// registration number) to Wheelboard, and the backend owns the provider call,
/// the credentials and the verdict.
///
/// The app can never assert its own verified state — nothing here sends a
/// `verified` flag, and the backend would ignore one if it did.

/// The five business states the app understands. Provider-specific complexity
/// stops at the backend, so no widget branches on a provider response shape.
enum VerificationState {
  verified,
  notVerified,
  pending,
  rejected,
  temporarilyUnavailable;

  static VerificationState fromWire(String? value) {
    switch (value) {
      case 'verified':
        return VerificationState.verified;
      case 'pending':
        return VerificationState.pending;
      case 'rejected':
        return VerificationState.rejected;
      case 'temporarily_unavailable':
        return VerificationState.temporarilyUnavailable;
      default:
        return VerificationState.notVerified;
    }
  }
}

/// Extracted Driving Licence fields, normalized by the backend.
class DrivingLicenceData {
  final String? licenseNumber;
  final String? name;
  final String? dateOfBirth;

  /// Only returned by the Add Driver lookup, where the company uploaded the
  /// licence themselves and is filling in that driver's record. A
  /// professional's own KYC status deliberately does not echo their address.
  final String? address;

  final String? issueDate;
  final String? expiryDate;
  final String? issuingAuthority;
  final String? bloodGroup;
  final List<String>? vehicleClasses;

  const DrivingLicenceData({
    this.licenseNumber,
    this.name,
    this.dateOfBirth,
    this.address,
    this.issueDate,
    this.expiryDate,
    this.issuingAuthority,
    this.bloodGroup,
    this.vehicleClasses,
  });

  factory DrivingLicenceData.fromJson(Map<String, dynamic> json) {
    final classes = json['vehicleClasses'];
    return DrivingLicenceData(
      licenseNumber: json['licenseNumber'] as String?,
      name: json['name'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      address: json['address'] as String?,
      issueDate: json['issueDate'] as String?,
      expiryDate: json['expiryDate'] as String?,
      issuingAuthority: json['issuingAuthority'] as String?,
      bloodGroup: json['bloodGroup'] as String?,
      vehicleClasses: classes is List
          ? classes.map((e) => e.toString()).toList()
          : null,
    );
  }
}

/// Normalized Vehicle RC information, used to populate the vehicle form.
class VehicleRcData {
  final String? registrationNumber;
  final String? manufacturer;
  final String? model;
  final int? year;
  final String? fuelType;
  final String? color;
  final String? bodyType;
  final String? vehicleClass;
  final String? vehicleCategory;
  final String? seatingCapacity;
  final String? cubicCapacity;
  final String? grossVehicleWeight;
  final String? chassisNumber;
  final String? engineNumber;
  final String? rcStatus;
  final String? registrationAuthority;
  final String? registrationDate;
  final String? rcExpiryDate;
  final String? taxUpto;
  final String? insuranceCompany;
  final String? insuranceUpto;
  final String? puccUpto;
  final bool? blacklistStatus;
  final bool? isCommercial;
  final String? ownerCount;

  const VehicleRcData({
    this.registrationNumber,
    this.manufacturer,
    this.model,
    this.year,
    this.fuelType,
    this.color,
    this.bodyType,
    this.vehicleClass,
    this.vehicleCategory,
    this.seatingCapacity,
    this.cubicCapacity,
    this.grossVehicleWeight,
    this.chassisNumber,
    this.engineNumber,
    this.rcStatus,
    this.registrationAuthority,
    this.registrationDate,
    this.rcExpiryDate,
    this.taxUpto,
    this.insuranceCompany,
    this.insuranceUpto,
    this.puccUpto,
    this.blacklistStatus,
    this.isCommercial,
    this.ownerCount,
  });

  factory VehicleRcData.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));

    return VehicleRcData(
      registrationNumber: json['registrationNumber'] as String?,
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      year: asInt(json['year']),
      fuelType: json['fuelType'] as String?,
      color: json['color'] as String?,
      bodyType: json['bodyType'] as String?,
      vehicleClass: json['vehicleClass'] as String?,
      vehicleCategory: json['vehicleCategory'] as String?,
      seatingCapacity: json['seatingCapacity']?.toString(),
      cubicCapacity: json['cubicCapacity']?.toString(),
      grossVehicleWeight: json['grossVehicleWeight']?.toString(),
      chassisNumber: json['chassisNumber'] as String?,
      engineNumber: json['engineNumber'] as String?,
      rcStatus: json['rcStatus'] as String?,
      registrationAuthority: json['registrationAuthority'] as String?,
      registrationDate: json['registrationDate'] as String?,
      rcExpiryDate: json['rcExpiryDate'] as String?,
      taxUpto: json['taxUpto'] as String?,
      insuranceCompany: json['insuranceCompany'] as String?,
      insuranceUpto: json['insuranceUpto'] as String?,
      puccUpto: json['puccUpto'] as String?,
      blacklistStatus: json['blacklistStatus'] as bool?,
      isCommercial: json['isCommercial'] as bool?,
      ownerCount: json['ownerCount']?.toString(),
    );
  }
}

/// The verification contract, identical in shape to Web's.
class VerificationResult<T> {
  final bool verified;
  final VerificationState state;

  /// Machine-readable cause. For logs and branching — NEVER shown to a user.
  final String? reason;

  /// User-safe copy authored by the backend. Safe to display verbatim.
  final String message;

  final bool canContinueManually;
  final T? data;
  final String? verifiedAt;
  final String? verificationMode;
  final bool alreadyVerified;

  const VerificationResult({
    required this.verified,
    required this.state,
    required this.message,
    required this.canContinueManually,
    this.reason,
    this.data,
    this.verifiedAt,
    this.verificationMode,
    this.alreadyVerified = false,
  });

  static VerificationResult<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parseData,
  ) {
    final raw = json['data'];
    return VerificationResult<T>(
      verified: json['verified'] == true,
      state: VerificationState.fromWire(json['status'] as String?),
      reason: json['reason'] as String?,
      message: (json['message'] as String?) ?? 'Verification updated.',
      canContinueManually: json['canContinueManually'] == true,
      data: raw is Map<String, dynamic> ? parseData(raw) : null,
      verifiedAt: json['verifiedAt'] as String?,
      verificationMode: json['verificationMode'] as String?,
      alreadyVerified: json['alreadyVerified'] == true,
    );
  }
}

/// Largest document forwarded to the provider — matches the backend limit.
const int kMaxDocumentBytes = 5 * 1024 * 1024;

const List<String> kAllowedDocumentExtensions = [
  'jpg',
  'jpeg',
  'png',
  'webp',
  'heic',
  'heif',
  'pdf',
];

/// Normalize an Indian registration number to the compact form the backend and
/// provider expect: `gj07 4h 4682`, `GJ07-4H-4682` and `GJ074H4682` all become
/// `GJ074H4682`. Only separators are removed, so a real registration is never
/// altered into a different one.
String normalizeRegistration(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Deliberately permissive structural check. Its only job is to keep obviously
/// empty or junk input from spending a paid provider call — Indian registration
/// formats vary too much to validate strictly on a client.
bool isPlausibleRegistration(String value) {
  final normalized = normalizeRegistration(value);
  return normalized.length >= 6 &&
      normalized.length <= 15 &&
      RegExp(r'[A-Z]').hasMatch(normalized) &&
      RegExp(r'[0-9]').hasMatch(normalized);
}

/// Normalize a Driving Licence number to the compact upper-case form the
/// backend and provider expect: `mh01 2011-0012345` becomes `MH0120110012345`.
/// Only separators are removed, so a real licence number is never altered.
String normalizeLicenceNumber(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Deliberately permissive structural check, matching the backend's — its only
/// job is to keep obviously empty or junk input from spending a paid provider
/// call. Indian DL formats vary by issuing state.
bool isPlausibleLicenceNumber(String value) {
  final normalized = normalizeLicenceNumber(value);
  return normalized.length >= 8 &&
      normalized.length <= 20 &&
      RegExp(r'[A-Z]').hasMatch(normalized) &&
      RegExp(r'[0-9]').hasMatch(normalized);
}

/// Filename portion of a path. Handles both separators so it behaves the same
/// on Android, iOS and desktop.
String documentBasename(String filePath) {
  final normalized = filePath.replaceAll(r'\', '/');
  final slash = normalized.lastIndexOf('/');
  return slash == -1 ? normalized : normalized.substring(slash + 1);
}

/// Lowercase extension without the dot, e.g. `jpg`.
String documentExtension(String filePath) {
  final name = documentBasename(filePath);
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

/// Returns an error message, or null when the file is acceptable.
String? validateDocumentFile(File file) {
  final extension = documentExtension(file.path);
  if (!kAllowedDocumentExtensions.contains(extension)) {
    return 'Upload the licence as a JPG, PNG, WEBP, HEIC image or a PDF.';
  }
  final length = file.lengthSync();
  if (length == 0) {
    return 'That file appears to be empty. Please choose another.';
  }
  if (length > kMaxDocumentBytes) {
    return 'Document must be ${kMaxDocumentBytes ~/ (1024 * 1024)} MB or less.';
  }
  return null;
}

MediaType? _contentTypeFor(String path) {
  switch (documentExtension(path)) {
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'png':
      return MediaType('image', 'png');
    case 'webp':
      return MediaType('image', 'webp');
    case 'heic':
      return MediaType('image', 'heic');
    case 'heif':
      return MediaType('image', 'heif');
    case 'pdf':
      return MediaType('application', 'pdf');
    default:
      return null;
  }
}

class VerificationService {
  /// Translate any thrown error into the same contract the backend returns.
  ///
  /// This is what keeps `DioException`, `404`, `ECONNRESET` and stack traces
  /// out of the UI: callers always receive a result with a user-safe message,
  /// and the technical detail goes to the log instead.
  static VerificationResult<T> _failure<T>(Object error, String documentKind) {
    AppLogger.e('❌ verification[$documentKind]: $error');

    var message =
        'Verification is temporarily unavailable. You can try again or '
        'submit your details for manual verification.';

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message =
              'Verification is taking longer than expected. Please try again.';
          break;
        case DioExceptionType.connectionError:
          message =
              'Unable to connect. Check your internet connection and try again.';
          break;
        default:
          // A 4xx from OUR backend is a request problem (e.g. a file we
          // rejected); surface its message, which is already user-safe.
          final status = error.response?.statusCode ?? 0;
          final body = error.response?.data;
          if (status >= 400 &&
              status < 500 &&
              body is Map &&
              body['message'] != null) {
            final raw = body['message'];
            message = raw is List ? raw.join(', ') : raw.toString();
          }
      }
    }

    return VerificationResult<T>(
      verified: false,
      state: VerificationState.temporarilyUnavailable,
      reason: 'client-request-failed',
      message: message,
      canContinueManually: true,
    );
  }

  // ── Driving Licence ──────────────────────────────────────────────────────

  /// Read the caller's stored DL verification.
  ///
  /// Does NOT call the KYC provider — safe to call whenever a screen opens.
  /// Reading a status and performing a verification are separate operations.
  Future<VerificationResult<DrivingLicenceData>> getDrivingLicenceStatus() async {
    try {
      final raw = await ApiClient.instance.get<dynamic>(
        ApiEndpoints.kyc.drivingLicenceStatus,
      );
      if (raw is Map<String, dynamic>) {
        return VerificationResult.fromJson(raw, DrivingLicenceData.fromJson);
      }
      return _failure<DrivingLicenceData>(
        StateError('Unexpected status payload'),
        'dl',
      );
    } catch (e) {
      return _failure<DrivingLicenceData>(e, 'dl');
    }
  }

  /// Verify a Driving Licence by uploading the licence document.
  ///
  /// The real file bytes are sent as multipart/form-data to OUR backend — never
  /// a local file path or a temporary URL — and the backend forwards them to
  /// the provider's OCR endpoint.
  Future<VerificationResult<DrivingLicenceData>> verifyDrivingLicence(
    File document, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final filename = documentBasename(document.path);
      final form = FormData.fromMap({
        'document': await MultipartFile.fromFile(
          document.path,
          filename: filename,
          contentType: _contentTypeFor(document.path),
        ),
      });

      final raw = await ApiClient.instance.upload<dynamic>(
        ApiEndpoints.kyc.verifyDrivingLicense,
        formData: form,
        onSendProgress: onProgress,
      );

      if (raw is Map<String, dynamic>) {
        return VerificationResult.fromJson(raw, DrivingLicenceData.fromJson);
      }
      return _failure<DrivingLicenceData>(
        StateError('Unexpected verification payload'),
        'dl',
      );
    } catch (e) {
      return _failure<DrivingLicenceData>(e, 'dl');
    }
  }

  /// Manual DL fallback — files into the existing admin KYC review queue.
  Future<VerificationResult<DrivingLicenceData>> submitDrivingLicenceManually({
    required String dlNumber,
    String? dateOfBirth,
    String? fileUrl,
  }) async {
    try {
      final raw = await ApiClient.instance.post<dynamic>(
        ApiEndpoints.kyc.drivingLicenceManual,
        data: {
          'dlNumber': dlNumber,
          if (dateOfBirth != null && dateOfBirth.isNotEmpty)
            'dateOfBirth': dateOfBirth,
          if (fileUrl != null && fileUrl.isNotEmpty) 'fileUrl': fileUrl,
        },
      );
      if (raw is Map<String, dynamic>) {
        return VerificationResult.fromJson(raw, DrivingLicenceData.fromJson);
      }
      return _failure<DrivingLicenceData>(
        StateError('Unexpected manual submission payload'),
        'dl',
      );
    } catch (e) {
      return _failure<DrivingLicenceData>(e, 'dl');
    }
  }

  // ── Vehicle RC ───────────────────────────────────────────────────────────

  /// Pre-save RC lookup for the Add/Edit Vehicle flow, before the vehicle
  /// exists in our database.
  Future<VerificationResult<VehicleRcData>> verifyRegistration(
    String registrationNumber,
  ) async {
    try {
      final raw = await ApiClient.instance.get<dynamic>(
        ApiEndpoints.fleet.verifyVehicleRegistration,
        queryParameters: {
          'registrationNumber': normalizeRegistration(registrationNumber),
        },
      );
      if (raw is Map<String, dynamic>) {
        return VerificationResult.fromJson(raw, VehicleRcData.fromJson);
      }
      return _failure<VehicleRcData>(
        StateError('Unexpected RC payload'),
        'rc',
      );
    } catch (e) {
      return _failure<VehicleRcData>(e, 'rc');
    }
  }

  /// Read a saved vehicle's stored RC state. Does NOT call the provider.
  Future<VerificationResult<VehicleRcData>> getVehicleRcStatus(
    String vehicleId,
  ) async {
    try {
      final raw = await ApiClient.instance.get<dynamic>(
        ApiEndpoints.fleet.vehicleRcStatus(vehicleId),
      );
      if (raw is Map<String, dynamic>) {
        return VerificationResult.fromJson(raw, VehicleRcData.fromJson);
      }
      return _failure<VehicleRcData>(StateError('Unexpected RC status'), 'rc');
    } catch (e) {
      return _failure<VehicleRcData>(e, 'rc');
    }
  }

  /// Verify a saved vehicle's RC and persist the result.
  Future<VerificationResult<VehicleRcData>> verifyVehicleRc(
    String vehicleId,
  ) async {
    try {
      final raw = await ApiClient.instance.post<dynamic>(
        ApiEndpoints.fleet.verifyVehicleRc(vehicleId),
      );
      if (raw is Map<String, dynamic>) {
        return VerificationResult.fromJson(raw, VehicleRcData.fromJson);
      }
      return _failure<VehicleRcData>(StateError('Unexpected RC payload'), 'rc');
    } catch (e) {
      return _failure<VehicleRcData>(e, 'rc');
    }
  }

  /// Manual RC fallback — moves the vehicle to Pending for admin review.
  Future<VerificationResult<VehicleRcData>> submitVehicleRcManually(
    String vehicleId, {
    required String documentUrl,
    String? notes,
  }) async {
    try {
      final raw = await ApiClient.instance.post<dynamic>(
        ApiEndpoints.fleet.vehicleRcManualVerification(vehicleId),
        data: {
          'documentUrl': documentUrl,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      if (raw is Map<String, dynamic>) {
        return VerificationResult.fromJson(raw, VehicleRcData.fromJson);
      }
      return _failure<VehicleRcData>(
        StateError('Unexpected manual RC payload'),
        'rc',
      );
    } catch (e) {
      return _failure<VehicleRcData>(e, 'rc');
    }
  }

  /// Verify a driver's licence document for the Add Driver auto-fill flow.
  Future<VerificationResult<DrivingLicenceData>> verifyDriverLicence(
    File document,
  ) async {
    try {
      final form = FormData.fromMap({
        'document': await MultipartFile.fromFile(
          document.path,
          filename: documentBasename(document.path),
          contentType: _contentTypeFor(document.path),
        ),
      });

      final raw = await ApiClient.instance.upload<dynamic>(
        ApiEndpoints.fleet.verifyDriverLicense,
        formData: form,
      );
      if (raw is Map<String, dynamic>) {
        return VerificationResult.fromJson(raw, DrivingLicenceData.fromJson);
      }
      return _failure<DrivingLicenceData>(
        StateError('Unexpected licence payload'),
        'dl',
      );
    } catch (e) {
      return _failure<DrivingLicenceData>(e, 'dl');
    }
  }
}
