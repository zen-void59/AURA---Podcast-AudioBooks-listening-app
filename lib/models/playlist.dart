class Playlist {
  final String id;

  String name;

  String? description;

  List<String> episodeIds; // store episode IDs, resolve when needed

  final DateTime createdAt;

  DateTime updatedAt;

  String? coverImageUrl; // first episode's image

  Playlist({
    required this.id,
    required this.name,
    this.description,
    List<String>? episodeIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.coverImageUrl,
  })  : episodeIds = episodeIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get episodeCount => episodeIds.length;

  void addEpisode(String episodeId) {
    if (!episodeIds.contains(episodeId)) {
      episodeIds.add(episodeId);
      updatedAt = DateTime.now();
    }
  }

  void removeEpisode(String episodeId) {
    episodeIds.remove(episodeId);
    updatedAt = DateTime.now();
  }

  void reorder(int oldIndex, int newIndex) {
    final id = episodeIds.removeAt(oldIndex);
    episodeIds.insert(newIndex, id);
    updatedAt = DateTime.now();
  }
}
