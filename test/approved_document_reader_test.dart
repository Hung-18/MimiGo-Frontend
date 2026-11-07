import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/approved_document_reader.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/mimigo_design.dart';

import 'child_onboarding_test.dart' show noticeSnapshot;
import 'design_test_support.dart' show visualApp;
import 'learning_widget_test.dart' show tapVisible;
import 'pilot_legal_contract_test.dart' show parseReference, legalReference;

void main() {
  Future<void> openRegister(WidgetTester t) async {
    final reference = await parseReference(legalReference());
    await t.pumpWidget(
      visualApp(
        Register(
          reference: reference,
          fixture: false,
          live: true,
          back: () {},
          submitted: (_) async {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await tapVisible(t, 'registrationReadTerms');
  }

  testWidgets(
    'reader starts unchecked, renders full text and explicitly agrees',
    (t) async {
      await openRegister(t);
      expect(find.byKey(const Key('legalFullText')), findsOneWidget);
      expect(
        t
            .widget<CheckboxListTile>(
              find.byKey(const Key('legalExplicitChoice')),
            )
            .value,
        isFalse,
      );
      expect(
        t.widget<FilledButton>(find.byKey(const Key('legalAgree'))).onPressed,
        isNull,
      );
      await t.tap(find.byKey(const Key('legalExplicitChoice')));
      await t.pump();
      await t.tap(find.byKey(const Key('legalAgree')));
      await t.pumpAndSettle();
      expect(
        t
            .widget<CheckboxListTile>(find.byKey(const Key('termsCheckbox')))
            .value,
        isTrue,
      );
    },
  );
  testWidgets(
    'Disagree clears acceptance; closing does not accept; reopening is unchecked',
    (t) async {
      await openRegister(t);
      await t.tap(find.byKey(const Key('legalClose')));
      await t.pumpAndSettle();
      expect(
        t
            .widget<CheckboxListTile>(find.byKey(const Key('termsCheckbox')))
            .value,
        isFalse,
      );
      await tapVisible(t, 'termsCheckbox');
      await tapVisible(t, 'registrationReadTerms');
      expect(
        t
            .widget<CheckboxListTile>(
              find.byKey(const Key('legalExplicitChoice')),
            )
            .value,
        isFalse,
      );
      await t.tap(find.byKey(const Key('legalDisagree')));
      await t.pumpAndSettle();
      expect(
        t
            .widget<CheckboxListTile>(find.byKey(const Key('termsCheckbox')))
            .value,
        isFalse,
      );
    },
  );
  testWidgets(
    'notice agreement is independent and does not affirm guardian or sibling purposes',
    (t) async {
      await t.pumpWidget(
        visualApp(
          Privacy(
            attempt: OnboardingAttempt(
              'attempt',
              DateTime(2030),
              noticeSnapshot(),
            ),
            begin: () async {},
            declined: () {},
            next: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      await tapVisible(t, 'noticeRead-CHILD_PROFILE_AGE');
      await t.tap(find.byKey(const Key('legalExplicitChoice')));
      await t.pump();
      await t.tap(find.byKey(const Key('legalAgree')));
      await t.pumpAndSettle();
      expect(
        t
            .widget<CheckboxListTile>(
              find.byKey(const Key('consent-CHILD_PROFILE_AGE')),
            )
            .value,
        isTrue,
      );
      expect(
        t
            .widget<CheckboxListTile>(
              find.byKey(const Key('consent-LEARNING_PROGRESS')),
            )
            .value,
        isFalse,
      );
      expect(
        t
            .widget<CheckboxListTile>(
              find.byKey(const Key('guardianAssertion')),
            )
            .value,
        isFalse,
      );
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('privacyContinue')))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets('child purpose checkbox opens its full notice before agreement', (t) async {
    await t.pumpWidget(
      visualApp(
        Privacy(
          attempt: OnboardingAttempt('attempt', DateTime(2030), noticeSnapshot()),
          begin: () async {},
          declined: () {},
          next: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await tapVisible(t, 'consent-CHILD_PROFILE_AGE');
    expect(find.byKey(const Key('legalFullText')), findsOneWidget);
    await t.tap(find.byKey(const Key('legalClose')));
    await t.pumpAndSettle();
    expect(
      t.widget<CheckboxListTile>(
        find.byKey(const Key('consent-CHILD_PROFILE_AGE')),
      ).value,
      isFalse,
    );
    await tapVisible(t, 'consent-CHILD_PROFILE_AGE');
    await t.tap(find.byKey(const Key('legalExplicitChoice')));
    await t.pump();
    await t.tap(find.byKey(const Key('legalAgree')));
    await t.pumpAndSettle();
    expect(
      t.widget<CheckboxListTile>(
        find.byKey(const Key('consent-CHILD_PROFILE_AGE')),
      ).value,
      isTrue,
    );
  });
  testWidgets('fixture purpose checkbox keeps its direct demo choice', (t) async {
    await t.pumpWidget(
      visualApp(
        Privacy(
          attempt: OnboardingAttempt('fixture-attempt', DateTime(2030), noticeSnapshot()),
          begin: () async {},
          declined: () {},
          next: () {},
          fixture: true,
        ),
      ),
    );
    await t.pumpAndSettle();
    await tapVisible(t, 'consent-CHILD_PROFILE_AGE');
    expect(find.byKey(const Key('legalFullText')), findsNothing);
    expect(
      t.widget<CheckboxListTile>(
        find.byKey(const Key('consent-CHILD_PROFILE_AGE')),
      ).value,
      isTrue,
    );
  });
  testWidgets(
    'an obsolete open reader cannot accept a replaced attempt snapshot',
    (t) async {
      final attempt = ValueNotifier(
        OnboardingAttempt('attempt-v1', DateTime(2030), noticeSnapshot()),
      );
      addTearDown(attempt.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: mimiTheme(),
          home: Scaffold(
            body: ValueListenableBuilder<OnboardingAttempt>(
              valueListenable: attempt,
              builder: (_, value, _) => Privacy(
                attempt: value,
                begin: () async {},
                declined: () {},
                next: () {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await tapVisible(t, 'noticeRead-CHILD_PROFILE_AGE');
      attempt.value = OnboardingAttempt(
        'attempt-v2',
        DateTime(2030),
        noticeSnapshot(),
      );
      await t.pump();
      await t.tap(find.byKey(const Key('legalExplicitChoice')));
      await t.pump();
      await t.tap(find.byKey(const Key('legalAgree')));
      await t.pumpAndSettle();
      expect(
        t
            .widget<CheckboxListTile>(
              find.byKey(const Key('consent-CHILD_PROFILE_AGE')),
            )
            .value,
        isFalse,
      );
    },
  );
  testWidgets(
    'reader respects 320dp and 200 percent text with scrollable content',
    (t) async {
      await t.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          theme: mimiTheme(),
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => readApprovedDocument(
                  c,
                  ApprovedLegalDocument(
                    versionId: 'v',
                    contentHash: 'hash',
                    title: 'Điều khoản',
                    body: List.filled(50, 'Nội dung văn bản.').join('\n'),
                    approved: true,
                  ),
                ),
                child: const Text('Read'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Read'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.byKey(const Key('legalDisagree')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('legalDisagree')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('legalFullText')), findsNothing);
    },
  );
}
