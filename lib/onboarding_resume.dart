import 'user_messages.dart';

import 'package:flutter/material.dart';

import 'main.dart' show MimiGoApi, OnboardingAttempt, OnboardingAttemptStatus;
import 'api_failure.dart';
import 'parent_onboarding.dart';

class OnboardingResumeState extends ChangeNotifier {
  OnboardingResumeState(this.api, this.attemptId);
  final MimiGoApi api;
  final String attemptId;
  OnboardingAttemptStatus? snapshot;
  ApiFailure? error;
  bool busy = false;
  int _generation = 0;
  bool get denied =>
      {401, 403}.contains(error?.status) ||
      snapshot?.status == 'PARENT_NOT_ACTIVE';

  Future<void> load() async {
    if (busy) return;
    final generation = _generation;
    busy = true;
    snapshot = null;
    error = null;
    notifyListeners();
    try {
      final value = await api.getOnboardingAttempt(attemptId);
      if (generation != _generation) return;
      if (value.attempt.id != attemptId)
        throw const ApiInvalidResponse(
          'A different onboarding attempt was returned.',
        );
      snapshot = value;
    } on ApiFailure catch (failure) {
      if (generation == _generation) error = failure;
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}

class OnboardingAttemptResume extends StatefulWidget {
  const OnboardingAttemptResume({
    super.key,
    required this.api,
    required this.attemptId,
    required this.hasPendingCreation,
    required this.resume,
    required this.consumed,
    required this.termsRequired,
    required this.restart,
    required this.parentHome,
    required this.accountEntry,
  });
  final MimiGoApi api;
  final String attemptId;
  final bool hasPendingCreation;
  final ValueChanged<OnboardingAttempt> resume;
  final VoidCallback consumed, termsRequired, restart, parentHome, accountEntry;
  @override
  State<OnboardingAttemptResume> createState() =>
      _OnboardingAttemptResumeState();
}

class _OnboardingAttemptResumeState extends State<OnboardingAttemptResume> {
  late final model = OnboardingResumeState(widget.api, widget.attemptId);
  bool leaving = false;
  @override
  void initState() {
    super.initState();
    model.load();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  void leave(VoidCallback action) {
    if (leaving || model.busy) return;
    setState(() => leaving = true);
    action();
  }

  String explanation(String status) => switch (status) {
    'OPEN' =>
      widget.hasPendingCreation
          ? 'Lượt tạo hồ sơ còn mở. Nếu đã gửi thông tin, ba mẹ chỉ gửi lại đúng yêu cầu cũ để tránh trùng hồ sơ.'
          : 'Ba mẹ xem lại thông báo và lựa chọn từng mục đích trước khi nhập hồ sơ.',
    'ATTEMPT_ALREADY_CONSUMED' =>
      'Lượt này đã tạo hồ sơ. Ba mẹ kiểm tra danh sách bé, không cần tạo lại.',
    'TERMS_ACCEPTANCE_REQUIRED' => 'Ba mẹ cần xem điều khoản hiện hành trước khi tiếp tục. Lựa chọn về thông tin của bé vẫn được xem xét riêng.',
    'PARENT_NOT_ACTIVE' =>
      'Tài khoản hiện chưa thể tiếp tục. Ba mẹ vui lòng đăng nhập lại.',
    _ => 'Lượt này chưa thể tiếp tục. Ba mẹ bắt đầu xem xét lại thông báo trước khi nhập hồ sơ.',
  };

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) {
      final snapshot = model.snapshot;
      final status = snapshot?.status;
      final locked = model.busy || leaving;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Kiểm tra để biết yêu cầu tạo hồ sơ đã có kết quả hay chưa.',
          ),
          const Text(
            'Ba mẹ có thể kiểm tra lượt tạo hồ sơ đang thực hiện ở đây.',
          ),
          if (model.busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Đang kiểm tra hồ sơ đang tạo',
            ),
          OnboardingError(model.error),
          if (snapshot != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                'Tình trạng: ${viState(status)}',
                key: const Key('attemptResumeStatus'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(explanation(status!)),
            Text('Có hiệu lực đến ${viTime(snapshot.attempt.expiresAt)}'),
            if (status == 'OPEN') ...[
              for (final notice in snapshot.attempt.notices)
                Text(viPurpose(notice.purposeCode)),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: FilledButton(
                  key: const Key('resumeOpenAttempt'),
                  onPressed: locked
                      ? null
                      : () => leave(() => widget.resume(snapshot.attempt)),
                  child: Text(
                    widget.hasPendingCreation
                        ? 'Về yêu cầu đã gửi'
                        : 'Xem lại thông báo',
                  ),
                ),
              ),
            ],
            if (status == 'ATTEMPT_ALREADY_CONSUMED')
              FilledButton(
                key: const Key('resumeConsumedHome'),
                onPressed: locked ? null : () => leave(widget.consumed),
                child: const Text('Kiểm tra hồ sơ đã tạo'),
              ),
            if (status == 'TERMS_ACCEPTANCE_REQUIRED')
              FilledButton(
                key: const Key('resumeTerms'),
                onPressed: locked ? null : () => leave(widget.termsRequired),
                child: const Text('Xem điều khoản hiện hành'),
              ),
          ],
          if (!model.denied &&
              !{
                'OPEN',
                'ATTEMPT_ALREADY_CONSUMED',
                'TERMS_ACCEPTANCE_REQUIRED',
              }.contains(status) &&
              (snapshot != null || model.error?.status == 404))
            OutlinedButton(
              key: const Key('resumeNewAttempt'),
              onPressed: locked ? null : () => leave(widget.restart),
              child: const Text('Xem xét thông tin lại từ đầu'),
            ),
          OutlinedButton(
            key: const Key('reloadAttemptStatus'),
            onPressed: locked || model.denied ? null : model.load,
            child: const Text('Kiểm tra lại'),
          ),
          TextButton(
            key: const Key('resumeBack'),
            onPressed: locked ? null : () => leave(widget.parentHome),
            child: Text(
              widget.hasPendingCreation
                  ? 'Về yêu cầu đã gửi'
                  : 'Về góc phụ huynh',
            ),
          ),
          TextButton(
            key: const Key('resumeAccountEntry'),
            onPressed: leaving ? null : widget.accountEntry,
            child: const Text('Về màn hình đăng nhập'),
          ),
        ],
      );
    },
  );
}
