import 'user_messages.dart';

import 'package:flutter/material.dart';

import 'main.dart' show ChildSummary, MimiGoApi, ParentSummary, ParentWorkspace;
import 'parent_gate_api.dart';
import 'mimigo_design.dart';
import 'api_failure.dart';
import 'po/po_design.dart';
import 'parent_onboarding.dart' show OnboardingError;

/// Parent-only selection before entering Child Mode. This does not grant a
/// Parent Gate or permit returning here from a child's learning screens.
class ParentHomeState extends ChangeNotifier {
  ParentHomeState(this.api);
  final MimiGoApi api;
  List<ChildSummary> children = const [];
  ChildSummary? selected;
  ApiFailure? error;
  bool busy = false;
  Map<String, String> catalogStatuses = const {};
  Map<String, String?> learningEntryStatuses = const {};
  String? disclaimer;
  int _generation = 0;
  bool get canEnter {
    final child = selected;
    final childContextAvailable =
        api is ParentGateApi && (api as ParentGateApi).parentGateEnabled;
    // Parent workspace counts Free only. Paid age-out Core is checked only
    // by the Child-context catalog; entering a context grants no lesson.
    final checkCoreInChildContext =
        childContextAvailable &&
        catalogStatuses[child?.id] == 'CHILD_OUTSIDE_PROGRAM_AGE' &&
        learningEntryStatuses[child?.id] == 'CHILD_OUTSIDE_PROGRAM_AGE';
    return !busy &&
        child != null &&
        child.state == 'ACTIVE' &&
        (checkCoreInChildContext ||
            (child.withinProgramAgeRange &&
                {
                  'AVAILABLE',
                  'NO_ELIGIBLE_CONTENT',
                }.contains(catalogStatuses[child.id]) &&
                {
                  'READY',
                  'NO_ELIGIBLE_CONTENT',
                }.contains(learningEntryStatuses[child.id])));
  }

  void seed(List<ChildSummary> profiles) {
    children = List.unmodifiable(profiles);
  }

  void seedWorkspace(ParentWorkspace workspace) {
    seed(workspace.children.map((item) => item.child).toList());
    catalogStatuses = Map.unmodifiable({
      for (final item in workspace.children) item.child.id: item.catalogStatus,
    });
    learningEntryStatuses = Map.unmodifiable({
      for (final item in workspace.children)
        item.child.id: item.learningEntryStatus,
    });
    disclaimer = workspace.disclaimer;
  }

  Future<void> refresh() async {
    if (busy) return;
    final generation = _generation;
    busy = true;
    error = null;
    selected = null;
    children = const [];
    catalogStatuses = const {};
    learningEntryStatuses = const {};
    disclaimer = null;
    notifyListeners();
    try {
      final value = await api.learningWorkspace();
      if (generation == _generation) seedWorkspace(value);
    } on ApiFailure catch (failure) {
      if (generation == _generation) {
        error = failure;
        children = const [];
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> choose(String id) async {
    if (busy || !children.any((child) => child.id == id)) return;
    final generation = _generation;
    busy = true;
    error = null;
    selected = null;
    notifyListeners();
    try {
      final gated =
          api is ParentGateApi && (api as ParentGateApi).parentGateEnabled;
      final value = gated
          ? children.firstWhere((child) => child.id == id)
          : await api.getChild(id);
      if (value.id != id)
        throw const ApiInvalidResponse(
          'The service returned a different child profile.',
        );
      if (generation == _generation) selected = value;
    } on ApiFailure catch (failure) {
      if (generation == _generation) error = failure;
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void clearSelection() {
    if (busy) return;
    selected = null;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}

class ParentHome extends StatefulWidget {
  const ParentHome({
    super.key,
    required this.api,
    required this.parent,
    required this.children,
    required this.add,
    required this.enterChild,
    required this.accountEntry,
    required this.fixture,
    this.workspace,
    this.resumeOnboarding,
    this.openParentArea,
    this.setupPin,
  });
  final MimiGoApi api;
  final ParentSummary parent;
  final List<ChildSummary> children;
  final VoidCallback add, accountEntry;
  final ValueChanged<ChildSummary> enterChild;
  final bool fixture;
  final ParentWorkspace? workspace;
  final VoidCallback? resumeOnboarding;
  final VoidCallback? openParentArea, setupPin;
  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
  late final model = ParentHomeState(widget.api)..seed(widget.children);
  bool leaving = false;
  @override
  void initState() {
    super.initState();
    if (widget.workspace != null)
      model.seedWorkspace(widget.workspace!);
    else
      model.refresh();
  }

  String availability(String? status) => switch (status) {
    'AVAILABLE' => 'Có bài học miễn phí phù hợp',
    'NO_ELIGIBLE_CONTENT' => 'Chưa có bài học phù hợp',
    'CHILD_OUTSIDE_PROGRAM_AGE' => 'Ngoài độ tuổi của chương trình',
    'PERMISSION_NOT_GRANTED' => 'Chưa được phép xem bài học',
    'CHILD_NOT_ACTIVE' => 'Hồ sơ bé chưa hoạt động',
    _ => 'Tải lại để kiểm tra bài học',
  };
  String entryAvailability(String? status) => switch (status) {
    'READY' => 'Có thể vào không gian của bé',
    'PERMISSION_NOT_GRANTED' => 'Bé hiện chưa được phép vào học',
    'CHILD_NOT_ACTIVE' => 'Hồ sơ bé chưa hoạt động nên chưa thể vào học',
    'CHILD_OUTSIDE_PROGRAM_AGE' =>
      'Bài học sẽ được kiểm tra theo độ tuổi và quyền của bé',
    'NO_ELIGIBLE_CONTENT' =>
      'Chưa có bài phù hợp; bé vẫn có thể mở góc khám phá',
    _ => 'Tải lại để kiểm tra quyền học trước khi tiếp tục',
  };
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) {
      final child = model.selected;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PoGarden(
            title: 'Cùng con lớn lên,\nmỗi ngày một chút',
            subtitle: 'Chọn một không gian học tập cho bé.',
            compact: true,
          ),
          Text(
            'Chào ${widget.parent.displayName}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (widget.fixture)
            const Text(
              'Dữ liệu mẫu · Không lưu kết quả lên máy chủ.',
              style: TextStyle(fontSize: 13),
            ),
          const Text(
            'Ba mẹ chọn một hồ sơ để bé bắt đầu nhé. Thông tin riêng tư và lịch sử học được bảo vệ bằng PIN.',
          ),
          const SizedBox(height: 16),
          if (model.busy)
            const LinearProgressIndicator(semanticsLabel: 'Đang tải hồ sơ bé'),
          if (model.error != null) OnboardingError(model.error!),
          if (child == null) ...[
            Semantics(
              header: true,
              child: Text(
                'Các bé của ba mẹ',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (model.children.isEmpty && !model.busy && model.error == null)
              const Text(
                'Ba mẹ có thể thêm hồ sơ đầu tiên sau khi xem thông tin về quyền riêng tư.',
              ),
            if (model.children.isEmpty && !model.busy && model.error == null)
              const Text('Chưa có hồ sơ bé.', key: Key('parentChildrenEmpty')),
            ...model.children.map(
              (profile) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PoCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  onTap: model.busy || leaving
                      ? null
                      : () => model.choose(profile.id),
                  child: ListTile(
                    key: Key('parent-child-${profile.id}'),
                    minVerticalPadding: 16,
                    title: Text(profile.alias),
                    leading: MimiAvatar(stockKey: profile.stockAvatarKey),
                    subtitle: Text(
                      '${viState(profile.state)}\n'
                      '${profile.withinProgramAgeRange ? '' : 'Ngoài độ tuổi của chương trình\n'}'
                      '${availability(model.catalogStatuses[profile.id])}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
            ),
          ] else ...[
            MimiNotice(
              icon: Icons.person_outline,
              color: MimiColors.rose,
              child: Semantics(
                header: true,
                child: Text(
                  'Đã chọn: ${child.alias}',
                  key: const Key('parentSelectedChild'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Text(viState(child.state)),
            Text(
              child.withinProgramAgeRange
                  ? 'Bài học sẽ được kiểm tra theo tuổi và quyền của bé.'
                  : 'Bé đang ngoài độ tuổi thông thường của chương trình. Nội dung theo gói đã mua, nếu có, sẽ được kiểm tra khi vào học.',
            ),
            Text(
              availability(model.catalogStatuses[child.id]),
              key: const Key('parentCatalogAvailability'),
            ),
            Text(
              entryAvailability(model.learningEntryStatuses[child.id]),
              key: const Key('parentLearningEntry'),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: FilledButton(
                key: const Key('parentEnterLearning'),
                onPressed: !model.canEnter || leaving
                    ? null
                    : () {
                        if (leaving) return;
                        setState(() => leaving = true);
                        widget.enterChild(child);
                      },
                child: const Text('Vào không gian của bé'),
              ),
            ),
            OutlinedButton(
              key: const Key('parentChooseAnother'),
              onPressed: model.busy || leaving ? null : model.clearSelection,
              child: const Text('Chọn bé khác'),
            ),
            const Text(
              'Ba mẹ có thể quản lý thông tin được hỗ trợ trong phần cài đặt có PIN.',
            ),
          ],
          const SizedBox(height: 16),
          if (widget.openParentArea != null) ...[
            const PoHeading(
              'Dành cho ba mẹ',
              subtitle: 'Thông tin riêng tư được bảo vệ bằng PIN.',
            ),
            Text('Mã PIN: ${viState(widget.parent.parentGate?.status)}'),
            OutlinedButton(
              key: const Key('openParentArea'),
              onPressed: model.busy || leaving ? null : widget.openParentArea,
              child: const Text('Cài đặt và thông tin riêng tư'),
            ),
            OutlinedButton(
              key: const Key('manageParentPin'),
              onPressed: model.busy || leaving ? null : widget.setupPin,
              child: Text(
                widget.parent.parentGate?.status == 'NOT_ENROLLED'
                    ? 'Thiết lập mã PIN'
                    : 'Đặt lại mã PIN',
              ),
            ),
          ],
          OutlinedButton(
            key: const Key('parentRefresh'),
            onPressed: model.busy || leaving ? null : model.refresh,
            child: const Text('Tải lại danh sách bé'),
          ),
          if (!widget.parent.currentTermsAccepted)
            const Text(
              'Nếu điều khoản đã thay đổi, ba mẹ sẽ cần xem lại trước khi thêm hồ sơ.',
            ),
          FilledButton(
            key: const Key('addChild'),
            onPressed: !model.busy && !leaving ? widget.add : null,
            child: Text(
              model.children.isEmpty
                  ? 'Thêm hồ sơ bé đầu tiên'
                  : 'Thêm hồ sơ bé',
            ),
          ),
          if (widget.resumeOnboarding != null)
            OutlinedButton(
              key: const Key('parentResumeOnboarding'),
              onPressed: model.busy || leaving ? null : widget.resumeOnboarding,
              child: const Text('Kiểm tra hồ sơ đang tạo'),
            ),
          TextButton(
            key: const Key('parentAccountEntry'),
            onPressed: model.busy || leaving ? null : widget.accountEntry,
            child: const Text('Về màn hình tài khoản'),
          ),
        ],
      );
    },
  );
}
