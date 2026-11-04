import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/account_availability.dart';
import 'package:mimigo_frontend/parent_gate_screens.dart';
import 'package:mimigo_frontend/terms_reacceptance.dart';
import 'package:mimigo_frontend/user_messages.dart';
import 'package:mimigo_frontend/po/po_design.dart';

import 'design_test_support.dart';

class MetadataOnlyApi extends FixtureMimiGoApi {
  int registrations = 0, acceptances = 0;
  @override
  Future<OnboardingReference> onboardingReference() async =>
      OnboardingReference(
        TermsReference(
          'metadata-version',
          'R0_MOCK_TERMS_V1',
          contentHash: 'metadata-hash',
          effectiveFrom: DateTime(2026),
        ),
        const [],
        const [],
        'PRIVATE DEVELOPER NOTICE',
      );
  @override
  Future<RegistrationResult> register(Registration value) async {
    registrations++;
    return super.register(value);
  }

  @override
  Future<TermsAcceptance> acceptCurrentTerms(
    String version, {
    required bool termsAccepted,
  }) async {
    acceptances++;
    return super.acceptCurrentTerms(version, termsAccepted: termsAccepted);
  }
}

Future<void> publicCapture(WidgetTester t, String name) async {
  expect(find.byType(GatePinScreen), findsNothing);
  expect(find.byType(GatedParentArea), findsNothing);
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('viPublicCapture')),
    );
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('reports/evidence/vi_cleanup/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Widget publicApp(Widget child) => MaterialApp(
  theme: poTheme(),
  home: RepaintBoundary(
    key: const Key('viPublicCapture'),
    child: Scaffold(body: SafeArea(child: child)),
  ),
);
void main() {
  setUpAll(loadDesignFonts);
  test('metadata, mock code, empty content and mismatched versions never authorize Terms', () {
    const doc = ApprovedLegalDocument(
      versionId: 'v1',
      contentHash: 'hash',
      title: 'Điều khoản',
      body: 'Nội dung kiểm thử.',
      approved: true,
    );
    for (final ref in [
      const TermsReference(
        'v1',
        'R0_MOCK_TERMS_V1',
        contentHash: 'hash',
        document: doc,
      ),
      const TermsReference(
        'v2',
        'ACCOUNT_TERMS',
        contentHash: 'hash',
        document: doc,
      ),
      const TermsReference(
        'v1',
        'ACCOUNT_TERMS',
        contentHash: 'different',
        document: doc,
      ),
      const TermsReference('v1', 'ACCOUNT_TERMS', contentHash: 'hash'),
    ]) {
      expect(ref.hasApprovedDocument, isFalse);
    }
    expect(
      const TermsReference(
        'v1',
        'ACCOUNT_TERMS',
        contentHash: 'hash',
        document: doc,
      ).hasApprovedDocument,
      isTrue,
    );
  });
  testWidgets(
    'registration with actual metadata shape is unavailable and cannot submit consent',
    (t) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final api = MetadataOnlyApi();
      final ref = await api.onboardingReference();
      await t.pumpWidget(
        publicApp(
          Register(
            reference: ref,
            live: true,
            back: () {},
            submitted: api.register,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const Key('registrationTermsUnavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('R0_MOCK_TERMS_V1'), findsNothing);
      expect(find.textContaining('PRIVATE DEVELOPER'), findsNothing);
      expect(
        t
            .widget<CheckboxListTile>(find.byKey(const Key('termsCheckbox')))
            .onChanged,
        isNull,
      );
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('registerSubmit')))
            .onPressed,
        isNull,
      );
      expect(api.registrations, 0);
      await publicCapture(t, 'registration_unavailable');
      expect(t.takeException(), isNull);
    },
  );
  test('Terms re-acceptance rejects choices and POST when approved content is absent', () async {
    final api = MetadataOnlyApi();
    final state = TermsReacceptanceState(api, 'parent');
    addTearDown(state.dispose);
    await state.load();
    state.choose(true);
    expect(state.agreed, isFalse);
    expect(await state.accept(), isNull);
    expect(api.acceptances, 0);
    expect(state.error?.code, 'TERMS_DOCUMENT_UNAVAILABLE');
  });
  testWidgets('unapproved child notice cannot collect consent or reach DOB', (
    t,
  ) async {
    final notice = Notice(
      'CHILD_PROFILE_AGE',
      'v',
      'R0_MOCK_NOTICE',
      isApprovedForRealUsers: false,
    );
    await t.pumpWidget(
      publicApp(
        Privacy(
          attempt: OnboardingAttempt('known', DateTime(2030), [notice]),
          begin: () async {},
          declined: () {},
          next: () {
            fail('Unapproved notice must not advance.');
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('noticeDocumentUnavailable')), findsOneWidget);
    expect(
      t
          .widget<CheckboxListTile>(find.byKey(const Key('guardianAssertion')))
          .onChanged,
      isNull,
    );
    expect(
      t
          .widget<CheckboxListTile>(
            find.byKey(const Key('consent-CHILD_PROFILE_AGE')),
          )
          .onChanged,
      isNull,
    );
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('privacyContinue')))
          .onPressed,
      isNull,
    );
    expect(find.byKey(const Key('childDob')), findsNothing);
  });
  testWidgets(
    'friendly errors hide codes and request IDs until details are explicitly opened',
    (t) async {
      await t.pumpWidget(
        publicApp(
          const Padding(
            padding: EdgeInsets.all(20),
            child: UserError(
              ApiFailure(
                'PRIVATE password or server text',
                code: 'DB_UNAVAILABLE',
                status: 503,
                requestId: 'support-request',
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('tạm gián đoạn'), findsOneWidget);
      expect(find.textContaining('DB_UNAVAILABLE'), findsNothing);
      expect(find.textContaining('support-request'), findsNothing);
      expect(find.textContaining('PRIVATE'), findsNothing);
      await t.tap(find.text('Chi tiết kỹ thuật'));
      await t.pumpAndSettle();
      expect(find.textContaining('DB_UNAVAILABLE'), findsOneWidget);
      expect(find.textContaining('support-request'), findsOneWidget);
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'error detail expansion does not collide with persisted scroll offset',
    (t) async {
      final failure = ValueNotifier<ApiFailure?>(null);
      addTearDown(failure.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: failure,
            builder: (c, e, _) => PoScaffold(
              title: 'Kiểm tra',
              preview: false,
              children: [const SizedBox(height: 900), UserError(e)],
            ),
          ),
        ),
      );
      await t.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await t.pumpAndSettle();
      failure.value = const ApiFailure('private', code: 'CONNECTIVITY');
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.text('Chi tiết kỹ thuật'));
      await t.tap(find.text('Chi tiết kỹ thuật'));
      await t.pumpAndSettle();
      expect(find.textContaining('CONNECTIVITY'), findsOneWidget);
      failure.value = const ApiFailure('private', code: 'INVALID_RESPONSE');
      await t.pumpAndSettle();
      expect(find.textContaining('INVALID_RESPONSE'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'normal welcome, validation and recovery use Vietnamese with no test identity',
    (t) async {
      await t.pumpWidget(
        MimiGoApp(
          api: MetadataOnlyApi(),
          configuration: const ApiConfiguration(ApiMode.live, 'unused'),
        ),
      );
      await t.pumpAndSettle();
      final welcome = find.byKey(const Key('welcomeSignIn'));
      expect(Localizations.localeOf(t.element(welcome)).languageCode, 'vi');
      await t.ensureVisible(welcome);
      await t.tap(welcome);
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('signInEmail')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.textContaining('Staging'), findsNothing);
      expect(find.textContaining('@example.test'), findsNothing);
      await t.ensureVisible(find.byKey(const Key('signInSubmit')));
      await t.tap(find.byKey(const Key('signInSubmit')));
      await t.pumpAndSettle();
      expect(find.text('Vui lòng nhập địa chỉ email hợp lệ.'), findsOneWidget);
      await t.ensureVisible(find.text('Quên mật khẩu?'));
      await t.tap(find.text('Quên mật khẩu?'));
      await t.pumpAndSettle();
      expect(
        find.text(AccountAvailability.passwordRecoveryMessage),
        findsOneWidget,
      );
    },
  );
}
