import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';

/// Caches only viewed public tiles, without prefetching or user credentials.
class PublicMapTileProvider extends TileProvider {
  static final cache = CacheManager(Config('eyoonak-public-map-v1',
      stalePeriod: const Duration(days: 7), maxNrOfCacheObjects: 500));
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      CachedNetworkImageProvider(getTileUrl(coordinates, options),
          cacheManager: cache, headers: headers);
}
