import 'user_messages.dart';

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
    'CHILD_NOTICE_NOT_APPROVED',
    'NICKNAME_MUST_NOT_IDENTIFY',
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
          (child.dateOfBirth != null &&
              dateText(child.dateOfBirth!) != dateText(request.dateOfBirth)) ||
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

/// Pilot nickname shape; server validation remains authoritative.
bool acceptableChildNickname(String value) {
  final alias = value.trim();
  return alias.isNotEmpty &&
      alias.length <= 30 &&
      !RegExp(
        r'[@/\\<>]|[0-9]{5,}|(https?:|www\.)',
        caseSensitive: false,
      ).hasMatch(alias);
}

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
          'Đã tạo hồ sơ: ${child.alias}',
          key: const Key('createdChildAlias'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      const Text(
        'Hồ sơ đã được lưu. Ba mẹ chọn hồ sơ trước khi bé vào học nhé.',
      ),
      if (child.ageYears != null) Text('${child.ageYears} tuổi'),
      Text(viState(child.state)),
      Text(
        child.withinProgramAgeRange
            ? 'Bé đang trong độ tuổi của chương trình. Bài học phù hợp sẽ được kiểm tra khi vào học.'
            : 'Bé đang ngoài độ tuổi thông thường của chương trình. Ba mẹ có thể xem thông tin hồ sơ ở góc phụ huynh.',
        key: const Key('createdChildEligibility'),
      ),
      if (child.stockAvatarKey != null) const Text('Đã lưu ảnh đại diện'),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: FilledButton(
          key: const Key('createdParentHome'),
          onPressed: parentHome,
          child: const Text('Chọn hồ sơ trong góc phụ huynh'),
        ),
      ),
      OutlinedButton(
        key: const Key('createdAddAnother'),
        onPressed: addAnother,
        child: const Text('Thêm hồ sơ bé khác'),
      ),
      const Text(
        'Ba mẹ chọn hồ sơ trước khi bé vào học. Mỗi bé cần được xem xét thông tin riêng.',
      ),
    ],
  );
}
