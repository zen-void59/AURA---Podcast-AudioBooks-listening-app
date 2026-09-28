class Bookmark {
  final String id;

  final String episodeId;

  final String episodeName;

  final String showName;

  final String? episodeImageUrl;

  final int positionMs; // milliseconds

  String? note;

  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.episodeId,
    required this.episodeName,
    required this.showName,
    this.episodeImageUrl,
    required this.positionMs,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get formattedPosition {
    final d = Duration(milliseconds: positionMs);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class ListenHistory {
  final String episodeId;

  final String episodeName;

  final String showName;

  final String? imageUrl;

  int positionMs;

  final int? durationMs;

  DateTime lastListened;

  int listenCount;

  ListenHistory({
    required this.episodeId,
    required this.episodeName,
    required this.showName,
    this.imageUrl,
    this.positionMs = 0,
    this.durationMs,
    DateTime? lastListened,
    this.listenCount = 1,
  }) : lastListened = lastListened ?? DateTime.now();

  double get progress {
    if (durationMs == null || durationMs == 0) return 0;
    return (positionMs / durationMs!).clamp(0.0, 1.0);
  }

  bool get isCompleted => progress >= 0.95;
}
