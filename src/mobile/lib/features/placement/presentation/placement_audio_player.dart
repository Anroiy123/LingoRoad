import 'package:audioplayers/audioplayers.dart';

abstract interface class PlacementAudioPlayer {
  Future<void> play(String url);

  Future<void> stop();

  Future<void> dispose();
}

class DevicePlacementAudioPlayer implements PlacementAudioPlayer {
  DevicePlacementAudioPlayer([AudioPlayer? player])
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(String url) => _player.play(UrlSource(url));

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
