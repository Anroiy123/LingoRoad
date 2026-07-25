class DailyQuest {
  const DailyQuest(this.title, this.current, this.target, this.icon);
  final String title;
  final int current;
  final int target;
  final String icon;
  bool get done => current >= target;
}

class PathNode {
  const PathNode(this.title, this.subtitle, this.xp, this.status, this.side);
  final String title;
  final String subtitle;
  final int xp;
  final String status;
  final String side;
}

class ReviewCardData {
  const ReviewCardData(this.word, this.meaning, this.example, this.category);
  final String word;
  final String meaning;
  final String example;
  final String category;
}

class SkillProgress {
  const SkillProgress(this.label, this.value, this.icon);
  final String label;
  final int value;
  final String icon;
}
