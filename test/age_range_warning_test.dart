import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/child_onboarding.dart';

import 'child_onboarding_test.dart'
    show ChildApi, openChildOnboarding, affirmNotices, reviewChild;
import 'learning_widget_test.dart' show tapVisible;

String iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  group('dobOutsideProgramAge (band 2..6 completed years)', () {
    final today = DateTime(2026, 11, 16);
    test('exactly the 2nd birthday is inside', () {
      expect(dobOutsideProgramAge(DateTime(2024, 11, 16), today), isFalse);
    });
    test('the day before the 2nd birthday is still age 1 -> outside', () {
      expect(dobOutsideProgramAge(DateTime(2024, 11, 17), today), isTrue);
    });
    test('the day before the 7th birthday is still age 6 -> inside', () {
      expect(dobOutsideProgramAge(DateTime(2019, 11, 17), today), isFalse);
    });
    test('exactly the 7th birthday is outside', () {
      expect(dobOutsideProgramAge(DateTime(2019, 11, 16), today), isTrue);
    });
    test('PO case: 15/11/2018 is 8 years -> outside', () {
      expect(dobOutsideProgramAge(DateTime(2018, 11, 15), today), isTrue);
    });
    test('a future date is outside (and is rejected earlier by the form)', () {
      expect(dobOutsideProgramAge(DateTime(2027, 1, 1), today), isTrue);
      expect(acceptableChildDob(DateTime(2027, 1, 1), today), isFalse);
    });
  });

  testWidgets('8-year-old: warning shows, "Sửa ngày sinh" sends nothing', (
    tester,
  ) async {
    final api = ChildApi();
    await openChildOnboarding(tester, api);
    await affirmNotices(tester);
    final t = vietnamToday();
    await reviewChild(tester, dob: iso(DateTime(t.year - 8, t.month, 1)));
    await tapVisible(tester, 'createChild');
    expect(find.byKey(const Key('ageRangeWarning')), findsOneWidget);
    expect(api.requests, isEmpty);
    await tester.tap(find.byKey(const Key('ageWarningEditDob')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ageRangeWarning')), findsNothing);
    expect(api.requests, isEmpty);
    expect(find.byKey(const Key('childDob')), findsOneWidget);
  });

  testWidgets('8-year-old: "Vẫn tạo hồ sơ" still creates the profile', (
    tester,
  ) async {
    final api = ChildApi()
      ..reportedAge = 8
      ..eligible = false;
    await openChildOnboarding(tester, api);
    await affirmNotices(tester);
    final t = vietnamToday();
    await reviewChild(tester, dob: iso(DateTime(t.year - 8, t.month, 1)));
    await tapVisible(tester, 'createChild');
    await tester.tap(find.byKey(const Key('ageWarningCreateAnyway')));
    await tester.pumpAndSettle();
    expect(api.requests, hasLength(1));
    expect(find.byType(ChildCreated), findsOneWidget);
    expect(find.textContaining('ngoài độ tuổi thông thường'), findsOneWidget);
  });

  testWidgets('in-range child (3 years): no warning, created directly', (
    tester,
  ) async {
    final api = ChildApi();
    await openChildOnboarding(tester, api);
    await affirmNotices(tester);
    final t = vietnamToday();
    await reviewChild(tester, dob: iso(DateTime(t.year - 3, t.month, 1)));
    await tapVisible(tester, 'createChild');
    expect(find.byKey(const Key('ageRangeWarning')), findsNothing);
    expect(api.requests, hasLength(1));
    expect(find.byType(ChildCreated), findsOneWidget);
  });
}
