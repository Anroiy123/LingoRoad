import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Page 1 manifest maps every audited PNG to a constructible state', () {
    final manifestFile = File(
      '../../docs/design/figma-reference/mobile/manifest.json',
    );
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    expect(manifest['schemaVersion'], 2);
    expect(manifest['visualAuditStatus'], 'complete');

    final frames = manifest['page1Frames'] as Map<String, dynamic>;
    expect(frames.keys.toSet(), _page1NodeIds);
    final pending = manifest['pendingGoldenBaselines'] as List<dynamic>;
    final pendingByNode = {
      for (final raw in pending)
        (raw as Map<String, dynamic>)['nodeId'] as String: raw,
    };
    expect(pendingByNode.keys.toSet(), _taskThreeGoldenByNode.keys.toSet());

    final referencedFiles = <String>{};
    for (final entry in frames.entries) {
      final mapping = entry.value as Map<String, dynamic>;
      final expectedFile = 'page-1/${entry.key.replaceAll(':', '-')}.png';
      expect(mapping['file'], expectedFile, reason: entry.key);
      referencedFiles.add(mapping['file'] as String);

      final screen = mapping['screen'];
      final state = mapping['state'];
      final route = mapping['route'];
      final status = mapping['status'];
      final golden = mapping['golden'];
      expect(screen, isA<String>(), reason: '${entry.key} screen');
      expect((screen as String).trim().length, greaterThanOrEqualTo(6));
      expect(state, matches(RegExp(r'^[a-z][a-z0-9-]+$')));
      expect(state, isNot(anyOf('default', 'unknown')));

      if (route == null) {
        expect(status, 'reference-only', reason: entry.key);
        expect(golden, isNull, reason: entry.key);
      } else {
        expect(status, 'routable', reason: entry.key);
        final states = _constructibleRouteStates[route];
        expect(states, isNotNull, reason: '${entry.key} route $route');
        expect(states, contains(state), reason: '${entry.key} $route');
      }

      if (golden != null) {
        expect(
          golden,
          _goldenByRouteState['$route|$state'],
          reason: '${entry.key} golden semantics',
        );
        expect(
          _goldenFileExists(golden as String),
          isTrue,
          reason: '${entry.key} golden file',
        );
      }

      final taskThreeGolden = _taskThreeGoldenByNode[entry.key];
      if (taskThreeGolden != null) {
        final pendingEntry = pendingByNode[entry.key];
        expect(
          golden ?? pendingEntry?['golden'],
          taskThreeGolden,
          reason: '${entry.key} Task 3 golden contract',
        );
        expect(
          golden != null || pendingEntry?['directory'] == 'progress-profile',
          isTrue,
          reason: '${entry.key} pending Linux baseline directory',
        );
        expect(
          golden != null ? ['light', 'dark'] : pendingEntry?['modes'],
          ['light', 'dark'],
          reason: '${entry.key} pending Linux baseline modes',
        );
        expect(
          golden != null ? route : pendingEntry?['route'],
          route,
          reason: '${entry.key} pending Linux baseline route',
        );
        expect(
          golden != null ? state : pendingEntry?['state'],
          state,
          reason: '${entry.key} pending Linux baseline state',
        );
      }

      final png = File(
        '../../docs/design/figma-reference/mobile/${mapping['file']}',
      );
      expect(png.existsSync(), isTrue, reason: entry.key);
      expect(
        png.readAsBytesSync().take(8).toList(),
        _pngSignature,
        reason: entry.key,
      );
    }

    final exportedFiles =
        Directory('../../docs/design/figma-reference/mobile/page-1')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.png'))
            .map((file) => 'page-1/${file.uri.pathSegments.last}')
            .toSet();
    expect(referencedFiles, exportedFiles);
  });
}

bool _goldenFileExists(String golden) {
  return File('test/goldens/foundation/$golden.png').existsSync() ||
      File('test/goldens/learning/$golden.png').existsSync() ||
      File('test/goldens/progress-profile/$golden.png').existsSync();
}

const _pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

const _page1NodeIds = <String>{
  '2030:716',
  '2030:717',
  '2030:718',
  '2030:719',
  '2030:724',
  '2030:725',
  '2030:726',
  '2030:727',
  '2030:728',
  '2030:729',
  '2030:730',
  '2030:731',
  '2030:732',
  '2045:756',
  '2069:99',
  '2070:136',
  '2070:99',
  '2071:99',
  '2079:1015',
  '2079:1172',
  '2079:792',
  '2079:915',
  '2085:1685',
  '2145:132',
  '2145:166',
  '2145:98',
  '2146:145',
  '2146:146',
  '2146:246',
  '2146:346',
  '2146:446',
  '2146:531',
  '2146:96',
  '2146:97',
  '2153:96',
};

const _constructibleRouteStates = <String, Set<String>>{
  '/login': {'form'},
  '/register': {'form'},
  '/placement': {'intro'},
  '/placement/question': {'mcq-unanswered', 'listening-mcq-unanswered'},
  '/placement/result': {'completed-summary'},
  '/profile-setup': {'personalization-form'},
  '/home': {
    'dashboard-loaded',
    'daily-plan',
    'learning-path-loaded',
    'learning-path-empty',
    'learning-path-error',
    'progress-overview',
    'progress-skills',
    'progress-achievements',
    'profile-settings',
  },
  '/lesson/:id': {
    'exercise-mcq-unanswered',
    'feedback-incorrect',
    'feedback-correct',
    'completed-celebration',
    'completed-rewards-summary',
  },
  '/question-review': {'feedback-incorrect-explanation'},
  '/vocabulary-review': {
    'card-front',
    'card-back-rating',
    'empty',
    'completed',
  },
  '/streak-details': {'loaded'},
};

const _goldenByRouteState = <String, String>{
  '/login|form': 'login_light',
  '/register|form': 'register_light',
  '/placement|intro': 'placement_intro_light',
  '/placement/question|mcq-unanswered': 'placement_question_light',
  '/placement/result|completed-summary': 'placement_result_light',
  '/profile-setup|personalization-form': 'profile_setup_light',
  '/home|dashboard-loaded': 'home_loaded_light',
  '/home|daily-plan': 'home_loaded_light',
  '/home|learning-path-loaded': 'learning_path_loaded_light',
  '/home|learning-path-empty': 'learning_path_empty_light',
  '/home|learning-path-error': 'learning_path_error_light',
  '/lesson/:id|exercise-mcq-unanswered': 'lesson_exercise_light',
  '/lesson/:id|feedback-incorrect': 'lesson_feedback_incorrect_light',
  '/lesson/:id|feedback-correct': 'lesson_feedback_correct_light',
  '/lesson/:id|completed-celebration': 'lesson_complete_light',
  '/lesson/:id|completed-rewards-summary': 'lesson_complete_light',
  '/question-review|feedback-incorrect-explanation':
      'question_review_feedback_incorrect_light',
  '/vocabulary-review|card-front': 'vocabulary_review_ready_light',
  '/vocabulary-review|card-back-rating': 'vocabulary_review_back_light',
  '/vocabulary-review|empty': 'vocabulary_review_empty_light',
  '/vocabulary-review|completed': 'vocabulary_review_complete_light',
  '/home|progress-overview': 'progress_overview_light',
  '/home|profile-settings': 'profile_loaded_light',
  '/home|progress-skills': 'progress_skills_light',
  '/home|progress-achievements': 'progress_achievements_light',
  '/streak-details|loaded': 'streak_loaded_light',
};

const _taskThreeGoldenByNode = <String, String>{
  '2030:730': 'progress_overview_light',
  '2030:731': 'profile_loaded_light',
  '2079:1015': 'streak_loaded_light',
  '2085:1685': 'progress_skills_light',
  '2146:346': 'progress_achievements_light',
};
