class MediaItem {
  final String id;
  final String title;
  final String type;
  final String poster;
  final String? banner;
  final String? year;
  final String? rating;
  final String? ratingSource;
  final String? quality;
  final String? duration;
  final String? overview;
  final List<String>? genres;
  final List<int>? seasons;

  MediaItem({
    required this.id,
    required this.title,
    required this.type,
    required this.poster,
    this.banner,
    this.year,
    this.rating,
    this.ratingSource,
    this.quality,
    this.duration,
    this.overview,
    this.genres,
    this.seasons,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? 'movie',
      poster: json['poster'] ?? '',
      banner: json['banner'],
      year: json['year'],
      rating: json['rating'],
      ratingSource: json['rating_source'] ?? 'TMDB',
      quality: json['quality'] ?? '1080p HD',
      duration: json['duration'],
      overview: json['overview'],
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      seasons: (json['seasons'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList(),
    );
  }
}

class Episode {
  final String id;
  final int number;
  final int season;
  final String title;
  final String? overview;

  Episode({
    required this.id,
    required this.number,
    required this.season,
    required this.title,
    this.overview,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'] ?? '',
      number: json['number'] ?? 1,
      season: json['season'] ?? 1,
      title: json['title'] ?? '',
      overview: json['overview'],
    );
  }
}

class Server {
  final String id;
  final String name;

  Server({required this.id, required this.name});

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class SubtitleTrack {
  final String url;
  final String lang;

  SubtitleTrack({required this.url, required this.lang});

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) {
    return SubtitleTrack(
      url: json['url'] ?? '',
      lang: json['lang'] ?? 'English',
    );
  }
}

class StreamSource {
  final String url;
  final String quality;
  final bool isM3U8;

  StreamSource({
    required this.url,
    required this.quality,
    required this.isM3U8,
  });

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    return StreamSource(
      url: json['url'] ?? '',
      quality: json['quality'] ?? 'auto',
      isM3U8: json['is_m3u8'] ?? true,
    );
  }
}

class StreamResult {
  final List<StreamSource> sources;
  final List<SubtitleTrack> subtitles;
  final Map<String, String> headers;

  StreamResult({
    required this.sources,
    required this.subtitles,
    required this.headers,
  });

  factory StreamResult.fromJson(Map<String, dynamic> json) {
    final rawSources = (json['sources'] as List<dynamic>?) ?? [];
    final rawSubs = (json['subtitles'] as List<dynamic>?) ?? [];
    final rawHeaders = (json['headers'] as Map<String, dynamic>?) ?? {};

    return StreamResult(
      sources: rawSources.map((e) => StreamSource.fromJson(e)).toList(),
      subtitles: rawSubs.map((e) => SubtitleTrack.fromJson(e)).toList(),
      headers: rawHeaders.map((k, v) => MapEntry(k, v.toString())),
    );
  }
}
