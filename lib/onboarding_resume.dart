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
          ? 'The service reports this attempt open. Your original submitted request stays locked. Return to review and retry that identical request; this read does not prove a delayed request cannot finish.'
          : 'This attempt is open. Review its notice snapshot again and make fresh, independent choices before entering synthetic profile information.',
    'ATTEMPT_ALREADY_CONSUMED' => 'This attempt already created a child profile. Check your authorized roster in Parent Home. No second child will be created from this attempt.',
    'TERMS_ACCEPTANCE_REQUIRED' => 'The service requires current account Terms. Accept them explicitly, then start a new privacy review. Child purposes remain separate.',
    'PARENT_NOT_ACTIVE' =>
      'This parent account cannot continue. Return to account entry.',
    _ => 'This attempt cannot continue. Start a new attempt and review fresh notices; no old choices or profile draft will be reused.',
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
            'R0 SYNTHETIC ONLY · read-only attempt check. It does not consume the attempt, extend its expiry, grant consent or create a child.',
          ),
          const Text(
            'Only an attempt known during this signed-in app session can be checked. No child draft or attempt identifier is persisted on this device.',
          ),
          if (model.busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Checking onboarding attempt',
            ),
          OnboardingError(model.error),
          if (snapshot != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                'Attempt status: $status',
                key: const Key('attemptResumeStatus'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(explanation(status!)),
            Text(
              'Original expiry: ${snapshot.attempt.expiresAt.toUtc().toIso8601String()}',
            ),
            if (status == 'OPEN') ...[
              for (final notice in snapshot.attempt.notices)
                Text(
                  '${notice.purposeCode} · ${notice.label} · ${notice.versionId}',
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: FilledButton(
                  key: const Key('resumeOpenAttempt'),
                  onPressed: locked
                      ? null
                      : () => leave(() => widget.resume(snapshot.attempt)),
                  child: Text(
                    widget.hasPendingCreation
                        ? 'Return to identical creation request'
                        : 'Review these notices again',
                  ),
                ),
              ),
            ],
            if (status == 'ATTEMPT_ALREADY_CONSUMED')
              FilledButton(
                key: const Key('resumeConsumedHome'),
                onPressed: locked ? null : () => leave(widget.consumed),
                child: const Text('Check created profile in Parent Home'),
              ),
            if (status == 'TERMS_ACCEPTANCE_REQUIRED')
              FilledButton(
                key: const Key('resumeTerms'),
                onPressed: locked ? null : () => leave(widget.termsRequired),
                child: const Text('Review current account Terms'),
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
              child: const Text('Start fresh privacy review'),
            ),
          OutlinedButton(
            key: const Key('reloadAttemptStatus'),
            onPressed: locked || model.denied ? null : model.load,
            child: const Text('Check status again'),
          ),
          TextButton(
            key: const Key('resumeBack'),
            onPressed: locked ? null : () => leave(widget.parentHome),
            child: Text(
              widget.hasPendingCreation
                  ? 'Back to original creation request'
                  : 'Back to Parent Home',
            ),
          ),
          TextButton(
            key: const Key('resumeAccountEntry'),
            onPressed: leaving ? null : widget.accountEntry,
            child: const Text('Return to account entry'),
          ),
        ],
      );
    },
  );
}
