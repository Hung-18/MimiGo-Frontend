// Opt-in real HTTP boundary probe. Malformed input only: never sends email,
// creates an account, redeems a code or changes any credential.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'PUBLIC_STAGING recovery availability and legal boundaries',
    () async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      try {
        for (final path in ['request', 'confirm']) {
          final request = await client.postUrl(
            Uri.parse(
              'https://mimigo-api-staging.onrender.com/api/v1/auth/password-reset/$path',
            ),
          );
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode({'email': 'invalid-address'}));
          final response = await request.close().timeout(
            const Duration(seconds: 60),
          );
          final body = await utf8.decoder.bind(response).join();
          String? code;
          try {
            code = (jsonDecode(body) as Map)['code'] as String?;
          } catch (_) {
            /* Disabled routes may have an empty 404. */
          }
          // Status/code only; never print responses, account data or credentials.
          // ignore: avoid_print
          print(
            'RECOVERY_$path status=${response.statusCode} code=${code ?? "none"}',
          );
          expect([400, 404, 429, 503], contains(response.statusCode));
          if (response.statusCode == 400)
            expect(['INVALID_EMAIL', 'INVALID_RESET_CODE'], contains(code));
          if (response.statusCode == 503)
            expect([
              'CLOUD_SURFACE_LOCKED',
              'PASSWORD_RESET_UNAVAILABLE',
            ], contains(code));
        }
        final request = await client.getUrl(
          Uri.parse(
            'https://mimigo-api-staging.onrender.com/api/v1/privacy/onboarding-reference',
          ),
        );
        final response = await request.close().timeout(
          const Duration(seconds: 60),
        );
        final body =
            jsonDecode(await utf8.decoder.bind(response).join()) as Map;
        expect(response.statusCode, 200);
        // Do not print notice content. Current boundary is recorded, not consented.
        // ignore: avoid_print
        print(
          'LEGAL_REFERENCE status=${response.statusCode} keys=${body.keys.join(",")}',
        );
      } finally {
        client.close(force: true);
      }
    },
    skip: Platform.environment['MIMIGO_RUN_PUBLIC_RECOVERY_PROBE'] != 'true',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
