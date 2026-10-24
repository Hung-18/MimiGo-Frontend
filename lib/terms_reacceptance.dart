import 'package:flutter/material.dart';

import 'main.dart' show MimiGoApi, TermsReference, ParentSummary;
import 'api_failure.dart';

class TermsReacceptanceState extends ChangeNotifier {
  TermsReacceptanceState(this.api, this.parentId);
  final MimiGoApi api;
  final String parentId;
  TermsReference? terms;
  String? disclaimer;
  ApiFailure? error;
  bool agreed = false, busy = false;
  int _generation = 0;
  bool get denied => {401, 403}.contains(error?.status);

  Future<void> load() async {
    if (busy) return;
    final generation = _generation;
    busy = true;
    agreed = false;
    terms = null;
    error = null;
    notifyListeners();
    try {
      final reference = await api.onboardingReference();
      if (generation != _generation) return;
      final current = reference.terms;
      if (current == null ||
          current.id.isEmpty ||
          current.code.isEmpty ||
          current.contentHash == null ||
          current.effectiveFrom == null)
        throw const ApiInvalidResponse(
          'The service did not supply the current Terms version metadata.',
        );
      terms = current;
      disclaimer = reference.disclaimer;
    } on ApiFailure catch (failure) {
      if (generation == _generation) error = failure;
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void choose(bool value) {
    if (busy || denied || terms == null) return;
    agreed = value;
    notifyListeners();
  }

  Future<ParentSummary?> accept() async {
    if (busy || !agreed || terms == null || denied) return null;
    final generation = _generation;
    final version = terms!;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.acceptCurrentTerms(
        version.id,
        termsAccepted: true,
      );
      if (generation != _generation) return null;
      if (result.id != version.id ||
          result.code != version.code ||
          !result.currentTermsAccepted)
        throw const ApiInvalidResponse(
          'The service did not confirm acceptance of this Terms version.',
        );
      final parent = await api.parentMe();
      if (generation != _generation) return null;
      if (parent.parentId != parentId)
        throw const ApiInvalidResponse(
          'The authenticated parent changed. Return to account entry.',
        );
      if (!parent.currentTermsAccepted)
        throw const ApiFailure(
          'Current Terms changed. Reload and review them.',
          code: 'TERMS_VERSION_NOT_CURRENT',
          status: 422,
        );
      return parent;
    } on ApiFailure catch (failure) {
      if (generation == _generation) {
        error = failure;
        if (failure.code == 'TERMS_VERSION_NOT_CURRENT') {
          terms = null;
          agreed = false;
        }
      }
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

/// Reached only from an authenticated Parent operation returning
/// TERMS_ACCEPTANCE_REQUIRED. It neither creates nor grants child consent.
class TermsReacceptance extends StatefulWidget {
  const TermsReacceptance({
    super.key,
    required this.api,
    required this.parentId,
    required this.accepted,
    required this.cancel,
    required this.accountEntry,
  });
  final MimiGoApi api;
  final String parentId;
  final ValueChanged<ParentSummary> accepted;
  final VoidCallback cancel, accountEntry;
  @override
  State<TermsReacceptance> createState() => _TermsReacceptanceState();
}

class _TermsReacceptanceState extends State<TermsReacceptance> {
  late final model = TermsReacceptanceState(widget.api, widget.parentId);
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

  Future<void> accept() async {
    if (leaving) return;
    final parent = await model.accept();
    if (mounted && parent != null && !leaving) {
      setState(() => leaving = true);
      widget.accepted(parent);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) {
      final terms = model.terms;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'DEVELOPMENT / DEMO · account Terms, separate from child consent.',
          ),
          const Text(
            'The service requires current account Terms before continuing this parent operation. Acceptance will not create a child or grant child purposes.',
          ),
          if (model.busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Checking current account Terms',
            ),
          if (terms != null) ...[
            Semantics(
              header: true,
              child: Text(
                'Current Terms: ${terms.code}',
                key: const Key('currentTermsVersion'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text('Version ID: ${terms.id}'),
            Text(
              'Effective: ${terms.effectiveFrom!.toUtc().toIso8601String()}',
            ),
            Text('Content hash: ${terms.contentHash}'),
            const Text(
              'This R0 API provides mock version metadata, not the full Terms document. No legal text is invented here; this flow is for synthetic development testing only.',
            ),
            if (model.disclaimer != null) Text(model.disclaimer!),
            CheckboxListTile(
              key: const Key('reacceptTermsCheckbox'),
              contentPadding: EdgeInsets.zero,
              value: model.agreed,
              onChanged: model.busy || model.denied || leaving
                  ? null
                  : (value) => model.choose(value ?? false),
              title: Text(
                'I explicitly accept account Terms ${terms.code} for this synthetic account.',
              ),
            ),
          ],
          if (model.error != null) _TermsError(model.error!),
          if (model.error?.code == 'TERMS_VERSION_NOT_CURRENT')
            const Text(
              'The version changed. Reload current Terms and make a new explicit choice.',
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: FilledButton(
              key: const Key('reacceptTermsSubmit'),
              onPressed:
                  model.busy ||
                      !model.agreed ||
                      model.denied ||
                      terms == null ||
                      leaving
                  ? null
                  : accept,
              child: Text(
                model.busy
                    ? 'Waiting for service…'
                    : 'Accept current account Terms',
              ),
            ),
          ),
          OutlinedButton(
            key: const Key('reloadCurrentTerms'),
            onPressed: model.busy || leaving || model.denied
                ? null
                : model.load,
            child: const Text('Reload current Terms'),
          ),
          TextButton(
            key: const Key('cancelTerms'),
            onPressed: model.busy || leaving ? null : widget.cancel,
            child: const Text('Cancel and return to Parent Home'),
          ),
          TextButton(
            key: const Key('termsAccountEntry'),
            onPressed: leaving ? null : widget.accountEntry,
            child: const Text('Return to account entry'),
          ),
        ],
      );
    },
  );
}

class _TermsError extends StatelessWidget {
  const _TermsError(this.failure);
  final ApiFailure failure;

  String get message {
    if (failure.status == 401)
      return 'Your parent sign-in expired. Return to account entry and sign in again.';
    if (failure.status == 403)
      return 'This parent account cannot continue. Return to account entry.';
    if (failure.code == 'TERMS_VERSION_NOT_CURRENT')
      return 'The service requires a different Terms version. Reload current Terms.';
    if (failure.code == 'CONNECTIVITY' || failure.code == 'TIMEOUT')
      return 'We could not reach the account service. Check your connection and try again.';
    if ((failure.status ?? 0) >= 500)
      return 'The account service is temporarily unavailable. Please try again later.';
    if (failure is ApiInvalidResponse) return failure.message;
    return 'Account Terms acceptance could not be confirmed. Reload or try again.';
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        '$message\n${failure.code ?? 'REQUEST_FAILED'}'
        '${failure.requestId == null ? '' : '\nRequest: ${failure.requestId}'}',
        key: const Key('termsError'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}
