import 'package:flutter/material.dart';

import 'main.dart'
    show ChildDetail, ChildSummary, MimiGoApi, ParentSummary, ParentWorkspace;
import 'parent_gate_api.dart';
import 'mimigo_design.dart';
import 'api_failure.dart';
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
    return !busy &&
        child != null &&
        child.state == 'ACTIVE' &&
        child.withinProgramAgeRange &&
        {
          'AVAILABLE',
          'NO_ELIGIBLE_CONTENT',
        }.contains(catalogStatuses[child.id]) &&
        {
          'READY',
          'NO_ELIGIBLE_CONTENT',
        }.contains(learningEntryStatuses[child.id]);
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
    'AVAILABLE' => 'Eligible Free lessons available',
    'NO_ELIGIBLE_CONTENT' => 'No eligible lessons returned',
    'CHILD_OUTSIDE_PROGRAM_AGE' => 'Outside program age range',
    'PERMISSION_NOT_GRANTED' => 'Catalog permission is not granted',
    'CHILD_NOT_ACTIVE' => 'Child profile is not active',
    _ => 'Refresh to check catalog availability',
  };
  String entryAvailability(String? status) => switch (status) {
    'READY' => 'Learning entry ready · service eligibility checked',
    'PERMISSION_NOT_GRANTED' =>
      'Learning entry is not permitted by the service',
    'CHILD_NOT_ACTIVE' => 'Learning entry unavailable · child is not active',
    'CHILD_OUTSIDE_PROGRAM_AGE' =>
      'Learning entry unavailable · outside program age',
    'NO_ELIGIBLE_CONTENT' =>
      'No eligible learning content · Child Mode can show empty discovery',
    _ => 'Learning entry unknown · refresh before entering',
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
          Text(
            'Welcome, ${widget.parent.displayName}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            widget.fixture
                ? 'DEMO / FIXTURE parent account'
                : 'DEVELOPMENT / DEMO · authenticated parent account',
          ),
          Text(
            widget.openParentArea == null
                ? 'Choose a child before entering Child Mode. Returning from Child Mode requires a fresh parent sign-in; Parent Gate is not available.'
                : 'Basic child roster only. Entering Child Mode needs a child-bound PIN verification. Protected Parent details require a Parent Area proof.',
          ),
          const SizedBox(height: 16),
          if (model.busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Loading child profile',
            ),
          if (model.error != null) OnboardingError(model.error!),
          if (model.disclaimer != null) Text(model.disclaimer!),
          Text(
            widget.openParentArea == null
                ? 'Learning activity is unavailable until Parent Gate is approved. No session history or progress is shown here.'
                : 'No protected profile details or learning activity are displayed in this basic roster.',
          ),
          if (child == null) ...[
            Semantics(
              header: true,
              child: Text(
                'Your children',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (model.children.isEmpty && !model.busy && model.error == null)
              const Text(
                'Your parent account is ready. Add your first synthetic child after independent privacy review.',
              ),
            if (model.children.isEmpty && !model.busy && model.error == null)
              const Text(
                'No child profiles returned.',
                key: Key('parentChildrenEmpty'),
              ),
            ...model.children.map(
              (profile) => Card(
                child: ListTile(
                  key: Key('parent-child-${profile.id}'),
                  minVerticalPadding: 16,
                  title: Text(profile.alias),
                  leading: MimiAvatar(stockKey: profile.stockAvatarKey),
                  subtitle: Text(
                    '${widget.openParentArea == null ? 'Profile: ${profile.state} · Age returned by service: ${profile.ageYears}' : 'Profile: ${profile.state}'}\n'
                    '${profile.withinProgramAgeRange ? 'Within program age range' : 'Outside program age range · profile only'}\n'
                    '${availability(model.catalogStatuses[profile.id])}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: model.busy || leaving
                      ? null
                      : () => model.choose(profile.id),
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
                  'Selected child: ${child.alias}',
                  key: const Key('parentSelectedChild'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Text(
              widget.openParentArea == null
                  ? 'Profile: ${child.state} · Age returned by service: ${child.ageYears}'
                  : 'Profile: ${child.state}',
            ),
            Text(
              child.withinProgramAgeRange
                  ? 'Lesson eligibility is checked by the service when you explore.'
                  : 'The service reports this child outside the program age range. No learning access is granted here.',
            ),
            if (child is ChildDetail && widget.openParentArea == null)
              Text(child.disclaimer),
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
                child: const Text('Enter Child Mode'),
              ),
            ),
            OutlinedButton(
              key: const Key('parentChooseAnother'),
              onPressed: model.busy || leaving ? null : model.clearSelection,
              child: const Text('Choose another child'),
            ),
            const Text(
              'Profile editing and sensitive account changes are not available. No PIN or step-up authorization is simulated.',
            ),
          ],
          const SizedBox(height: 16),
          if (widget.openParentArea != null) ...[
            Text(
              'Parent PIN status: ${widget.parent.parentGate?.status ?? 'UNAVAILABLE'}',
            ),
            OutlinedButton(
              key: const Key('openParentArea'),
              onPressed: model.busy || leaving ? null : widget.openParentArea,
              child: const Text('Open Parent Area with PIN'),
            ),
            OutlinedButton(
              key: const Key('manageParentPin'),
              onPressed: model.busy || leaving ? null : widget.setupPin,
              child: Text(
                widget.parent.parentGate?.status == 'NOT_ENROLLED'
                    ? 'Set up Parent PIN with password'
                    : 'Reset PIN with password',
              ),
            ),
          ],
          OutlinedButton(
            key: const Key('parentRefresh'),
            onPressed: model.busy || leaving ? null : model.refresh,
            child: const Text('Refresh child profiles'),
          ),
          if (!widget.parent.currentTermsAccepted)
            const Text(
              'Adding a child checks the current account Terms. Explicit acceptance will be requested only if the service requires it.',
            ),
          FilledButton(
            key: const Key('addChild'),
            onPressed: !model.busy && !leaving ? widget.add : null,
            child: Text(
              model.children.isEmpty
                  ? 'Add your first child'
                  : 'Add another child',
            ),
          ),
          if (widget.resumeOnboarding != null)
            OutlinedButton(
              key: const Key('parentResumeOnboarding'),
              onPressed: model.busy || leaving ? null : widget.resumeOnboarding,
              child: const Text(
                'Check pending child onboarding · this app session',
              ),
            ),
          TextButton(
            key: const Key('parentAccountEntry'),
            onPressed: model.busy || leaving ? null : widget.accountEntry,
            child: const Text('Return to account entry'),
          ),
        ],
      );
    },
  );
}
