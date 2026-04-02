import 'dart:convert';

import 'package:http/http.dart' as http;

enum DashboardNewsDesk {
  world,
  local,
}

class DashboardNewsStory {
  final DashboardNewsDesk desk;
  final String title;
  final String source;
  final String url;
  final String? imageUrl;
  final DateTime publishedAt;
  final int score;
  final int commentCount;

  const DashboardNewsStory({
    required this.desk,
    required this.title,
    required this.source,
    required this.url,
    required this.publishedAt,
    required this.score,
    required this.commentCount,
    this.imageUrl,
  });
}

class DashboardNewsBundle {
  final List<DashboardNewsStory> world;
  final List<DashboardNewsStory> local;

  const DashboardNewsBundle({
    required this.world,
    required this.local,
  });
}

class DashboardNewsService {
  static final Uri _worldNewsUri = _redditFeedUri(
    'worldnews',
    sort: 'top',
    limit: 12,
    timeframe: 'day',
  );
  static final List<Uri> _localNewsUris = [
    _redditFeedUri('taiwan', sort: 'hot', limit: 18),
    _redditFeedUri('taiwan', sort: 'top', limit: 18, timeframe: 'week'),
    _redditFeedUri('Taiwanese', sort: 'hot', limit: 18),
  ];
  static final Uri _worldRssFallbackUri = _rss2JsonUri(
    'https://news.google.com/rss/headlines/section/topic/WORLD?hl=en-US&gl=US&ceid=US:en',
  );
  static final Uri _localRssFallbackUri = _rss2JsonUri(
    'https://news.google.com/rss/search?q=Taichung%20school&hl=en-US&gl=TW&ceid=TW:en',
  );

  Future<DashboardNewsBundle> fetchNewsBundle() async {
    final world = await _safeFetchWorldStories();
    final local = await _safeFetchLocalStories();
    if (world.isEmpty && local.isEmpty) {
      throw Exception('No news stories were available from the live feeds.');
    }

    return DashboardNewsBundle(
      world: world,
      local: local,
    );
  }

  Future<List<DashboardNewsStory>> _safeFetchWorldStories() async {
    try {
      final stories = await _fetchRedditStories(
        _worldNewsUri,
        desk: DashboardNewsDesk.world,
      );
      if (stories.isNotEmpty) return stories;
    } catch (_) {
      // Fall through to browser-safe fallback.
    }
    try {
      final stories = await _fetchRss2JsonStories(
        _worldRssFallbackUri,
        desk: DashboardNewsDesk.world,
      );
      if (stories.isNotEmpty) return stories;
    } catch (_) {
      // Fall through to curated backup sources.
    }
    return _fallbackStories(DashboardNewsDesk.world);
  }

  Future<List<DashboardNewsStory>> _safeFetchLocalStories() async {
    final allStories = <DashboardNewsStory>[];
    for (final uri in _localNewsUris) {
      try {
        allStories.addAll(
          await _fetchRedditStories(
            uri,
            desk: DashboardNewsDesk.local,
            sourceFilter: _isAllowedLocalSource,
          ),
        );
      } catch (_) {
        // Keep going so one weak feed does not blank the whole local desk.
      }
    }

    final stories = _dedupeStories(
      allStories,
      maxCount: 6,
      preferLocalSources: true,
    );
    if (stories.isNotEmpty) return stories;

    try {
      final rssStories = await _fetchRss2JsonStories(
        _localRssFallbackUri,
        desk: DashboardNewsDesk.local,
      );
      if (rssStories.isNotEmpty) return rssStories;
    } catch (_) {
      // Fall through to curated backup sources.
    }
    return _fallbackStories(DashboardNewsDesk.local);
  }

  Future<List<DashboardNewsStory>> _fetchRedditStories(
    Uri uri, {
    required DashboardNewsDesk desk,
    bool Function(String source, String url)? sourceFilter,
  }) async {
    final response = await http.get(uri);
    if (response.statusCode >= 400) {
      throw Exception('News feed request failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final root =
        decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    final data = root['data'];
    final children = data is Map<String, dynamic> && data['children'] is List
        ? List<dynamic>.from(data['children'] as List)
        : const <dynamic>[];

    final stories = <DashboardNewsStory>[];
    for (final child in children) {
      if (child is! Map<String, dynamic>) continue;
      final item = child['data'];
      if (item is! Map<String, dynamic>) continue;
      if (item['stickied'] == true) continue;

      final title = (item['title'] ?? '').toString().trim();
      final url = (item['url_overridden_by_dest'] ?? item['url'] ?? '')
          .toString()
          .trim();
      final source = _cleanSource((item['domain'] ?? '').toString().trim());
      if (title.isEmpty || url.isEmpty || source.isEmpty) continue;
      if (_isBlockedSource(source, url)) continue;
      if (sourceFilter != null && !sourceFilter(source, url)) continue;

      final publishedAt = DateTime.fromMillisecondsSinceEpoch(
        (((item['created_utc'] as num?) ?? 0).toDouble() * 1000).round(),
        isUtc: true,
      ).toLocal();

      stories.add(
        DashboardNewsStory(
          desk: desk,
          title: title,
          source: source,
          url: url,
          imageUrl: _extractImageUrl(item),
          publishedAt: publishedAt,
          score: (item['score'] as num?)?.toInt() ?? 0,
          commentCount: (item['num_comments'] as num?)?.toInt() ?? 0,
        ),
      );
    }

    return _dedupeStories(
      stories,
      maxCount: desk == DashboardNewsDesk.world ? 6 : 8,
      preferLocalSources: desk == DashboardNewsDesk.local,
    );
  }

  static Uri _redditFeedUri(
    String subreddit, {
    required String sort,
    required int limit,
    String? timeframe,
  }) {
    return Uri.https(
      'www.reddit.com',
      '/r/$subreddit/$sort.json',
      {
        'limit': '$limit',
        'raw_json': '1',
        if (timeframe != null) 't': timeframe,
      },
    );
  }

  static Uri _rss2JsonUri(String rssUrl) {
    return Uri.https(
      'api.rss2json.com',
      '/v1/api.json',
      {
        'rss_url': rssUrl,
      },
    );
  }

  Future<List<DashboardNewsStory>> _fetchRss2JsonStories(
    Uri uri, {
    required DashboardNewsDesk desk,
  }) async {
    final response = await http.get(uri);
    if (response.statusCode >= 400) {
      throw Exception('RSS fallback request failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final root =
        decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    final items = root['items'];
    if (items is! List) return const <DashboardNewsStory>[];

    final stories = <DashboardNewsStory>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final rawTitle = (item['title'] ?? '').toString().trim();
      final url = (item['link'] ?? '').toString().trim();
      if (rawTitle.isEmpty || url.isEmpty) continue;

      final splitTitle = _splitTitleAndSource(rawTitle);
      final source = _cleanSource(splitTitle.source);
      if (source.isEmpty) continue;

      final publishedAt =
          DateTime.tryParse((item['pubDate'] ?? '').toString().trim()) ??
              DateTime.now();

      stories.add(
        DashboardNewsStory(
          desk: desk,
          title: splitTitle.title,
          source: source,
          url: url,
          imageUrl: _extractRssImageUrl(item),
          publishedAt: publishedAt,
          score: 0,
          commentCount: 0,
        ),
      );
    }

    return _dedupeStories(
      stories,
      maxCount: desk == DashboardNewsDesk.world ? 6 : 4,
      preferLocalSources: desk == DashboardNewsDesk.local,
    );
  }

  List<DashboardNewsStory> _dedupeStories(
    List<DashboardNewsStory> stories, {
    required int maxCount,
    bool preferLocalSources = false,
  }) {
    final seenUrls = <String>{};
    final deduped = <DashboardNewsStory>[];
    for (final story in stories) {
      final normalizedUrl = story.url.toLowerCase();
      if (!seenUrls.add(normalizedUrl)) continue;
      deduped.add(story);
    }

    deduped.sort((a, b) {
      if (preferLocalSources) {
        final sourcePriority = _localSourcePriority(b.source)
            .compareTo(_localSourcePriority(a.source));
        if (sourcePriority != 0) return sourcePriority;
      }

      final recency = b.publishedAt.compareTo(a.publishedAt);
      if (recency != 0) return recency;
      return b.score.compareTo(a.score);
    });

    return deduped.take(maxCount).toList();
  }

  String _cleanSource(String raw) {
    var value = raw.toLowerCase();
    if (value.startsWith('www.')) {
      value = value.substring(4);
    }
    return value;
  }

  ({String title, String source}) _splitTitleAndSource(String rawTitle) {
    final divider = rawTitle.lastIndexOf(' - ');
    if (divider <= 0 || divider >= rawTitle.length - 3) {
      return (title: rawTitle, source: 'news');
    }
    return (
      title: rawTitle.substring(0, divider).trim(),
      source: rawTitle.substring(divider + 3).trim(),
    );
  }

  bool _isAllowedLocalSource(String source, String url) {
    if (_isBlockedSource(source, url)) return false;
    if (source.endsWith('.tw')) return true;
    if (source.contains('taiwan')) return true;
    if (source.contains('taipei')) return true;
    if (source.contains('cna.com')) return true;
    if (source.contains('focus') || source.contains('nikkei')) return true;
    return true;
  }

  int _localSourcePriority(String source) {
    if (source.endsWith('.tw')) return 4;
    if (source.contains('taiwan')) return 3;
    if (source.contains('taipei') || source.contains('cna.com')) return 2;
    if (source.contains('focus') || source.contains('nikkei')) return 1;
    return 0;
  }

  bool _isBlockedSource(String source, String url) {
    final lowerSource = source.toLowerCase();
    final lowerUrl = url.toLowerCase();
    const blockedFragments = <String>[
      'reddit.com',
      'redd.it',
      'self.',
      'i.redd.it',
      'i.reddituploads.com',
      'youtube.com',
      'youtu.be',
      'imgur.com',
      'giphy.com',
      'v.redd.it',
      'gallery',
    ];

    for (final fragment in blockedFragments) {
      if (lowerSource.contains(fragment) || lowerUrl.contains(fragment)) {
        return true;
      }
    }
    return false;
  }

  String? _extractImageUrl(Map<String, dynamic> item) {
    final preview = item['preview'];
    if (preview is Map<String, dynamic>) {
      final images = preview['images'];
      if (images is List && images.isNotEmpty) {
        final first = images.first;
        if (first is Map<String, dynamic>) {
          final source = first['source'];
          if (source is Map<String, dynamic>) {
            final url = (source['url'] ?? '').toString().trim();
            if (url.startsWith('http')) {
              return url.replaceAll('&amp;', '&');
            }
          }
        }
      }
    }

    final thumbnail = (item['thumbnail'] ?? '').toString().trim();
    if (thumbnail.startsWith('http')) {
      return thumbnail.replaceAll('&amp;', '&');
    }
    return null;
  }

  String? _extractRssImageUrl(Map<String, dynamic> item) {
    final thumbnail = (item['thumbnail'] ?? '').toString().trim();
    if (thumbnail.startsWith('http')) return thumbnail;

    final enclosure = item['enclosure'];
    if (enclosure is Map<String, dynamic>) {
      final link = (enclosure['link'] ?? '').toString().trim();
      if (link.startsWith('http')) return link;
    }
    return null;
  }

  List<DashboardNewsStory> _fallbackStories(DashboardNewsDesk desk) {
    final now = DateTime.now();
    if (desk == DashboardNewsDesk.world) {
      return [
        DashboardNewsStory(
          desk: desk,
          title: 'Open Reuters World for the latest global coverage',
          source: 'reuters.com',
          url: 'https://www.reuters.com/world/',
          publishedAt: now,
          score: 0,
          commentCount: 0,
        ),
        DashboardNewsStory(
          desk: desk,
          title: 'Open BBC World for live developing stories',
          source: 'bbc.com',
          url: 'https://www.bbc.com/news/world',
          publishedAt: now.subtract(const Duration(minutes: 5)),
          score: 0,
          commentCount: 0,
        ),
      ];
    }

    return [
      DashboardNewsStory(
        desk: desk,
        title: 'Open Focus Taiwan for Taiwan and local reporting',
        source: 'focustaiwan.tw',
        url: 'https://focustaiwan.tw/',
        publishedAt: now,
        score: 0,
        commentCount: 0,
      ),
      DashboardNewsStory(
        desk: desk,
        title: 'Open Taipei Times for regional and school-adjacent coverage',
        source: 'taipeitimes.com',
        url: 'https://www.taipeitimes.com/',
        publishedAt: now.subtract(const Duration(minutes: 5)),
        score: 0,
        commentCount: 0,
      ),
    ];
  }
}
