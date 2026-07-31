class DailyQuest {
  const DailyQuest(this.title, this.current, this.target, this.icon);
  final String title;
  final int current;
  final int target;
  final String icon;
  bool get done => current >= target;
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
