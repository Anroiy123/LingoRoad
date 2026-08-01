import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/lesson/domain/lesson_models.dart';

class DashboardData {
  const DashboardData({
    required this.name,
    required this.currentCefr,
    required this.dailyGoalMinutes,
    required this.mastery,
    required this.dailyProgress,
    required this.weeklyProgress,
    required this.dueReviews,
    required this.completedLessons,
    required this.xp,
    required this.coins,
    required this.currentStreak,
    required this.longestStreak,
    required this.activeDates,
    required this.recentActivity,
    this.targetCefr,
    this.todayLesson,
  });

  final String name;
  final String currentCefr;
  final String? targetCefr;
  final int dailyGoalMinutes;
  final double mastery;
  final double dailyProgress;
  final double weeklyProgress;
  final int dueReviews;
  final int completedLessons;
  final int xp;
  final int coins;
  final int currentStreak;
  final int longestStreak;
  final List<DateTime> activeDates;
  final TodayLesson? todayLesson;
  final List<RecentLessonActivity> recentActivity;

  factory DashboardData.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) throw _malformed();
    final recent = value['recentActivity'];
    final rawActiveDates = value['activeDates'];
    if (recent is! List || rawActiveDates is! List) throw _malformed();
    final activeDates = rawActiveDates
        .map((date) => DateTime.tryParse(date.toString()))
        .toList(growable: false);
    if (activeDates.any((date) => date == null)) throw _malformed();
    return DashboardData(
      name: _text(value, 'name'),
      currentCefr: _text(value, 'currentCefr'),
      targetCefr: value['targetCefr']?.toString(),
      dailyGoalMinutes: _integer(value, 'dailyGoalMinutes'),
      mastery: _progress(value, 'mastery'),
      dailyProgress: _progress(value, 'dailyProgress'),
      weeklyProgress: _progress(value, 'weeklyProgress'),
      dueReviews: _integer(value, 'dueReviews'),
      completedLessons: _integer(value, 'completedLessons'),
      xp: _integer(value, 'xp'),
      coins: _integer(value, 'coins'),
      currentStreak: _integer(value, 'currentStreak'),
      longestStreak: _integer(value, 'longestStreak'),
      activeDates: activeDates.cast<DateTime>(),
      todayLesson: value['todayLesson'] == null
          ? null
          : TodayLesson.fromJson(value['todayLesson']),
      recentActivity:
          recent.map(RecentLessonActivity.fromJson).toList(growable: false),
    );
  }
}

class RecentLessonActivity {
  const RecentLessonActivity({
    required this.lessonId,
    required this.title,
    required this.titleVi,
    required this.completedAt,
  });

  final String lessonId;
  final String title;
  final String titleVi;
  final DateTime completedAt;

  factory RecentLessonActivity.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) throw _malformed();
    final completedAt = DateTime.tryParse(_text(value, 'completedAt'));
    if (completedAt == null) throw _malformed();
    return RecentLessonActivity(
      lessonId: _text(value, 'lessonId'),
      title: _text(value, 'title'),
      titleVi: _text(value, 'titleVi'),
      completedAt: completedAt,
    );
  }
}

class QuestData {
  const QuestData({
    required this.code,
    required this.current,
    required this.target,
    required this.completed,
  });

  final String code;
  final int current;
  final int target;
  final bool completed;

  factory QuestData.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) throw _malformed();
    if (value['completed'] is! bool) throw _malformed();
    return QuestData(
      code: _text(value, 'code'),
      current: _integer(value, 'current'),
      target: _integer(value, 'target'),
      completed: value['completed'] as bool,
    );
  }
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) throw _malformed();
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) throw _malformed();
  return parsed;
}

double _progress(Map<String, dynamic> json, String key) {
  final value = json[key];
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  if (parsed == null || parsed < 0 || parsed > 1) throw _malformed();
  return parsed;
}

ApiException _malformed() => const ApiException(
      code: 'malformed_response',
      message: 'Phản hồi bảng điều khiển không hợp lệ',
    );
