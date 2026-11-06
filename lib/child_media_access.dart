import 'package:flutter/foundation.dart';

/// A short-lived, in-memory source. Signed storage grants never receive the
/// API bearer; the legacy local debug adapter uses header authentication.
class ChildMediaSource {
  const ChildMediaSource(
    this.uri,
    this.bearer, {
    this.sendBearer = true,
    this.expiresAt,
  });
  final Uri uri;
  final String bearer;
  final bool sendBearer;
  final DateTime? expiresAt;
  Map<String, String> get httpHeaders =>
      sendBearer ? {'Authorization': 'Bearer $bearer'} : const {};
}

abstract interface class ChildMediaAccess {
  bool get childMediaEnabled;
  Listenable get mediaSessionChanges;
  bool mediaSessionIsCurrent(String childId, String bearer);
  Future<ChildMediaSource> childMediaSource(
    String childId,
    String lessonId,
    String revisionId,
  );
}
