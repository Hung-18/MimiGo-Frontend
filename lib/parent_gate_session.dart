import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_failure.dart';

typedef GateWire = Future<Map<String, dynamic>> Function(
  String method,
  String path, {
  Object? body,
  String? token,
  String? proof,
  Set<int>? statuses,
});

String gateText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty)
    throw const ApiInvalidResponse('Invalid session response.');
  return value;
}

DateTime gateDate(Map<String, dynamic> json, String key) =>
    DateTime.tryParse(gateText(json, key)) ??
    (throw const ApiInvalidResponse('Invalid session expiry.'));

enum SessionMode { parent, child }

SessionMode gateMode(Object? mode) => switch (mode) {
  'PARENT' => SessionMode.parent,
  'CHILD' => SessionMode.child,
  _ => throw const ApiInvalidResponse('Invalid session mode.'),
};

abstract interface class CredentialVault {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

/// Only the encrypted refresh bundle crosses this channel. Never PINs/proofs.
class PlatformCredentialVault implements CredentialVault {
  const PlatformCredentialVault();
  static const channel = MethodChannel('mimigo/security');
  @override
  Future<String?> read() => channel.invokeMethod<String>('readRefresh');
  @override
  Future<void> write(String value) =>
      channel.invokeMethod<void>('writeRefresh', value);
  @override
  Future<void> clear() => channel.invokeMethod<void>('clearRefresh');
}

class GateProof {
  GateProof.fromJson(
    Map<String, dynamic> json, {
    required String action,
    required String kind,
    String? childId,
  }) : value = gateText(json, 'proof'),
       expiresAt = gateDate(json, 'expiresAt') {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value) ||
        json['action'] != action ||
        json['kind'] != kind ||
        json['method'] != (kind == 'STEP_UP' ? 'PASSWORD' : 'PIN') ||
        json['singleUse'] != (action != 'PARENT_AREA') ||
        json['childId'] != childId ||
        !expiresAt.isAfter(DateTime.now()))
      throw const ApiInvalidResponse('Invalid authorization proof response.');
  }
  final String value;
  final DateTime expiresAt;
}

class DeviceSession {
  const DeviceSession({
    required this.token,
    required this.expiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
    required this.sessionId,
    required this.parentId,
    required this.mode,
    this.childId,
  });
  factory DeviceSession.login(Map<String, dynamic> json) {
    if (json['tokenType'] != 'Bearer' ||
        gateMode(json['sessionMode']) != SessionMode.parent ||
        json.containsKey('childContextToken'))
      throw const ApiInvalidResponse('Invalid Parent login session.');
    return DeviceSession(
      token: gateText(json, 'accessToken'),
      expiresAt: gateDate(json, 'expiresAt'),
      refreshToken: gateText(json, 'refreshToken'),
      refreshExpiresAt: gateDate(json, 'refreshExpiresAt'),
      sessionId: gateText(json, 'sessionId'),
      parentId: gateText(json, 'parentId'),
      mode: SessionMode.parent,
    );
  }
  final String token, refreshToken, sessionId, parentId;
  final DateTime expiresAt, refreshExpiresAt;
  final SessionMode mode;
  final String? childId;
  String vaultBundle() => jsonEncode({
    'refreshToken': refreshToken,
    'refreshExpiresAt': refreshExpiresAt.toUtc().toIso8601String(),
    'sessionId': sessionId,
    'parentId': parentId,
  });
  DeviceSession access(
    String token,
    DateTime expiry,
    SessionMode mode,
    String? childId, {
    String? refreshToken,
    DateTime? refreshExpiresAt,
  }) => DeviceSession(
    token: token,
    expiresAt: expiry,
    mode: mode,
    childId: childId,
    refreshToken: refreshToken ?? this.refreshToken,
    refreshExpiresAt: refreshExpiresAt ?? this.refreshExpiresAt,
    sessionId: sessionId,
    parentId: parentId,
  );
}

/// Serializes every authenticated command with refresh and mode transitions.
/// This also keeps queued old-child writes from using a new child's token.
class GateSessionCoordinator extends ChangeNotifier {
  GateSessionCoordinator(
    this.wire,
    this.vault, {
    DateTime Function()? clock,
    this.credentialScope = 'test-only',
  }) : clock = clock ?? DateTime.now;
  final GateWire wire;
  final CredentialVault vault;
  final DateTime Function() clock;
  final String credentialScope;
  DeviceSession? current;
  GateProof? _parentProof;
  Future<void> _tail = Future.value();
  Future<void>? _refreshFlight;
  Timer? _proofTimer, _accessTimer;
  int _generation = 0;
  bool _disposed = false;
  bool get hasSession => current != null;
  bool get hasParentProof =>
      current?.mode == SessionMode.parent &&
      (_parentProof?.expiresAt.isAfter(clock()) ?? false);
  String? get parentProof => hasParentProof ? _parentProof!.value : null;

  Future<T> exclusive<T>(Future<T> Function() work) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return () async {
      await previous;
      try {
        return await work();
      } finally {
        done.complete();
      }
    }();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void dropProof() {
    _proofTimer?.cancel();
    _parentProof = null;
    _notify();
  }

  void invalidateMemory() {
    _proofTimer?.cancel();
    _accessTimer?.cancel();
    _generation++;
    current = null;
    _parentProof = null;
    _notify();
  }

  Future<void> forget() async {
    invalidateMemory();
    try {
      await vault.clear();
    } catch (_) {
      throw const ApiFailure(
        'Secure session storage is unavailable.',
        code: 'SECURE_STORAGE_UNAVAILABLE',
      );
    }
  }

  Future<void> _save(DeviceSession value, int generation) async {
    if (generation != _generation)
      throw const ApiFailure(
        'Session changed.',
        code: 'SESSION_REVOKED',
        status: 401,
      );
    if (!value.expiresAt.isAfter(clock()) ||
        !value.refreshExpiresAt.isAfter(clock()))
      throw const ApiInvalidResponse('Session is already expired.');
    await vault.write(
      jsonEncode({
        ...jsonDecode(value.vaultBundle()) as Map<String, dynamic>,
        'apiScope': credentialScope,
      }),
    );
    if (generation != _generation) {
      await vault.clear();
      throw const ApiFailure(
        'Session changed.',
        code: 'SESSION_REVOKED',
        status: 401,
      );
    }
    current = value;
    _armAccessExpiry();
    _notify();
  }

  Future<void> login(String email, String password) => exclusive(() async {
    await forget();
    final generation = _generation;
    try {
      final json = await wire(
        'POST',
        'auth/login',
        body: {'email': email, 'password': password},
        statuses: {200},
      );
      await _save(DeviceSession.login(json), generation);
    } on ApiFailure {
      await forget();
      rethrow;
    } catch (_) {
      await forget();
      throw const ApiFailure(
        'Secure session storage is unavailable.',
        code: 'SECURE_STORAGE_UNAVAILABLE',
      );
    }
  });

  Future<void> restore() => exclusive(() async {
    final generation = _generation;
    try {
      final encoded = await vault.read();
      if (encoded == null) return;
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      if (json['apiScope'] != credentialScope) {
        await vault.clear();
        return;
      }
      current = DeviceSession(
        token: '',
        expiresAt: DateTime.fromMillisecondsSinceEpoch(0),
        refreshToken: gateText(json, 'refreshToken'),
        refreshExpiresAt: gateDate(json, 'refreshExpiresAt'),
        sessionId: gateText(json, 'sessionId'),
        parentId: gateText(json, 'parentId'),
        mode: SessionMode.parent,
      );
      await refreshLocked(generation: generation);
    } catch (_) {
      await forget();
      rethrow;
    }
  });

  Future<void> refresh() {
    final existing = _refreshFlight;
    if (existing != null) return existing;
    final future = exclusive(() => refreshLocked());
    _refreshFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshFlight, future)) _refreshFlight = null;
    });
  }

  /// Only call while holding exclusive(). Destroy durable old credentials
  /// BEFORE presenting them: a lost rotation response can never replay them.
  Future<void> refreshLocked({int? generation}) async {
    final before = current;
    final expectedGeneration = generation ?? _generation;
    if (before == null || !before.refreshExpiresAt.isAfter(clock())) {
      await forget();
      throw const ApiFailure(
        'Sign in again.',
        code: 'SESSION_REVOKED',
        status: 401,
      );
    }
    try {
      await vault.clear();
      final json = await wire(
        'POST',
        'auth/sessions/refresh',
        body: {'refreshToken': before.refreshToken},
        statuses: {200},
      );
      final mode = gateMode(json['sessionMode']);
      final childId = mode == SessionMode.child
          ? gateText(json, 'childId')
          : null;
      if (json.containsKey(
            mode == SessionMode.parent ? 'childContextToken' : 'accessToken',
          ) ||
          (mode == SessionMode.parent && json['childId'] != null))
        throw const ApiInvalidResponse('Ambiguous refresh token context.');
      final rotated = gateText(json, 'refreshToken');
      if (rotated == before.refreshToken)
        throw const ApiInvalidResponse('Refresh credential did not rotate.');
      final value = before.access(
        gateText(
          json,
          mode == SessionMode.parent ? 'accessToken' : 'childContextToken',
        ),
        gateDate(json, 'expiresAt'),
        mode,
        childId,
        refreshToken: rotated,
        refreshExpiresAt: gateDate(json, 'refreshExpiresAt'),
      );
      if (mode != before.mode || childId != before.childId) _parentProof = null;
      await _save(value, expectedGeneration);
    } catch (_) {
      await forget();
      throw const ApiFailure(
        'Session could not be validated. Sign in again.',
        code: 'SESSION_REVOKED',
        status: 401,
      );
    }
  }

  void _checkScope(String? childId, bool anyMode) {
    final value = current;
    if (value == null)
      throw const ApiFailure(
        'Sign in again.',
        code: 'UNAUTHENTICATED',
        status: 401,
      );
    if (anyMode) return;
    if (childId == null && value.mode != SessionMode.parent)
      throw const ApiFailure(
        'Parent route unavailable in Child Mode.',
        code: 'CHILD_CONTEXT_FORBIDDEN',
        status: 403,
      );
    if (childId != null && value.mode != SessionMode.child)
      throw const ApiFailure(
        'Enter Child Mode first.',
        code: 'CHILD_CONTEXT_REQUIRED',
        status: 403,
      );
    if (childId != null && value.childId != childId)
      throw const ApiFailure(
        'Child is unavailable.',
        code: 'CHILD_NOT_FOUND',
        status: 404,
      );
  }

  Future<T> authorized<T>(
    Future<T> Function(String token, String? proof) action, {
    String? childId,
    bool anyMode = false,
    bool proofRequired = false,
  }) => exclusive(() async {
    _checkScope(childId, anyMode);
    if (!current!.expiresAt.isAfter(clock().add(const Duration(seconds: 20))))
      await refreshLocked();
    _checkScope(childId, anyMode);
    Future<T> send() async {
      if (proofRequired && !hasParentProof)
        throw const ApiFailure(
          'Verify the Parent PIN again.',
          code: 'PARENT_GATE_REQUIRED',
          status: 403,
        );
      return action(current!.token, parentProof);
    }

    try {
      return await send();
    } on ApiFailure catch (failure) {
      if (failure.code == 'PARENT_NOT_ACTIVE') {
        await forget();
        rethrow;
      }
      if (failure.code == 'PARENT_GATE_REQUIRED' ||
          failure.code == 'STEP_UP_REQUIRED' ||
          (proofRequired && {403, 404}.contains(failure.status)))
        dropProof();
      if (failure.status != 401 ||
          !{'SESSION_REVOKED', 'UNAUTHENTICATED'}.contains(failure.code))
        rethrow;
      dropProof();
      await refreshLocked();
      _checkScope(childId, anyMode);
      try {
        return await send();
      } on ApiFailure catch (second) {
        if (second.status == 401 || second.code == 'PARENT_NOT_ACTIVE')
          await forget();
        else if (proofRequired && {403, 404}.contains(second.status))
          dropProof();
        rethrow;
      }
    }
  });

  void adoptAccess(
    String token,
    DateTime expiry,
    SessionMode mode,
    String? childId,
  ) {
    if (current == null || !expiry.isAfter(clock()))
      throw const ApiInvalidResponse('Invalid token transition.');
    current = current!.access(token, expiry, mode, childId);
    _proofTimer?.cancel();
    _armAccessExpiry();
    _parentProof = null;
    _notify();
  }

  void retainParentProof(GateProof proof) {
    if (current?.mode != SessionMode.parent)
      throw const ApiFailure(
        'Parent Mode required.',
        code: 'CHILD_CONTEXT_FORBIDDEN',
        status: 403,
      );
    _parentProof = proof;
    _proofTimer?.cancel();
    _proofTimer = Timer(proof.expiresAt.difference(clock()), dropProof);
    _notify();
  }

  Future<void> logout() => exclusive(() async {
    ApiFailure? failure;
    try {
      if (current != null) {
        if (!current!.expiresAt.isAfter(clock())) await refreshLocked();
        await wire(
          'POST',
          'auth/logout',
          token: current!.token,
          statuses: {204},
        );
      }
    } on ApiFailure catch (error) {
      failure = error;
    } finally {
      await forget();
    }
    if (failure != null) throw failure;
  });
  void _armAccessExpiry() {
    _accessTimer?.cancel();
    if (current != null)
      _accessTimer = Timer(current!.expiresAt.difference(clock()), dropProof);
  }

  @override
  void dispose() {
    _proofTimer?.cancel();
    _accessTimer?.cancel();
    _disposed = true;
    _generation++;
    current = null;
    _parentProof = null;
    super.dispose();
  }
}
