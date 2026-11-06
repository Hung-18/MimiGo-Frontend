import 'user_messages.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart'
    show MimiGoApi, ChildSummary, ChildDetail, ParentSummary, Frame;
import 'po/po_design.dart';
import 'api_failure.dart';
import 'parent_gate_api.dart';
import 'parent_gate_session.dart';
import 'gate_screen_security.dart';
import 'po/mobile_services.dart';
import 'po/premium_panel.dart';
import 'po/profile_panel.dart';

String gateFailureText(ApiFailure failure) => friendlyError(failure);

class GateError extends StatelessWidget {
  const GateError(this.error, {super.key});
  final ApiFailure? error;
  @override
  Widget build(BuildContext context) =>
      UserError(error, messageKey: const Key('gateError'));
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
              ? 'Nhập PIN của ba mẹ'
              : 'Nhập PIN để bé vào học'
        : switch (widget.pinAction!) {
            PinAction.enroll => 'Thiết lập mã PIN',
            PinAction.change => 'Đổi mã PIN',
            PinAction.reset => 'Đặt lại mã PIN',
          };
    return Frame(
      title: title,
      back: busy || leaving ? null : widget.back,
      children: [
        const Text(
          'Mã PIN giúp bảo vệ thông tin của gia đình. Ba mẹ không chia sẻ mã này với bé nhé.',
        ),
        if (!protected) ...[
          if (error == null)
            const LinearProgressIndicator(
              semanticsLabel: 'Đang bảo vệ màn hình PIN',
            ),
          GateError(error),
        ],
        if (protected) ...[
          if (widget.pinAction != null) ...[
            const Text('Ba mẹ nhập mật khẩu để xác nhận việc đổi mã PIN.'),
            secret(password, 'gatePassword', 'Mật khẩu của ba mẹ'),
            const SizedBox(height: 12),
          ],
          secret(
            pin,
            'gatePin',
            widget.pinAction == null
                ? 'Mã PIN 6 chữ số'
                : 'Mã PIN mới gồm 6 chữ số',
            digits: true,
          ),
          if (widget.pinAction != null) ...[
            const SizedBox(height: 12),
            secret(
              confirmation,
              'gatePinConfirmation',
              'Nhập lại PIN mới',
              digits: true,
            ),
          ],
          if (busy)
            const LinearProgressIndicator(semanticsLabel: 'Đang xác minh'),
          GateError(error),
          if (waitSeconds > 0)
            Semantics(
              liveRegion: true,
              child: Text(
                'Vui lòng thử lại sau $waitSeconds giây.',
                key: const Key('gateRetryAfter'),
              ),
            ),
          if (recoveryRequired)
            const Text(
              'Ba mẹ cần đăng xuất, đăng nhập lại rồi dùng mật khẩu để đặt lại PIN.',
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
                    ? 'Đang chờ xác nhận…'
                    : widget.pinAction == null
                    ? 'Xác nhận PIN'
                    : 'Xác nhận và lưu PIN',
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
                  ? 'Quên PIN? Đăng xuất để đặt lại'
                  : 'Quên PIN hoặc cần thiết lập PIN?',
            ),
          ),
        TextButton(
          key: const Key('gateAccountEntry'),
          onPressed: leaving ? null : widget.accountEntry,
          child: const Text('Đăng xuất và về màn hình đăng nhập'),
        ),
      ],
    );
  }
}

class GatedParentArea extends StatefulWidget {
  const GatedParentArea({
    super.key,
    this.parent,
    required this.api,
    required this.gate,
    required this.home,
    required this.reverify,
    required this.changePin,
    required this.resetPin,
  });
  final MimiGoApi api;
  final ParentSummary? parent;
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
  bool showPremium = false, showProfileEdit = false;
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
    setState(() {
      children = [];
      detail = null;
      activity = null;
    });
    final value = await widget.api.listChildren();
    if (mounted) setState(() => children = value);
  });
  Future<void> choose(ChildSummary child) => run(() async {
    setState(() {
      showPremium = false;
      showProfileEdit = false;
      detail = null;
      activity = null;
    });
    final value = await widget.api.getChild(child.id);
    if (value.id != child.id)
      throw const ApiInvalidResponse('Invalid protected child detail.');
    if (mounted) setState(() => detail = value);
  });
  @override
  Widget build(BuildContext context) => Frame(
    title: 'Cài đặt của ba mẹ',
    back: busy ? null : widget.home,
    children: [
      const Text(
        'Thông tin riêng tư được bảo vệ bằng PIN. Một số thay đổi hiện chưa được hỗ trợ.',
      ),
      if (busy)
        const LinearProgressIndicator(
          semanticsLabel: 'Đang tải thông tin của ba mẹ',
        ),
      GateError(error),
      if (info != null) Text(info!),
      if (!protected && error == null)
        const LinearProgressIndicator(semanticsLabel: 'Đang bảo vệ thông tin'),
      if (protected && children.isEmpty && !busy && error == null)
        const Text('Chưa có hồ sơ bé.'),
      if (protected)
        if (widget.parent != null)
          PoCard(
            color: PoPalette.mint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PoHeading('Tài khoản phụ huynh'),
                Text(widget.parent!.displayName),
                Text(widget.parent!.email),
                const Text(
                  'Thay đổi email hoặc thông tin tài khoản chưa được dịch vụ hỗ trợ.',
                ),
              ],
            ),
          ),
      if (protected)
        OutlinedButton(
          key: const Key('gatedRefresh'),
          onPressed: busy ? null : load,
          child: const Text('Tải lại danh sách bé được phép xem'),
        ),
      for (final child in children)
        OutlinedButton(
          key: Key('gated-child-${child.id}'),
          onPressed: busy ? null : () => choose(child),
          child: Text('Xem hồ sơ: ${child.alias}'),
        ),
      if (detail != null) ...[
        if (widget.api is MobileCapabilities)
          OutlinedButton(
            onPressed: busy
                ? null
                : () => setState(() => showProfileEdit = !showProfileEdit),
            child: const Text('Chỉnh tên gọi & ảnh đại diện'),
          ),
        if (showProfileEdit && widget.api is MobileCapabilities)
          ProfilePanel(
            key: ValueKey('profile-${detail!.id}'),
            service: (widget.api as MobileCapabilities).profiles,
            childId: detail!.id,
          ),
        if (widget.api is MobileCapabilities)
          OutlinedButton(
            onPressed: busy
                ? null
                : () => setState(() => showPremium = !showPremium),
            child: const Text('Gói học & quyền Premium Core'),
          ),
        if (showPremium && widget.api is MobileCapabilities)
          PremiumPanel(
            key: ValueKey(detail!.id),
            service: (widget.api as MobileCapabilities).premium,
            childId: detail!.id,
          ),
        Text('Hồ sơ: ${detail!.alias}', key: const Key('protectedChildAlias')),
        if (detail!.dateOfBirth != null)
          Text(
            'Ngày sinh: ${viDate(detail!.dateOfBirth!)}',
            key: const Key('protectedChildDob'),
          ),
        if (detail!.ageYears != null) Text('${detail!.ageYears} tuổi'),
        for (final decision in detail!.recordedDecisions)
          Text(
            '${viPurpose(decision.purposeCode)}: ${viState(decision.recordedState)}',
          ),
        OutlinedButton(
          key: const Key('loadParentActivity'),
          onPressed: busy
              ? null
              : () => run(() async {
                  // Never leave a previous history result looking current
                  // while a new protected read is pending or has failed.
                  setState(() => activity = null);
                  final value = await widget.gate.parentActivity(detail!.id);
                  if (mounted) setState(() => activity = value);
                }),
          child: const Text('Xem lịch sử học được phép truy cập'),
        ),
        if (activity != null && activity!.isEmpty)
          const Text('Chưa có phiên học được máy chủ trả về.'),
        if (activity != null)
          const Text(
            'Các lượt học gần đây đã được lưu. Hiển thị tối đa 20 lượt.',
          ),
        if (activity != null)
          for (final item in activity!)
            Card(
              child: ListTile(
                title: Text(
                  '${item.lessonTitle == 'Content unavailable' ? 'Nội dung chưa khả dụng' : item.lessonTitle} · ${viState(item.state)}',
                ),
                subtitle: Text(
                  'Bắt đầu: ${viTime(item.startedAt)}${item.endedAt == null ? '' : '\nKết thúc: ${viTime(item.endedAt)}'}',
                ),
              ),
            ),
      ],
      OutlinedButton(
        key: const Key('gateChangePin'),
        onPressed: busy ? null : widget.changePin,
        child: const Text('Đổi PIN bằng mật khẩu'),
      ),
      OutlinedButton(
        key: const Key('gateResetPin'),
        onPressed: busy ? null : widget.resetPin,
        child: const Text('Đặt lại PIN bằng mật khẩu'),
      ),
      OutlinedButton(
        key: const Key('revokeOtherDevices'),
        onPressed: busy
            ? null
            : () => run(() async {
                final count = await widget.gate.revokeOtherDevices();
                if (mounted)
                  setState(
                    () =>
                        info = 'Đã đăng xuất $count phiên trên thiết bị khác.',
                  );
              }),
        child: const Text('Đăng xuất các thiết bị khác'),
      ),
      TextButton(
        key: const Key('gatedParentHome'),
        onPressed: busy ? null : widget.home,
        child: const Text('Về danh sách bé'),
      ),
    ],
  );
}
