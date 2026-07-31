class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.targetCefr,
    required this.cefrLevel,
    required this.level,
    required this.badgesCount,
  });

  final String id;
  final String email;
  final String name;
  final String targetCefr;
  final String cefrLevel;
  final int level;
  final int badgesCount;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      targetCefr: json['targetCefr']?.toString() ?? 'B2',
      cefrLevel: json['cefrLevel']?.toString() ?? 'A1',
      level: json['level'] is int ? json['level'] as int : int.tryParse(json['level']?.toString() ?? '') ?? 1,
      badgesCount: json['badgesCount'] is int ? json['badgesCount'] as int : int.tryParse(json['badgesCount']?.toString() ?? '') ?? 0,
    );
  }
}
