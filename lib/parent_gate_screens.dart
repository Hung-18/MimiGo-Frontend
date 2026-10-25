import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart' show MimiGoApi, ChildSummary, ChildDetail, Frame, dateText;
import 'api_failure.dart';
import 'parent_gate_api.dart';
import 'parent_gate_session.dart';
import 'gate_screen_security.dart';
import 'mimigo_design.dart';

String gateFailureText(ApiFailure failure) => switch (failure.code) {
  'INVALID_CREDENTIALS' => 'Email or password is incorrect.',
  'EMAIL_NOT_VERIFIED' => 'Verify this synthetic email before signing in.',
  'PARENT_GATE_FAILED' => 'The PIN could not be verified. Try again.',
  'INVALID_PIN_FORMAT' => 'Enter exactly six ASCII digits.',
  'PIN_CONFIRMATION_MISMATCH' => 'The two PIN entries must match.',
  'PIN_TOO_WEAK' =>
    'Choose a less predictable PIN. The service rejected this choice.',
  'PARENT_GATE_LOCKED' || 'ACCOUNT_LOGIN_LOCKED' =>
    'Verification is temporarily locked. Wait for the service retry time.',
  'PARENT_GATE_RECOVERY_REQUIRED' => 'PIN recovery is required. In Parent Mode, reauthenticate with your password to reset it.',
  'PARENT_GATE_NOT_ENROLLED' =>
    'Set up a Parent PIN with password reauthentication first.',
  'PARENT_GATE_ALREADY_ENROLLED' => 'A PIN is already enrolled. Check status or use password-authorized change/reset.',
  'STEP_UP_FAILED' => 'Password reauthentication failed.',
  'STEP_UP_REQUIRED' => 'Fresh password reauthentication is required. Re-enter the password and new PIN.',
  'PARENT_GATE_REQUIRED' =>
    'Verify your PIN again to open protected Parent information.',
  'CHILD_CONTEXT_REQUIRED' =>
    'Enter the selected child’s authorized Child Mode first.',
  'CHILD_CONTEXT_FORBIDDEN' =>
    'This Parent operation is unavailable in Child Mode.',
  'SESSION_REVOKED' ||
  'UNAUTHENTICATED' => 'The session could not be validated. Sign in again.',
  'CHILD_NOT_FOUND' =>
    'This child is unavailable. Return to the authorized roster.',
  'PARENT_NOT_ACTIVE' => 'This Parent account is unavailable. Sign in again or contact the operator.',
  'CHILD_NOT_ACTIVE' =>
    'This child is unavailable. Return to authorized Parent selection.',
  'SECURE_STORAGE_UNAVAILABLE' =>
    'Secure credential storage is unavailable. No session is assumed.',
  'SCREEN_PROTECTION_UNAVAILABLE' =>
    'Sensitive screen protection is unavailable. PIN entry is disabled.',
  'CONNECTIVITY' || 'TIMEOUT' => 'The service response could not be confirmed. Check connectivity and retry; no success is assumed.',
  _ when failure.status == 503 =>
    'The security service is unavailable. Try again later.',
  _ when failure.status == 429 => 'Please wait before trying again.',
  _ when failure.status == 403 =>
    'This operation is not authorized by the service.',
  _ =>
    'The operation could not be confirmed. Retry or return to account entry.',
};

class GateError extends StatelessWidget {
  const GateError(this.error, {super.key});
  final ApiFailure? error;
  @override
  Widget build(BuildContext context) => error == null
      ? const SizedBox.shrink()
      : Semantics(
          liveRegion: true,
          child: MimiNotice(
            icon: Icons.lock_outline,
            color: MimiColors.rose,
            child: Text(
              '${gateFailureText(error!)}\n${error!.code ?? 'REQUEST_FAILED'}',
              key: const Key('gateError'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
}

/// All enrollment/change/reset and PIN verification use the same protected
/// input surface. No PIN/password survives a submit, background or disposal.
class GatePinScreen extends StatefulWidget {
  const GatePinScreen({
    super.key,
    required this.api,
    required this.done,
    required this.back,
    required this.accountEntry,
    required this.recover,
    this.childId,
    this.pinAction,
    this.status,
    this.security,
    this.clock,
  });
  final ParentGateApi api;
  final Future<void> Function() done;
  final VoidCallback back, accountEntry, recover;
  final String? childId;
  final PinAction? pinAction;
  final ParentGateStatus? status;
  final GateScreenSecurity? security;
  final DateTime Function()? clock;
  @override
  State<GatePinScreen> createState() => _GatePinScreenState();
}

class _GatePinScreenState extends State<GatePinScreen>
    with WidgetsBindingObserver {
  final pin = TextEditingController(),
      confirmation = TextEditingController(),
      password = TextEditingController();
  late final security = widget.security ?? GateScreenSecurity();
  bool protected = false, busy = false, leaving = false;
  ApiFailure? error;
  DateTime? retryAt;
  Timer? ticker;
  DateTime now() => widget.clock?.call() ?? DateTime.now();
  int get waitSeconds => retryAt == null
      ? 0
      : (retryAt!.difference(now()).inMilliseconds / 1000).ceil().clamp(
          0,
          86400,
        );
  bool get recoveryRequired =>
      error?.code == 'PARENT_GATE_RECOVERY_REQUIRED' ||
      (widget.pinAction == null &&
          widget.status?.status == 'RECOVERY_REQUIRED');
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final seconds = widget.status?.retryAfterSeconds;
    if (widget.pinAction == null && seconds != null) cooldown(seconds);
    protect();
  }

  Future<void> protect() async {
    try {
      await security.protect();
      if (mounted) setState(() => protected = true);
    } catch (_) {
      if (mounted)
        setState(
          () => error = const ApiFailure(
            'Protection unavailable.',
            code: 'SCREEN_PROTECTION_UNAVAILABLE',
          ),
        );
    }
  }

  void cooldown(int seconds) {
    if (seconds <= 0) return;
    retryAt = now().add(Duration(seconds: seconds));
    ticker?.cancel();
    ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});
      if (waitSeconds == 0) timer.cancel();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      pin.clear();
      confirmation.clear();
      password.clear();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker?.cancel();
    pin.dispose();
    confirmation.dispose();
    password.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(security.release().catchError((Object _) {}));
    });
    super.dispose();
  }

  Future<void> submit() async {
    if (!protected || busy || leaving || waitSeconds > 0 || recoveryRequired)
      return;
    final entered = pin.text, confirm = confirmation.text, pass = password.text;
    if (!RegExp(r'^[0-9]{6}$').hasMatch(entered) ||
        (widget.pinAction != null &&
            !RegExp(r'^[0-9]{6}$').hasMatch(confirm))) {
      setState(
        () => error = const ApiFailure(
          'Invalid PIN.',
          code: 'INVALID_PIN_FORMAT',
        ),
      );
      return;
    }
    if (widget.pinAction != null && entered != confirm) {
      setState(
        () => error = const ApiFailure(
          'Mismatch.',
          code: 'PIN_CONFIRMATION_MISMATCH',
        ),
      );
      return;
    }
    if (widget.pinAction != null && pass.isEmpty) {
      setState(
        () => error = const ApiFailure(
          'Password required.',
          code: 'STEP_UP_REQUIRED',
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    pin.clear();
    confirmation.clear();
    password.clear();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.pinAction != null)
        await widget.api.setParentPin(
          widget.pinAction!,
          pass,
          entered,
          confirm,
        );
      else if (widget.childId != null)
        await widget.api.switchChildContext(entered, widget.childId!);
      else
        await widget.api.verifyParentArea(entered);
      if (!mounted) return;
      await widget.done();
      if (mounted) setState(() => leaving = true);
    } on ApiFailure catch (failure) {
      if (mounted)
        setState(() {
          error = failure;
          cooldown(failure.retryAfterSeconds ?? 0);
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error = const ApiFailure(
            'Security service unavailable.',
            code: 'PARENT_GATE_UNAVAILABLE',
            status: 503,
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget secret(
    TextEditingController controller,
    String key,
    String label, {
    bool digits = false,
  }) => TextField(
    key: Key(key),
    controller: controller,
    enabled: !busy && !leaving,
    obscureText: true,
    autocorrect: false,
    enableSuggestions: false,
    enableIMEPersonalizedLearning: false,
    enableInteractiveSelection: false,
    keyboardType: digits ? TextInputType.number : TextInputType.visiblePassword,
    textAlign: digits ? TextAlign.center : TextAlign.start,
    style: digits
        ? const TextStyle(
            fontSize: 26,
            letterSpacing: 4,
            fontWeight: FontWeight.w700,
          )
        : null,
    inputFormatters: digits
        ? [
            FilteringTextInputFormatter.allow(RegExp('[0-9]')),
            LengthLimitingTextInputFormatter(6),
          ]
        : null,
    decoration: InputDecoration(labelText: label),
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => submit(),
  );
  @override
  Widget build(BuildContext context) {
    final title = widget.pinAction == null
        ? widget.childId == null
              ? 'Verify PIN for Parent Area'
              : 'Verify PIN to enter selected Child Mode'
        : switch (widget.pinAction!) {
            PinAction.enroll => 'Set up Parent PIN',
            PinAction.change => 'Change Parent PIN',
            PinAction.reset => 'Reset Parent PIN',
          };
    return Frame(
      title: title,
      back: busy || leaving ? null : widget.back,
      children: [
        const Text(
          'R0 SYNTHETIC CANDIDATE · Not Security/Legal approved. A PIN or password does not prove guardian authority or child consent.',
        ),
        if (!protected) ...[
          if (error == null)
            const LinearProgressIndicator(
              semanticsLabel: 'Securing PIN screen',
            ),
          GateError(error),
        ],
        if (protected) ...[
          if (widget.pinAction != null) ...[
            const Text(
              'Fresh password reauthentication is required for this PIN action. No email/PIN recovery provider is simulated.',
            ),
            secret(password, 'gatePassword', 'Current parent password'),
            const SizedBox(height: 12),
          ],
          secret(
            pin,
            'gatePin',
            widget.pinAction == null
                ? 'Six-digit Parent PIN'
                : 'New six-digit Parent PIN',
            digits: true,
          ),
          if (widget.pinAction != null) ...[
            const SizedBox(height: 12),
            secret(
              confirmation,
              'gatePinConfirmation',
              'Confirm new PIN',
              digits: true,
            ),
          ],
          if (busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Waiting for security service',
            ),
          GateError(error),
          if (waitSeconds > 0)
            Semantics(
              liveRegion: true,
              child: Text(
                'Try again in $waitSeconds seconds.',
                key: const Key('gateRetryAfter'),
              ),
            ),
          if (recoveryRequired)
            const Text(
              'Recovery is required. Leave Child Mode by signing out, then sign in for password-authorized reset.',
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: FilledButton(
              key: const Key('gateSubmit'),
              onPressed: busy || leaving || waitSeconds > 0 || recoveryRequired
                  ? null
                  : submit,
              child: Text(
                busy
                    ? 'Waiting for service…'
                    : widget.pinAction == null
                    ? 'Verify PIN'
                    : 'Reauthenticate and save PIN',
              ),
            ),
          ),
        ],
        if (widget.pinAction == null)
          TextButton(
            key: const Key('gateRecover'),
            onPressed: busy || leaving ? null : widget.recover,
            child: Text(
              widget.api.gateSession?.current?.mode == SessionMode.child
                  ? 'Forgot PIN? Sign out and sign in'
                  : 'Forgot PIN / set up PIN with password',
            ),
          ),
        TextButton(
          key: const Key('gateAccountEntry'),
          onPressed: leaving ? null : widget.accountEntry,
          child: const Text('Sign out and return to account entry'),
        ),
      ],
    );
  }
}

class GatedParentArea extends StatefulWidget {
  const GatedParentArea({
    super.key,
    required this.api,
    required this.gate,
    required this.home,
    required this.reverify,
    required this.changePin,
    required this.resetPin,
  });
  final MimiGoApi api;
  final ParentGateApi gate;
  final VoidCallback home, reverify, changePin, resetPin;
  @override
  State<GatedParentArea> createState() => _GatedParentAreaState();
}

class _GatedParentAreaState extends State<GatedParentArea> {
  final security = GateScreenSecurity();
  bool protected = false;
  List<ChildSummary> children = [];
  ChildDetail? detail;
  List<ParentActivityItem>? activity;
  ApiFailure? error;
  bool busy = false;
  String? info;
  @override
  void initState() {
    super.initState();
    secureAndLoad();
  }

  Future<void> secureAndLoad() async {
    try {
      await security.protect();
      if (!mounted) return;
      setState(() => protected = true);
      await load();
    } catch (_) {
      if (mounted)
        setState(
          () => error = const ApiFailure(
            'Screen protection unavailable.',
            code: 'SCREEN_PROTECTION_UNAVAILABLE',
          ),
        );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(security.release().catchError((Object _) {}));
    });
    super.dispose();
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      info = null;
    });
    try {
      await work();
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() => error = failure);
        if (failure.code == 'PARENT_GATE_REQUIRED') widget.reverify();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() => run(() async {
    final value = await widget.api.listChildren();
    if (mounted) setState(() => children = value);
  });
  Future<void> choose(ChildSummary child) => run(() async {
    setState(() {
      detail = null;
      activity = null;
    });
    final value = await widget.api.getChild(child.id);
    if (value.id != child.id || value.dateOfBirth == null)
      throw const ApiInvalidResponse('Invalid protected child detail.');
    if (mounted) setState(() => detail = value);
  });
  @override
  Widget build(BuildContext context) => Frame(
    title: 'Authorized Parent Area',
    back: busy ? null : widget.home,
    children: [
      const Text(
        'R0 SYNTHETIC ONLY · Protected reads require the current session’s Parent Area proof. No sensitive profile edits or consent withdrawal are available.',
      ),
      if (busy)
        const LinearProgressIndicator(
          semanticsLabel: 'Loading authorized Parent information',
        ),
      GateError(error),
      if (info != null) Text(info!),
      if (!protected && error == null)
        const LinearProgressIndicator(
          semanticsLabel: 'Protecting Parent information',
        ),
      if (protected && children.isEmpty && !busy)
        const Text('No child profiles returned.'),
      for (final child in children)
        OutlinedButton(
          key: Key('gated-child-${child.id}'),
          onPressed: busy ? null : () => choose(child),
          child: Text('View protected profile: ${child.alias}'),
        ),
      if (detail != null) ...[
        Text(
          'Protected profile: ${detail!.alias}',
          key: const Key('protectedChildAlias'),
        ),
        Text(
          'Date of birth: ${dateText(detail!.dateOfBirth!)}',
          key: const Key('protectedChildDob'),
        ),
        Text('Age returned by service: ${detail!.ageYears}'),
        for (final decision in detail!.recordedDecisions)
          Text('${decision.purposeCode}: ${decision.recordedState}'),
        OutlinedButton(
          key: const Key('loadParentActivity'),
          onPressed: busy
              ? null
              : () => run(() async {
                  final value = await widget.gate.parentActivity(detail!.id);
                  if (mounted) setState(() => activity = value);
                }),
          child: const Text('Read authorized session history'),
        ),
        if (activity != null && activity!.isEmpty)
          const Text('No sessions returned.'),
        if (activity != null)
          for (final item in activity!)
            Card(
              child: ListTile(
                title: Text('${item.lessonTitle} · ${item.state}'),
                subtitle: Text(
                  'Session: ${item.sessionId}\nStarted: ${item.startedAt.toUtc().toIso8601String()}${item.endedAt == null ? '' : '\nEnded: ${item.endedAt!.toUtc().toIso8601String()}'}',
                ),
              ),
            ),
      ],
      OutlinedButton(
        key: const Key('gateChangePin'),
        onPressed: busy ? null : widget.changePin,
        child: const Text('Change PIN with password reauthentication'),
      ),
      OutlinedButton(
        key: const Key('gateResetPin'),
        onPressed: busy ? null : widget.resetPin,
        child: const Text('Reset PIN with password reauthentication'),
      ),
      OutlinedButton(
        key: const Key('revokeOtherDevices'),
        onPressed: busy
            ? null
            : () => run(() async {
                final count = await widget.gate.revokeOtherDevices();
                if (mounted)
                  setState(
                    () => info = 'Other device sessions revoked: $count',
                  );
              }),
        child: const Text('Sign out other device sessions'),
      ),
      TextButton(
        key: const Key('gatedParentHome'),
        onPressed: busy ? null : widget.home,
        child: const Text('Back to basic child selection'),
      ),
    ],
  );
}
