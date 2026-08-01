class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.targetCefr,
    required this.cefrLevel,
    required this.level,
    required this.badgesCount,
    this.dailyGoalMinutes = 30,
    this.learningPurpose,
    this.focusSkillIds = const [],
    this.studyReminderEnabled = true,
    this.reminderTime,
    this.timeZone = 'Asia/Ho_Chi_Minh',
    this.emailNotifications = false,
    this.appUpdates = true,
    this.role = 'Learner',
    this.targetCefrConfirmed = true,
  });

  final String id;
  final String email;
  final String name;
  final String targetCefr;
  final String cefrLevel;
  final int level;
  final int badgesCount;
  final int dailyGoalMinutes;
  final String? learningPurpose;
  final List<int> focusSkillIds;
  final bool studyReminderEnabled;
  final String? reminderTime;
  final String timeZone;
  final bool emailNotifications;
  final bool appUpdates;
  final String role;
  final bool targetCefrConfirmed;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      targetCefr: json['targetCefr']?.toString() ?? 'B2',
      cefrLevel: json['cefrLevel']?.toString() ?? 'A1',
      level: json['level'] is int
          ? json['level'] as int
          : int.tryParse(json['level']?.toString() ?? '') ?? 1,
      badgesCount: json['badgesCount'] is int
          ? json['badgesCount'] as int
          : int.tryParse(json['badgesCount']?.toString() ?? '') ?? 0,
      dailyGoalMinutes: json['dailyGoalMinutes'] is int
          ? json['dailyGoalMinutes'] as int
          : 30,
      learningPurpose: json['learningPurpose']?.toString(),
      focusSkillIds: (json['focusSkillIds'] as List<dynamic>? ?? const [])
          .map((value) => value is int ? value : int.tryParse(value.toString()))
          .whereType<int>()
          .toList(growable: false),
      studyReminderEnabled: json['studyReminderEnabled'] as bool? ?? true,
      reminderTime: json['reminderTime']?.toString(),
      timeZone: json['timeZone']?.toString() ?? 'Asia/Ho_Chi_Minh',
      emailNotifications: json['emailNotifications'] as bool? ?? false,
      appUpdates: json['appUpdates'] as bool? ?? true,
      role: json['role']?.toString() ?? 'Learner',
      targetCefrConfirmed: json['targetCefrConfirmed'] as bool? ?? true,
    );
  }
}
