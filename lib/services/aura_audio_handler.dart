import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:aura/models/episode.dart';

class AuraAudioHandler extends BaseAudioHandler with SeekHandler {
  VoidCallback? onPlay;
  VoidCallback? onPause;
  VoidCallback? onStop;
  ValueChanged<Duration>? onSeek;
  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;
  VoidCallback? onFastForward;
  VoidCallback? onRewind;

  AuraAudioHandler() {
    playbackState.add(
      PlaybackState(
        controls: const [
          MediaControl.rewind,
          MediaControl.play,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  void updateItem(Episode episode, Duration? dur) {
    Uri? artUri;
    if (episode.imageUrl != null && episode.imageUrl!.isNotEmpty) {
      artUri = Uri.tryParse(episode.imageUrl!);
    }

    mediaItem.add(
      MediaItem(
        id: episode.id,
        album: episode.showName,
        title: episode.name,
        artist: episode.showName,
        duration: dur != null && dur > Duration.zero ? dur : (episode.duration != null ? Duration(seconds: episode.duration!) : null),
        artUri: artUri,
        displayTitle: episode.name,
        displaySubtitle: episode.showName,
      ),
    );
  }

  void updatePlaybackState({
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    required double speed,
    required bool isLoading,
  }) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.rewind,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: isLoading
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: isPlaying,
        updatePosition: position,
        bufferedPosition: position,
        speed: speed,
      ),
    );
  }

  @override
  Future<void> play() async {
    onPlay?.call();
  }

  @override
  Future<void> pause() async {
    onPause?.call();
  }

  @override
  Future<void> stop() async {
    onStop?.call();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  @override
  Future<void> seek(Duration position) async {
    onSeek?.call(position);
  }

  @override
  Future<void> skipToNext() async {
    onSkipNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipPrevious?.call();
  }

  @override
  Future<void> fastForward() async {
    onFastForward?.call();
  }

  @override
  Future<void> rewind() async {
    onRewind?.call();
  }
}
