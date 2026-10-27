import 'package:flutter/foundation.dart';

/// A short-lived, in-memory source. The URI contains only lesson and revision
/// identity; the bearer is passed as an HTTP header to the native player.
class ChildMediaSource {
  const ChildMediaSource(this.uri, this.bearer);
  final Uri uri;
  final String bearer;
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
