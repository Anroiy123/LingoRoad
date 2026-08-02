import 'dart:io';

import 'package:lingoroad_mobile/features/practice/domain/practice_models.dart';
import 'package:record/record.dart';

abstract interface class SpeakingRecorder {
  Future<bool> start();
  Future<RecordedAudio?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class DeviceSpeakingRecorder implements SpeakingRecorder {
  DeviceSpeakingRecorder({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  String? _path;

  @override
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    _path = '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'lingoroad-${DateTime.now().microsecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
      path: _path!,
    );
    return true;
  }

  @override
  Future<RecordedAudio?> stop() async {
    final recordedPath = await _recorder.stop() ?? _path;
    _path = null;
    if (recordedPath == null) return null;
    final file = File(recordedPath);
    try {
      if (!await file.exists()) return null;
      return RecordedAudio(
        bytes: await file.readAsBytes(),
        fileName: 'speaking.wav',
        mimeType: 'audio/wav',
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> cancel() async {
    await _recorder.cancel();
    final path = _path;
    _path = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}
