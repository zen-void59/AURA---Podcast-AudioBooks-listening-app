class Episode {
  final String id;

  final String name;

  final String? description;

  final int? duration; // seconds

  final String? releaseDate;

  final String? imageUrl;

  final String showId;

  final String showName;

  final int? seasonNumber;

  final int? episodeNumber;

  final List<AudioQuality> downloadUrls;

  final String? url;

  final bool explicitContent;

  final bool isYouTube;
  final String? youtubeVideoId;

  // Not stored in Hive — runtime only
  String? localPath; // path if downloaded

  Episode({
    required this.id,
    required this.name,
    this.description,
    this.duration,
    this.releaseDate,
    this.imageUrl,
    required this.showId,
    required this.showName,
    this.seasonNumber,
    this.episodeNumber,
    this.downloadUrls = const [],
    this.url,
    this.explicitContent = false,
    this.isYouTube = false,
    this.youtubeVideoId,
    this.localPath,
  });

  /// Best available audio URL (prefers 160kbps for streaming)
  String? get streamUrl {
    for (final q in ['160kbps', '96kbps', '320kbps', '48kbps', '12kbps']) {
      final match = downloadUrls.where((d) => d.quality == q && d.url.isNotEmpty);
      if (match.isNotEmpty) return match.first.url;
    }
    if (downloadUrls.isNotEmpty && downloadUrls.first.url.isNotEmpty) {
      return downloadUrls.first.url;
    }
    return url;
  }

  /// High quality URL for download
  String? get downloadUrl {
    if (downloadUrls.isEmpty) return null;
    final preferred = downloadUrls.firstWhere(
      (q) => q.quality == '320kbps',
      orElse: () => downloadUrls.last,
    );
    return preferred.url;
  }

  /// Safely resolves the best display image URL, with automatic fallbacks for
  /// YouTube videos, LibriVox audiobooks, and direct stream links.
  String? get displayImageUrl {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      final trimmed = imageUrl!.trim();
      if (trimmed.startsWith('http://')) {
        return trimmed.replaceFirst('http://', 'https://');
      }
      return trimmed;
    }
    // YouTube video thumbnail fallback: hqdefault is guaranteed to exist on YouTube CDN
    final ytId = youtubeVideoId ?? _extractYtIdFromEpisodeId();
    if (ytId != null && ytId.isNotEmpty) {
      return 'https://img.youtube.com/vi/$ytId/hqdefault.jpg';
    }
    return null;
  }

  String? _extractYtIdFromEpisodeId() {
    if (id.startsWith('yt_ep_')) {
      final stripped = id.substring(6);
      if (stripped.isNotEmpty) return stripped;
    }
    if (id.startsWith('yt_vid_')) {
      final stripped = id.substring(7);
      if (stripped.isNotEmpty) return stripped;
    }
    return null;
  }

  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  factory Episode.fromJson(Map<String, dynamic> json) {
    final images = json['image'] as List<dynamic>?;
    String? apiImageUrl;
    if (images != null && images.isNotEmpty) {
      final highRes = images.firstWhere(
        (img) => img['quality'] == '500x500',
        orElse: () => images.last,
      );
      apiImageUrl = highRes['url'] as String?;
    }

    final show = json['show'] as Map<String, dynamic>?;
    final season = json['season'] as Map<String, dynamic>?;

    final downloadUrlsJson = json['downloadUrl'] as List<dynamic>? ?? [];
    final downloadUrls = downloadUrlsJson
        .map((q) => AudioQuality.fromJson(q as Map<String, dynamic>))
        .toList();

    final rawId = json['id']?.toString() ?? '';
    final isYt = json['isYouTube'] as bool? ??
        (rawId.startsWith('yt_ep_') || rawId.startsWith('yt_vid_'));
    String? ytVidId = json['youtubeVideoId'] as String?;
    if (ytVidId == null && isYt) {
      if (rawId.startsWith('yt_ep_')) {
        ytVidId = rawId.substring(6);
      } else if (rawId.startsWith('yt_vid_')) {
        ytVidId = rawId.substring(7);
      }
    }

    // Read stored 'imageUrl' first (from toJson/SharedPreferences), then API fallback
    String? resolvedImageUrl = json['imageUrl'] as String? ??
        json['squareImage'] as String? ??
        apiImageUrl;

    if (resolvedImageUrl != null && resolvedImageUrl.trim().isNotEmpty) {
      resolvedImageUrl = resolvedImageUrl.trim();
      if (resolvedImageUrl.startsWith('http://')) {
        resolvedImageUrl = resolvedImageUrl.replaceFirst('http://', 'https://');
      }
    } else if (ytVidId != null && ytVidId.isNotEmpty) {
      resolvedImageUrl = 'https://img.youtube.com/vi/$ytVidId/hqdefault.jpg';
    }

    return Episode(
      id: rawId,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      duration: json['duration'] as int?,
      releaseDate: json['releaseDate'] as String?,
      imageUrl: resolvedImageUrl,
      showId: json['showId'] as String? ?? show?['id']?.toString() ?? '',
      showName: json['showName'] as String? ?? show?['name'] as String? ?? '',
      seasonNumber: season?['number'] as int? ?? json['seasonNumber'] as int?,
      episodeNumber: json['episodeNumber'] as int? ?? json['sequenceNumber'] as int?,
      downloadUrls: downloadUrls,
      url: json['url'] as String?,
      isYouTube: isYt,
      youtubeVideoId: ytVidId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'duration': duration,
    'releaseDate': releaseDate,
    'imageUrl': displayImageUrl ?? imageUrl,
    'showId': showId,
    'showName': showName,
    'seasonNumber': seasonNumber,
    'episodeNumber': episodeNumber,
    'downloadUrl': downloadUrls.map((d) => d.toJson()).toList(),
    'url': url,
    'explicitContent': explicitContent,
    'isYouTube': isYouTube,
    'youtubeVideoId': youtubeVideoId,
    'localPath': localPath,
  };

  Episode copyWith({String? localPath}) {
    return Episode(
      id: id,
      name: name,
      description: description,
      duration: duration,
      releaseDate: releaseDate,
      imageUrl: imageUrl,
      showId: showId,
      showName: showName,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      downloadUrls: downloadUrls,
      url: url,
      explicitContent: explicitContent,
      isYouTube: isYouTube,
      youtubeVideoId: youtubeVideoId,
      localPath: localPath ?? this.localPath,
    );
  }
}

class AudioQuality {
  final String quality;

  final String url;

  const AudioQuality({required this.quality, required this.url});

  factory AudioQuality.fromJson(Map<String, dynamic> json) => AudioQuality(
    quality: json['quality'] as String? ?? '',
    url: json['url'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'quality': quality,
    'url': url,
  };
}
