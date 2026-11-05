import 'package:flutter/material.dart';

import 'main.dart' show MimiGoApi, TermsReference, ParentSummary;
import 'api_failure.dart';
import 'account_availability.dart';
import 'approved_document_reader.dart';
import 'user_messages.dart';

class TermsReacceptanceState extends ChangeNotifier {
  TermsReacceptanceState(
    this.api,
    this.parentId, {
    this.allowFixtureMetadata = false,
  });
  final bool allowFixtureMetadata;
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
      if (!allowFixtureMetadata && !current.hasApprovedDocument)
        throw const ApiFailure(
          'Approved Terms unavailable.',
          code: 'TERMS_DOCUMENT_UNAVAILABLE',
        );
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
    if (busy ||
        denied ||
        terms == null ||
        (!allowFixtureMetadata && !terms!.hasApprovedDocument))
      return;
    agreed = value;
    notifyListeners();
  }

  Future<ParentSummary?> accept() async {
    if (busy ||
        !agreed ||
        terms == null ||
        denied ||
        (!allowFixtureMetadata && !terms!.hasApprovedDocument))
      return null;
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
    this.fixture = false,
    required this.api,
    required this.parentId,
    required this.accepted,
    required this.cancel,
    required this.accountEntry,
  });
  final MimiGoApi api;
  final bool fixture;
  final String parentId;
  final ValueChanged<ParentSummary> accepted;
  final VoidCallback cancel, accountEntry;
  @override
  State<TermsReacceptance> createState() => _TermsReacceptanceState();
}

class _TermsReacceptanceState extends State<TermsReacceptance> {
  late final model = TermsReacceptanceState(
    widget.api,
    widget.parentId,
    allowFixtureMetadata: widget.fixture,
  );
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
            'Ba mẹ cần xem điều khoản hiện hành trước khi tiếp tục. Đồng ý điều khoản tài khoản không thay cho lựa chọn về thông tin của bé.',
          ),
          if (model.busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Đang tải điều khoản',
            ),
          if (terms != null &&
              (terms.hasApprovedDocument || widget.fixture)) ...[
            Semantics(
              header: true,
              child: Text(
                terms.document?.title ?? 'Điều khoản sử dụng',
                key: const Key('currentTermsVersion'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (terms.document != null)
              ApprovedDocumentCard(
                document: terms.document!,
                readKey: const Key('reacceptReadTerms'),
                enabled: !model.busy && !model.denied && !leaving,
                read: () async {
                  final snapshot = terms;
                  final decision = await readApprovedDocument(
                    context,
                    snapshot.document!,
                  );
                  if (!mounted ||
                      decision == null ||
                      leaving ||
                      model.busy ||
                      model.denied)
                    return;
                  if (model.terms?.id == snapshot.id &&
                      model.terms?.contentHash == snapshot.contentHash &&
                      model.terms?.hasApprovedDocument == true)
                    model.choose(decision);
                },
              ),
            CheckboxListTile(
              key: const Key('reacceptTermsCheckbox'),
              contentPadding: EdgeInsets.zero,
              value: model.agreed,
              onChanged: model.busy || model.denied || leaving
                  ? null
                  : (value) => model.choose(value ?? false),
              title: Text('Tôi đã đọc và đồng ý với điều khoản sử dụng'),
            ),
          ],
          if (!model.busy &&
              !widget.fixture &&
              terms?.hasApprovedDocument != true)
            if (model.error?.code == 'TERMS_DOCUMENT_UNAVAILABLE')
              UserError(
                model.error,
                message: AccountAvailability.termsUnavailable,
                messageKey: const Key('termsDocumentUnavailable'),
              )
            else
              const Text(
                AccountAvailability.termsUnavailable,
                key: Key('termsDocumentUnavailable'),
              ),
          if (model.error != null &&
              model.error!.code != 'TERMS_DOCUMENT_UNAVAILABLE')
            _TermsError(model.error!),
          if (model.error?.code == 'TERMS_VERSION_NOT_CURRENT')
            const Text(
              'Điều khoản đã thay đổi. Ba mẹ tải lại và xem xét trước khi lựa chọn.',
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
                      (!widget.fixture && !terms.hasApprovedDocument) ||
                      leaving
                  ? null
                  : accept,
              child: Text(
                model.busy
                    ? 'Đang chờ xác nhận…'
                    : 'Đồng ý điều khoản hiện hành',
              ),
            ),
          ),
          OutlinedButton(
            key: const Key('reloadCurrentTerms'),
            onPressed: model.busy || leaving || model.denied
                ? null
                : model.load,
            child: const Text('Tải lại điều khoản'),
          ),
          TextButton(
            key: const Key('cancelTerms'),
            onPressed: model.busy || leaving ? null : widget.cancel,
            child: const Text('Hủy và về góc phụ huynh'),
          ),
          TextButton(
            key: const Key('termsAccountEntry'),
            onPressed: leaving ? null : widget.accountEntry,
            child: const Text('Về màn hình đăng nhập'),
          ),
        ],
      );
    },
  );
}

class _TermsError extends StatelessWidget {
  const _TermsError(this.failure);
  final ApiFailure failure;

  @override
  Widget build(BuildContext context) =>
      UserError(failure, messageKey: const Key('termsError'));
}
