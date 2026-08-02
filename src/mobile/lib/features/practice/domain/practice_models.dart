import 'dart:typed_data';

class WritingScores {
  const WritingScores({
    required this.taskAchievement,
    required this.coherenceCohesion,
    required this.lexicalResource,
    required this.grammaticalAccuracy,
  });

  final double taskAchievement;
  final double coherenceCohesion;
  final double lexicalResource;
  final double grammaticalAccuracy;
}

class WritingFeedback {
  const WritingFeedback({
    required this.sentence,
    required this.issue,
    required this.suggestion,
  });

  final String sentence;
  final String issue;
  final String suggestion;
}

class WritingResult {
  const WritingResult({
    required this.scores,
    required this.feedback,
    required this.overallVi,
  });

  final WritingScores scores;
  final List<WritingFeedback> feedback;
  final String overallVi;
}

class SpeakingScore {
  const SpeakingScore({
    required this.transcript,
    required this.accuracy,
    required this.completeness,
    required this.fluency,
    required this.total,
    required this.durationSeconds,
    required this.modelVersion,
    required this.feedbackVi,
  });

  final String transcript;
  final double accuracy;
  final double completeness;
  final double fluency;
  final double total;
  final double durationSeconds;
  final String modelVersion;
  final String feedbackVi;
}

class SpeakingHistoryItem {
  const SpeakingHistoryItem({
    required this.id,
    required this.promptText,
    required this.transcript,
    required this.total,
    required this.modelVersion,
    required this.createdAt,
  });

  final String id;
  final String promptText;
  final String? transcript;
  final double total;
  final String modelVersion;
  final DateTime createdAt;
}

class RecordedAudio {
  const RecordedAudio({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}
