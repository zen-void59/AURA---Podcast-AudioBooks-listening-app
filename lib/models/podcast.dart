class Podcast {
  final String id;

  final String name;

  final String? description;

  final String? imageUrl;

  final String? headerImageUrl;

  final int? totalEpisodes;

  final int? latestSeasonNumber;

  final List<Season> seasons;

  final String? url;

  final bool isYouTube;
  final String? youtubeId;
  final String? channelName;

  const Podcast({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.headerImageUrl,
    this.totalEpisodes,
    this.latestSeasonNumber,
    this.seasons = const [],
    this.url,
    this.isYouTube = false,
    this.youtubeId,
    this.channelName,
  });

  factory Podcast.fromJson(Map<String, dynamic> json) {
    final images = json['image'] as List<dynamic>?;
    String? imageUrl;
    if (images != null && images.isNotEmpty) {
      final highRes = images.firstWhere(
        (img) => img['quality'] == '500x500',
        orElse: () => images.last,
      );
      imageUrl = highRes['url'] as String?;
    }

    final seasons = (json['seasons'] as List<dynamic>?)
        ?.map((s) => Season.fromJson(s as Map<String, dynamic>))
        .toList() ?? [];

    return Podcast(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['squareImage'] as String? ?? imageUrl,
      headerImageUrl: json['headerImage'] as String?,
      totalEpisodes: json['totalEpisodes'] as int?,
      latestSeasonNumber: json['latestSeasonNumber'] as int?,
      seasons: seasons,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'squareImage': imageUrl,
    'headerImage': headerImageUrl,
    'totalEpisodes': totalEpisodes,
    'latestSeasonNumber': latestSeasonNumber,
    'url': url,
  };
}

class Season {
  final String id;

  final String name;

  final int number;

  final String? imageUrl;

  const Season({
    required this.id,
    required this.name,
    required this.number,
    this.imageUrl,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    final images = json['image'] as List<dynamic>?;
    String? imageUrl;
    if (images != null && images.isNotEmpty) {
      final highRes = images.firstWhere(
        (img) => img['quality'] == '500x500',
        orElse: () => images.last,
      );
      imageUrl = highRes['url'] as String?;
    }

    return Season(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      number: json['seasonNumber'] as int? ?? json['number'] as int? ?? 1,
      imageUrl: imageUrl,
    );
  }
}
