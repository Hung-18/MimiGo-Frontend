import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mimigo_design.dart';

/// One editable/autofill field, six decorative cells, one screen-reader target.
/// Pasting and deleting use the native text input rather than six focus nodes.
class SixDigitCodeField extends StatefulWidget {
  const SixDigitCodeField({
    super.key,
    required this.controller,
    required this.fieldKey,
    this.enabled = true,
    this.validator,
    this.label = 'Mã xác nhận 6 chữ số',
  });
  final TextEditingController controller;
  final Key fieldKey;
  final bool enabled;
  final String label;
  final String? Function(String?)? validator;
  @override
  State<SixDigitCodeField> createState() => _SixDigitCodeFieldState();
}

class _SixDigitCodeFieldState extends State<SixDigitCodeField> {
  final focus = FocusNode();
  @override
  void initState() {
    super.initState();
    focus.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    focus.removeListener(changed);
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = math.max(
      64.0,
      MediaQuery.textScalerOf(context).scale(26) * 1.3 + 36,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Stack(
          children: [
            Semantics(
              label: widget.label,
              child: TextFormField(
                key: widget.fieldKey,
                controller: widget.controller,
                focusNode: focus,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.3,
                  color: Colors.transparent,
                ),
                cursorColor: Colors.transparent,
                decoration: InputDecoration(
                  semanticCounterText: widget.label,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                validator: widget.validator,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: height,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, _) => Row(
                      children: [
                        for (var i = 0; i < 6; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: widget.enabled
                                    ? Colors.white
                                    : MimiColors.canvas,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color:
                                      focus.hasFocus &&
                                          i == value.text.length.clamp(0, 5)
                                      ? MimiColors.action
                                      : MimiColors.border,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                i < value.text.length ? value.text[i] : '',
                                style: const TextStyle(
                                  fontSize: 26,
                                  height: 1.3,
                                  color: MimiColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Expiry is informational: resend ACCEPTED does not supply a new expiry and
/// must never start a fabricated validity period. The server checks the code.
class CodeExpiry extends StatefulWidget {
  const CodeExpiry({
    super.key,
    required this.expiresAt,
    this.now = DateTime.now,
  });
  final DateTime expiresAt;
  final DateTime Function() now;
  @override
  State<CodeExpiry> createState() => _CodeExpiryState();
}

class _CodeExpiryState extends State<CodeExpiry> with WidgetsBindingObserver {
  Timer? timer;
  void tick() {
    if (mounted) setState(() {});
  }

  void start() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      tick();
      if (!widget.expiresAt.isAfter(widget.now())) timer?.cancel();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    start();
  }

  @override
  void didUpdateWidget(CodeExpiry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expiresAt != oldWidget.expiresAt) start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      tick();
      start();
    } else {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds =
        (widget.expiresAt.difference(widget.now()).inMilliseconds / 1000)
            .ceil()
            .clamp(0, 86400);
    final duration =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Text(
      seconds > 0
          ? 'Mã ban đầu còn hiệu lực: $duration'
          : 'Mã ban đầu đã hết hạn. Ba mẹ có thể yêu cầu gửi lại mã.',
      key: const Key('codeExpiry'),
      style: TextStyle(
        color: seconds > 0 ? MimiColors.blueText : MimiColors.action,
      ),
    );
  }
}
