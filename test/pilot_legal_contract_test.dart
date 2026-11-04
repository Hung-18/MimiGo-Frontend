import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';

import 'learning_api_test.dart' show Transport, Reply, authenticated;
import 'design_test_support.dart' show visualApp;

// Deliberately test-only content. Never bundled as runtime legal authority.
Map<String, dynamic> legalSnapshot({bool approved = true}) {
  const body =
      '# Nội dung kiểm thử\nChỉ dùng trong kiểm thử, không phải văn bản pháp lý.';
  final hash = sha256.convert(utf8.encode(body)).toString();
  return {
    'termsVersionId': 'legal-terms-v1',
    'code': 'ACCOUNT_TERMS_V1',
    'contentHash': hash,
    'effectiveFrom': '2026-01-01T00:00:00Z',
    'isApprovedForRealUsers': approved,
    if (approved)
      'document': <String, dynamic>{
        'title': 'Văn bản kiểm thử',
        'language': 'vi',
        'format': 'text/markdown',
        'body': body,
        'contentHash': hash,
      },
  };
}

Map<String, dynamic> legalNotice({bool approved = true}) =>
    {
        ...legalSnapshot(approved: approved),
        'purposeCode': 'CHILD_PROFILE_AGE',
        'noticeVersionId': 'notice-v1',
        'versionLabel': 'NOTICE_V1',
      }
      ..remove('termsVersionId')
      ..remove('code');

Map<String, dynamic> legalReference({
  Map<String, dynamic>? terms,
  List<Object?>? notices,
}) => {
  'terms': terms ?? legalSnapshot(),
  'purposes': [
    {'purposeCode': 'CHILD_PROFILE_AGE', 'isCoreForChild': true},
  ],
  'currentNotices': notices ?? [legalNotice()],
  'disclaimer': 'Test reference only.',
};

Future<OnboardingReference> parseReference(Map<String, dynamic> json) {
  final transport = Transport()..replies.add(Reply(json));
  return LiveMimiGoApi(
    Uri.parse('https://unit.invalid/api/v1'),
    client: transport,
  ).onboardingReference();
}

void main() {
  test(
    'approved Terms and Privacy Notice are version-bound real HTTP models',
    () async {
      final ref = await parseReference(legalReference());
      expect(ref.terms!.hasApprovedDocument, isTrue);
      expect(ref.terms!.document!.versionId, ref.terms!.id);
      expect(ref.notices.single.hasApprovedDocument, isTrue);
      expect(
        ref.notices.single.document!.versionId,
        ref.notices.single.versionId,
      );
    },
  );
  test('unapproved and absent documents remain unavailable without rejecting metadata', () async {
    final ref = await parseReference(
      legalReference(
        terms: legalSnapshot(approved: false),
        notices: [legalNotice(approved: false)],
      ),
    );
    expect(ref.terms!.hasApprovedDocument, isFalse);
    expect(ref.notices.single.hasApprovedDocument, isFalse);
    final approvedWithoutBody = legalSnapshot()..remove('document');
    expect(
      (await parseReference(legalReference(terms: approvedWithoutBody)))
          .terms!
          .hasApprovedDocument,
      isFalse,
    );
  });
  test(
    'old Terms metadata with no approval property stays safely unavailable',
    () async {
      final old = legalSnapshot(approved: false)
        ..remove('isApprovedForRealUsers');
      expect(
        (await parseReference(legalReference(terms: old)))
            .terms!
            .hasApprovedDocument,
        isFalse,
      );
    },
  );
  for (final part in ['terms', 'notice']) {
    for (final defect in [
      'approval',
      'missingTitle',
      'blankBody',
      'format',
      'language',
      'hash',
      'body',
      'shape',
    ]) {
      test('$part rejects malformed/mismatched legal $defect', () async {
        final snapshot = part == 'terms' ? legalSnapshot() : legalNotice();
        final doc = snapshot['document'] as Map<String, dynamic>;
        switch (defect) {
          case 'approval':
            snapshot['isApprovedForRealUsers'] = false;
          case 'missingTitle':
            doc.remove('title');
          case 'blankBody':
            doc['body'] = '  ';
          case 'format':
            doc['format'] = 'text/html';
          case 'language':
            doc['language'] = 17;
          case 'hash':
            doc['contentHash'] = 'b' * 64;
          case 'body':
            doc['body'] = '${doc['body']} altered';
          case 'shape':
            snapshot['document'] = 'invalid';
        }
        await expectLater(
          parseReference(
            legalReference(
              terms: part == 'terms' ? snapshot : null,
              notices: part == 'notice' ? [snapshot] : null,
            ),
          ),
          throwsA(isA<ApiInvalidResponse>()),
        );
      });
    }
  }
  test('CRLF normalization matches the authoritative UTF-8 hash', () async {
    final snapshot = legalSnapshot();
    final doc = snapshot['document'] as Map<String, dynamic>;
    doc['body'] = (doc['body'] as String).replaceAll('\n', '\r\n');
    expect(
      (await parseReference(legalReference(terms: snapshot)))
          .terms!
          .hasApprovedDocument,
      isTrue,
    );
  });
  test(
    'duplicate notices remain rejected, including approved documents',
    () async {
      await expectLater(
        parseReference(legalReference(notices: [legalNotice(), legalNotice()])),
        throwsA(isA<ApiInvalidResponse>()),
      );
    },
  );
  test('attempt and resume parse approved notice documents without fabricating absent text', () async {
    final snapshot = {
      'attemptId': 'attempt-v1',
      'expiresAt': '2030-01-01T00:00:00Z',
      'notices': [legalNotice()],
    };
    final transport = Transport()..replies.add(Reply(snapshot));
    final api = await authenticated(transport);
    expect(
      (await api.beginOnboardingAttempt()).notices.single.hasApprovedDocument,
      isTrue,
    );
    final status = OnboardingAttemptStatus.fromJson({
      ...snapshot,
      'status': 'OPEN',
      'childId': null,
    });
    expect(status.attempt.notices.single.hasApprovedDocument, isTrue);
    (snapshot['notices'] as List).single.remove('document');
    transport.replies.add(Reply(snapshot));
    expect(
      (await api.beginOnboardingAttempt()).notices.single.hasApprovedDocument,
      isFalse,
    );
  });
  testWidgets(
    'parsed approved document is readable and agreement starts unchecked',
    (t) async {
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
      expect(find.text(reference.terms!.document!.body), findsOneWidget);
      expect(find.byKey(const Key('registerEmail')), findsOneWidget);
      final checkbox = t.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, isFalse);
      expect(checkbox.onChanged, isNotNull);
    },
  );
}
