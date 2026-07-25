import 'package:lingoroad_mobile/models/models.dart';

class MockRepository {
  const MockRepository();

  Future<List<DailyQuest>> quests() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return const [
      DailyQuest('Hoàn thành 2 bài học', 1, 2, 'bolt'),
      DailyQuest('Nghe 10 phút', 0, 10, 'headphones'),
      DailyQuest('Đạt 50 XP', 50, 50, 'check'),
    ];
  }

  Future<List<PathNode>> path() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return const [
      PathNode('Bài 2', 'Tại nhà hàng', 20, 'complete', 'right'),
      PathNode('Bài 3', 'Hỏi đường', 25, 'complete', 'left'),
      PathNode('Bài 4', 'Mua sắm', 30, 'complete', 'right'),
      PathNode('Bài 5', 'Giao tiếp tại sân bay', 50, 'current', 'center'),
      PathNode('Bài 6', 'Nhận phòng khách sạn', 35, 'locked', 'center'),
      PathNode('Bài 7', 'Giao tiếp công sở', 40, 'locked', 'center'),
    ];
  }

  Future<List<ReviewCardData>> reviews() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return const [
      ReviewCardData(
        'Serendipity',
        'Sự tình cờ may mắn',
        'Meeting her was pure serendipity.',
        'TỪ VỰNG',
      ),
      ReviewCardData(
        'Itinerary',
        'Lịch trình chuyến đi',
        'Please check your travel itinerary.',
        'TỪ VỰNG',
      ),
      ReviewCardData(
        'Boarding pass',
        'Thẻ lên máy bay',
        'May I see your boarding pass?',
        'SÂN BAY',
      ),
    ];
  }

  List<SkillProgress> get skills => const [
        SkillProgress('Từ vựng', 92, 'book'),
        SkillProgress('Ngữ pháp', 88, 'language'),
        SkillProgress('Nghe', 85, 'headphones'),
        SkillProgress('Viết', 60, 'edit'),
        SkillProgress('Nói', 52, 'mic'),
        SkillProgress('Phát âm', 45, 'record'),
      ];
}
