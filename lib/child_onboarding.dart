import 'package:flutter/material.dart';

import 'main.dart' show MimiGoApi, CreateChildRequest, ChildSummary, dateText;
import 'api_failure.dart';

/// One immutable creation request per review. An unknown outcome must retry
/// exactly this payload; editing never silently creates a second request.
class ChildCreationState extends ChangeNotifier {
  ChildCreationState(this.api, this.request);
  final MimiGoApi api;
  final CreateChildRequest request;
  ChildSummary? result;
  ApiFailure? error;
  bool busy = false, sent = false;
  int _generation = 0;
  bool get canEdit => !sent && !busy;
  bool get denied => {401, 403}.contains(error?.status);
  bool get needsNotices => {
    'ATTEMPT_EXPIRED',
    'ATTEMPT_NOT_FOUND',
    'NOTICE_CHANGED_REDISPLAY_REQUIRED',
    'CORE_PERMISSION_REQUIRED',
    'INVALID_CHILD_ALIAS',
    'SYNTHETIC_ALIAS_REQUIRED',
    'DATE_OF_BIRTH_REQUIRED',
    'INVALID_DATE_OF_BIRTH',
    'INVALID_AVATAR',
  }.contains(error?.code);
  bool get conflict => {
    'ATTEMPT_ALREADY_CONSUMED',
    'IDEMPOTENCY_CONFLICT',
  }.contains(error?.code);
  bool get canSubmit =>
      !busy &&
      result == null &&
      !denied &&
      !needsNotices &&
      !conflict &&
      error?.code != 'TERMS_ACCEPTANCE_REQUIRED';

  Future<ChildSummary?> submit() async {
    if (!canSubmit) return null;
    final generation = _generation;
    busy = sent = true;
    error = null;
    notifyListeners();
    try {
      final child = await api.createChild(request);
      if (generation != _generation) return null;
      if (child.id.isEmpty ||
          child.alias != request.childAlias ||
          dateText(child.dateOfBirth) != dateText(request.dateOfBirth) ||
          child.stockAvatarKey != request.stockAvatarKey)
        throw const ApiInvalidResponse(
          'Created child does not match the submitted profile.',
        );
      result = child;
      return child;
    } on ApiFailure catch (failure) {
      if (generation == _generation) error = failure;
      return null;
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

/// Matches the documented Asia/Ho_Chi_Minh date boundary; the server still
/// computes age/eligibility. No age is submitted by the client.
DateTime vietnamToday([DateTime? now]) {
  final local = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  return DateTime(local.year, local.month, local.day);
}

bool acceptableChildDob(DateTime date, DateTime today) =>
    !date.isBefore(DateTime(1900, 1, 1)) && date.isBefore(today);

class ChildCreated extends StatelessWidget {
  const ChildCreated({
    super.key,
    required this.child,
    required this.parentHome,
    required this.addAnother,
  });
  final ChildSummary child;
  final VoidCallback parentHome, addAnother;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(
          'Profile created: ${child.alias}',
          key: const Key('createdChildAlias'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      const Text(
        'R0 SYNTHETIC ONLY · The service confirmed profile creation with mock purpose decisions. This is not production legal consent or guardian verification.',
      ),
      Text('Age returned by service: ${child.ageYears}'),
      Text('Profile state: ${child.state}'),
      Text(
        child.withinProgramAgeRange
            ? 'The service reports this profile within the program age range. Lesson access still requires service authorization.'
            : 'The service reports this profile outside the program age range. The profile can stay in Parent Home; learning entry is unavailable.',
        key: const Key('createdChildEligibility'),
      ),
      if (child.stockAvatarKey != null)
        Text('Predefined avatar: ${child.stockAvatarKey}'),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: FilledButton(
          key: const Key('createdParentHome'),
          onPressed: parentHome,
          child: const Text('Choose a child in Parent Home'),
        ),
      ),
      OutlinedButton(
        key: const Key('createdAddAnother'),
        onPressed: addAnother,
        child: const Text('Add another child with fresh privacy choices'),
      ),
      const Text(
        'No child is automatically selected or entered. Each additional child needs independent privacy review.',
      ),
    ],
  );
}
