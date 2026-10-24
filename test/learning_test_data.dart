const childId = '11111111-1111-4111-8111-111111111111';
const lessonId = '22222222-2222-4222-8222-222222222222';
const revisionId = '33333333-3333-4333-8333-333333333333';
const sessionId = '44444444-4444-4444-8444-444444444444';
const cueId = '55555555-5555-4555-8555-555555555555';
const optionId = '66666666-6666-4666-8666-666666666666';
const otherOptionId = '77777777-7777-4777-8777-777777777777';
const eventId = '88888888-8888-4888-8888-888888888888';

// Test-only response builder; never a live client fallback.
Map<String, dynamic> curriculumJson(
  Iterable<Map<String, dynamic>> items, {
  String? emptyReason,
  String disclaimer = 'Synthetic curriculum',
}) {
  final domains = <String, Map<String, dynamic>>{};
  for (final item in items) {
    final code = item['domainCode'] as String;
    final domain = domains.putIfAbsent(
      code,
      () => {
        'domainCode': code,
        'name': code == 'MATH'
            ? 'Math'
            : code == 'ENGLISH'
            ? 'English'
            : code,
        'sortOrder': domains.length,
        'topics': <Map<String, dynamic>>[],
      },
    );
    final topics = domain['topics'] as List<Map<String, dynamic>>;
    final found = topics.where(
      (topic) => topic['topicCode'] == item['topicCode'],
    );
    final topic = found.isNotEmpty
        ? found.first
        : {
            'topicCode': item['topicCode'],
            'name': 'Topic: ${item['topicCode']}',
            'sortOrder': topics.length,
            'lessons': <Map<String, dynamic>>[],
          };
    if (found.isEmpty) topics.add(topic);
    (topic['lessons'] as List).add(item);
  }
  return {
    'domains': domains.values.toList(),
    'emptyReason': emptyReason,
    'disclaimer': disclaimer,
  };
}

Map<String, dynamic> summaryJson() => {
  'lessonId': lessonId,
  'lessonCode': 'SYN-MATH-001',
  'revisionNo': 1,
  'title': 'Synthetic Math',
  'objective': 'Synthetic question',
  'domainCode': 'MATH',
  'topicCode': 'SYN-TOPIC',
  'primarySkill': 'SYN-SKILL',
  'access': 'FREE',
};
Map<String, dynamic> detailJson() => {
  ...summaryJson(),
  'revisionId': revisionId,
  'disclaimer': 'Synthetic development only',
  'assets': [
    {
      'assetId': eventId,
      'kind': 'VIDEO',
      'role': 'MAIN_VIDEO',
      'mimeType': 'video/mp4',
      'contentHash': 'hash',
      'storageRef': 'https://not-playable.invalid/private-reference',
      'rightsStatus': 'SYNTHETIC_TEST_ONLY',
    },
  ],
  'cues': [
    {
      'cueId': cueId,
      'seq': 1,
      'pauseAtMs': 1000,
      'promptText': 'Choose an option',
      'promptAssetId': null,
      'options': [
        {'optionId': optionId, 'position': 1, 'labelText': 'Option A'},
        {'optionId': otherOptionId, 'position': 2, 'labelText': 'Option B'},
      ],
    },
  ],
};
Map<String, dynamic> sessionJson({
  List<Map<String, dynamic>> answers = const [],
}) => {
  'sessionId': sessionId,
  'childId': childId,
  'lessonId': lessonId,
  'revisionId': revisionId,
  'state': 'IN_PROGRESS',
  'startedAt': '2026-10-23T12:00:00Z',
  'lastActivityAt': '2026-10-23T12:00:00Z',
  'endedAt': null,
  'answers': answers,
};
Map<String, dynamic> feedbackJson() => {
  'answerEventId': 12,
  'sessionId': sessionId,
  'cueId': cueId,
  'optionId': optionId,
  'attemptNo': 1,
  'usedHint': false,
  'isCorrect': false,
  'feedbackText': 'Server explanation for A',
  'feedbackAssetId': null,
  'recordedAt': '2026-10-23T12:00:00Z',
};
