// Opt-in real HTTP acceptance. No credentials in source, defines or reports.
// This file never registers accounts, creates children or performs billing writes.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/parent_gate_session.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/po/mobile_services.dart';

import 'parent_gate_session_test.dart' show MemoryVault;

void main() {
  test(
    'PUBLIC_STAGING: actual client loads current onboarding reference',
    () async {
      final http = HttpClient();
      final api = LiveMimiGoApi(
        Uri.parse('https://mimigo-api-staging.onrender.com/api/v1'),
        client: http,
        parentGateEnabled: true,
        vault: MemoryVault(),
      );
      try {
        final reference = await api.onboardingReference();
        expect(reference.terms?.id, isNotEmpty);
        expect(reference.notices, isNotEmpty);
        expect(
          reference.notices.every((n) => n.isApprovedForRealUsers == false),
          isTrue,
        );
      } finally {
        api.gateSession!.dispose();
        http.close(force: true);
      }
    },
    skip: !const bool.fromEnvironment('MIMIGO_VERIFY_PUBLIC_STAGING'),
    timeout: const Timeout(Duration(seconds: 100)),
  );

  final env = Platform.environment;
  final authorized =
      env['MIMIGO_STAGING_EXISTING_ACCOUNT_AUTHORIZED'] == 'true';
  test(
    'AUTHORIZED_STAGING: existing Parent, protected history and Child catalog; optional authorized learning persistence',
    () async {
      String requiredValue(String key) {
        final value = env[key];
        if (value == null || value.isEmpty)
          fail(
            'Missing approved runtime setting $key. Do not put credentials in dart-defines.',
          );
        return value;
      }

      final email = requiredValue('MIMIGO_STAGING_TEST_EMAIL');
      final password = requiredValue('MIMIGO_STAGING_TEST_PASSWORD');
      final pin = requiredValue('MIMIGO_STAGING_TEST_PIN');
      final childId = requiredValue('MIMIGO_STAGING_TEST_CHILD_ID');
      final http = HttpClient();
      final api = LiveMimiGoApi(
        Uri.parse('https://mimigo-api-staging.onrender.com/api/v1'),
        client: http,
        parentGateEnabled: true,
        vault: MemoryVault(),
      );
      try {
        await api.login(email: email, password: password);
        final parent = await api.parentMe();
        expect(parent.parentId, api.gateSession!.current!.parentId);
        final roster = await api.listChildren();
        expect(
          roster.any((c) => c.id == childId && c.alias.startsWith('SYN-')),
          isTrue,
          reason: 'Only the explicitly authorized existing synthetic child may be used.',
        );
        await api.verifyParentArea(pin);
        await api.parentActivity(childId);
        await api.switchChildContext(pin, childId);
        expect(api.gateSession!.current!.mode, SessionMode.child);
        final catalog = await api.curriculum(childId);
        if (env['MIMIGO_STAGING_LEARNING_WRITE_AUTHORIZED'] == 'true') {
          final lessonId = requiredValue('MIMIGO_STAGING_TEST_LESSON_ID');
          expect(
            catalog.domains
                .expand((d) => d.topics)
                .expand((t) => t.lessons)
                .any((l) => l.lessonId == lessonId),
            isTrue,
            reason: 'The approved lesson must be returned by the actual Child catalog.',
          );
          final lesson = await api.lesson(childId, lessonId);
          expect(lesson.cues, isNotEmpty);
          final session = await api.startLearning(childId, lessonId);
          lesson.validateSession(session, childId);
          final before = await api.learningSession(childId, session.sessionId);
          for (final cue in lesson.cues) {
            if (before.answers.any((a) => a.cueId == cue.cueId)) continue;
            expect(cue.options, isNotEmpty);
            final request = AnswerRequest(
              clientEventId: mobileRequestKey(),
              cueId: cue.cueId,
              optionId: cue.options.first.optionId,
            );
            // Exactly one submission. Never retry an unknown outcome with a new ID.
            await api.submitAnswer(childId, session.sessionId, request);
          }
          final completed = await api.completeLearning(
            childId,
            session.sessionId,
          );
          expect(completed.state, 'COMPLETED');
          expect(completed.endedAt, isNotNull);
          final readback = await api.learningSession(
            childId,
            session.sessionId,
          );
          expect(readback.endedAt, completed.endedAt);
          // Destroy the authentication lifetime; prove history comes from the
          // server rather than LearningSessionMemory or a preview state object.
          await api.gateSession!.logout();
          await api.login(email: email, password: password);
          await api.verifyParentArea(pin);
          final history = await api.parentActivity(childId);
          expect(
            history.any(
              (h) =>
                  h.sessionId == session.sessionId &&
                  h.state == 'COMPLETED' &&
                  h.endedAt == completed.endedAt,
            ),
            isTrue,
          );
        }
      } finally {
        try {
          await api.gateSession!.logout();
        } finally {
          api.gateSession!.dispose();
          http.close(force: true);
        }
      }
    },
    skip: !authorized,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
