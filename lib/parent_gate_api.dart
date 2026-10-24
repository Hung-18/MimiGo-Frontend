import 'api_failure.dart';
import 'parent_gate_session.dart';

enum PinAction { enroll, change, reset }

class ParentGateStatus {
  const ParentGateStatus(this.status, this.retryAfterSeconds);
  factory ParentGateStatus.fromJson(Map<String, dynamic> json) {
    final status = gateText(json, 'status');
    if (!{
      'NOT_ENROLLED',
      'ENROLLED',
      'LOCKED',
      'RECOVERY_REQUIRED',
      'UNAVAILABLE',
    }.contains(status))
      throw const ApiInvalidResponse('Invalid Parent Gate status.');
    final retry = json['retryAfterSeconds'];
    if (retry != null && (retry is! int || retry < 1))
      throw const ApiInvalidResponse('Invalid lock duration.');
    return ParentGateStatus(status, retry as int?);
  }
  final String status;
  final int? retryAfterSeconds;
}

class ParentActivityItem {
  ParentActivityItem.fromJson(Map<String, dynamic> json)
    : sessionId = gateText(json, 'sessionId'),
      lessonId = gateText(json, 'lessonId'),
      revisionId = gateText(json, 'revisionId'),
      lessonCode = gateText(json, 'lessonCode'),
      lessonTitle = gateText(json, 'lessonTitle'),
      state = gateText(json, 'state'),
      startedAt = gateDate(json, 'startedAt'),
      lastActivityAt = gateDate(json, 'lastActivityAt'),
      endedAt = json['endedAt'] == null ? null : gateDate(json, 'endedAt') {
    if (!json.containsKey('endedAt') ||
        !{'IN_PROGRESS', 'COMPLETED', 'ABANDONED'}.contains(state) ||
        (state == 'COMPLETED' && endedAt == null))
      throw const ApiInvalidResponse('Invalid activity response.');
  }
  final String sessionId, lessonId, revisionId, lessonCode, lessonTitle, state;
  final DateTime startedAt, lastActivityAt;
  final DateTime? endedAt;
}

abstract interface class ParentGateApi {
  bool get parentGateEnabled;
  GateSessionCoordinator? get gateSession;
  Future<void> setParentPin(
    PinAction action,
    String password,
    String pin,
    String confirmation,
  );
  Future<void> verifyParentArea(String pin);
  Future<void> switchChildContext(String pin, String childId);
  Future<List<ParentActivityItem>> parentActivity(String childId);
  Future<int> revokeOtherDevices();
}

class ParentGateService {
  ParentGateService(this.session, this.wire);
  final GateSessionCoordinator session;
  final GateWire wire;
  static void validatePin(String pin) {
    if (!RegExp(r'^[0-9]{6}$').hasMatch(pin))
      throw const ApiFailure(
        'Use exactly six ASCII digits.',
        code: 'INVALID_PIN_FORMAT',
        status: 400,
      );
  }

  Future<void> _ready({bool parentOnly = false}) async {
    if (session.current == null)
      throw const ApiFailure(
        'Sign in again.',
        code: 'UNAUTHENTICATED',
        status: 401,
      );
    if (!session.current!.expiresAt.isAfter(
      session.clock().add(const Duration(seconds: 20)),
    ))
      await session.refreshLocked();
    if (parentOnly && session.current!.mode != SessionMode.parent)
      throw const ApiFailure(
        'Leave Child Mode first.',
        code: 'CHILD_CONTEXT_FORBIDDEN',
        status: 403,
      );
  }

  Future<void> _reconcile(ApiFailure failure) async {
    session.dropProof();
    if (failure.code == 'PARENT_NOT_ACTIVE') {
      await session.forget();
      return;
    }
    if (failure.status == 401 &&
        {'SESSION_REVOKED', 'UNAUTHENTICATED'}.contains(failure.code))
      await session.refreshLocked();
  }

  Future<void> setPin(
    PinAction action,
    String password,
    String pin,
    String confirmation,
  ) => session.exclusive(() async {
    validatePin(pin);
    validatePin(confirmation);
    if (pin != confirmation)
      throw const ApiFailure(
        'PINs do not match.',
        code: 'PIN_CONFIRMATION_MISMATCH',
        status: 400,
      );
    if (password.isEmpty)
      throw const ApiFailure(
        'Enter your password.',
        code: 'STEP_UP_REQUIRED',
        status: 403,
      );
    await _ready(parentOnly: true);
    final actionCode = switch (action) {
      PinAction.enroll => 'PIN_ENROLL',
      PinAction.change => 'PIN_CHANGE',
      PinAction.reset => 'PIN_RESET',
    };
    try {
      final json = await wire(
        'POST',
        'auth/step-up',
        token: session.current!.token,
        body: {'password': password, 'action': actionCode},
        statuses: {200},
      );
      final proof = GateProof.fromJson(
        json,
        action: actionCode,
        kind: 'STEP_UP',
      );
      final response = await wire(
        action == PinAction.change ? 'PUT' : 'POST',
        'parents/me/parent-gate${action == PinAction.enroll
            ? ''
            : action == PinAction.change
            ? '/pin'
            : '/reset'}',
        token: session.current!.token,
        proof: proof.value,
        body: action == PinAction.reset
            ? {'newPin': pin, 'newPinConfirmation': confirmation}
            : {'pin': pin, 'pinConfirmation': confirmation},
        statuses: action == PinAction.reset ? {200} : {204},
      );
      if (action == PinAction.reset && response['sessionMode'] != 'PARENT')
        throw const ApiInvalidResponse('Invalid PIN reset response.');
      session.dropProof();
    } on ApiFailure catch (failure) {
      await _reconcile(failure);
      rethrow;
    }
  });

  Future<void> parentArea(String pin) => session.exclusive(() async {
    validatePin(pin);
    await _ready();
    final wasChild = session.current!.mode == SessionMode.child;
    try {
      final json = await wire(
        'POST',
        'parent-gate/verifications',
        token: session.current!.token,
        body: {'pin': pin, 'action': 'PARENT_AREA'},
        statuses: {200},
      );
      final proof = GateProof.fromJson(
        json,
        action: 'PARENT_AREA',
        kind: 'GATE',
      );
      if (json['sessionMode'] != 'PARENT')
        throw const ApiInvalidResponse('Parent Mode was not confirmed.');
      if (wasChild)
        session.adoptAccess(
          gateText(json, 'accessToken'),
          gateDate(json, 'accessTokenExpiresAt'),
          SessionMode.parent,
          null,
        );
      session.retainParentProof(proof);
    } on ApiFailure catch (failure) {
      await _reconcile(failure);
      if (wasChild &&
          {
            'CONNECTIVITY',
            'TIMEOUT',
            'INVALID_RESPONSE',
          }.contains(failure.code))
        await session.refreshLocked();
      rethrow;
    }
  });

  Future<void> enterChild(String pin, String childId) =>
      session.exclusive(() async {
        validatePin(pin);
        if (childId.isEmpty)
          throw const ApiFailure(
            'Choose an owned child.',
            code: 'CHILD_NOT_FOUND',
            status: 404,
          );
        await _ready();
        var entering = false;
        try {
          final json = await wire(
            'POST',
            'parent-gate/verifications',
            token: session.current!.token,
            body: {'pin': pin, 'action': 'SWITCH_CHILD', 'childId': childId},
            statuses: {200},
          );
          final proof = GateProof.fromJson(
            json,
            action: 'SWITCH_CHILD',
            kind: 'GATE',
            childId: childId,
          );
          if (gateMode(json['sessionMode']) != session.current!.mode)
            throw const ApiInvalidResponse('Unexpected PIN verification mode.');
          entering = true;
          final result = await wire(
            'POST',
            'child-contexts',
            token: session.current!.token,
            proof: proof.value,
            body: {'childId': childId},
            statuses: {201},
          );
          if (result['sessionMode'] != 'CHILD' || result['childId'] != childId)
            throw const ApiInvalidResponse(
              'A different child context was returned.',
            );
          session.adoptAccess(
            gateText(result, 'childContextToken'),
            gateDate(result, 'expiresAt'),
            SessionMode.child,
            childId,
          );
        } on ApiFailure catch (failure) {
          await _reconcile(failure);
          if (entering &&
              {
                'CONNECTIVITY',
                'TIMEOUT',
                'INVALID_RESPONSE',
              }.contains(failure.code)) {
            // A SWITCH proof is never reused after an unknown enter outcome.
            await session.refreshLocked();
            if (session.current?.mode == SessionMode.child &&
                session.current?.childId == childId)
              return;
          }
          rethrow;
        }
      });

  Future<List<ParentActivityItem>> activity(String childId) =>
      session.authorized((token, proof) async {
        final json = await wire(
          'GET',
          'children/$childId/learning-sessions',
          token: token,
          proof: proof,
          statuses: {200},
        );
        final values = json['items'];
        if (values is! List)
          throw const ApiInvalidResponse('Invalid activity list.');
        return values
            .map((value) {
              if (value is! Map<String, dynamic>)
                throw const ApiInvalidResponse('Invalid activity item.');
              return ParentActivityItem.fromJson(value);
            })
            .toList(growable: false);
      }, proofRequired: true);
  Future<int> revokeOthers() => session.authorized((token, _) async {
    final json = await wire(
      'POST',
      'auth/sessions/revoke-others',
      token: token,
      statuses: {200},
    );
    final count = json['revokedCount'];
    if (count is! int || count < 0)
      throw const ApiInvalidResponse('Invalid revocation response.');
    return count;
  });
}
