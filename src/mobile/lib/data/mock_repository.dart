import 'package:lingoroad_mobile/models/models.dart';

class MockRepository {
  const MockRepository();

  Future<List<DailyQuest>> quests() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return const [
      DailyQuest('home.quests.complete_lessons', 1, 2, 'bolt'),
      DailyQuest('home.quests.listen_minutes', 0, 10, 'headphones'),
      DailyQuest('home.quests.reach_xp', 50, 50, 'check'),
    ];
  }

  Future<List<PathNode>> path() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return const [
      PathNode('learning_path.lessons.lesson_2', 'learning_path.lessons.at_restaurant', 20, 'complete', 'right'),
      PathNode('learning_path.lessons.lesson_3', 'learning_path.lessons.asking_directions', 25, 'complete', 'left'),
      PathNode('learning_path.lessons.lesson_4', 'learning_path.lessons.shopping', 30, 'complete', 'right'),
      PathNode('learning_path.lessons.lesson_5', 'learning_path.lessons.airport_communication', 50, 'current', 'center'),
      PathNode('learning_path.lessons.lesson_6', 'learning_path.lessons.hotel_check_in', 35, 'locked', 'center'),
      PathNode('learning_path.lessons.lesson_7', 'learning_path.lessons.workplace_communication', 40, 'locked', 'center'),
    ];
  }

  Future<List<ReviewCardData>> reviews() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return const [
      ReviewCardData(
        'review.word.serendipity',
        'review.word.serendipity_meaning',
        'review.word.serendipity_example',
        'review.category.vocab',
      ),
      ReviewCardData(
        'review.word.itinerary',
        'review.word.itinerary_meaning',
        'review.word.itinerary_example',
        'review.category.vocab',
      ),
      ReviewCardData(
        'review.word.boarding_pass',
        'review.word.boarding_pass_meaning',
        'review.word.boarding_pass_example',
        'review.category.airport',
      ),
    ];
  }

  List<SkillProgress> get skills => const [
        SkillProgress('progress.skills_list.vocabulary', 92, 'book'),
        SkillProgress('progress.skills_list.grammar', 88, 'language'),
        SkillProgress('progress.skills_list.listening', 85, 'headphones'),
        SkillProgress('progress.skills_list.writing', 60, 'edit'),
        SkillProgress('progress.skills_list.speaking', 52, 'mic'),
        SkillProgress('progress.skills_list.pronunciation', 45, 'record'),
      ];
}
