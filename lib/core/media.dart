/// Resolves media URLs for the current target.
///
/// Native builds load Flackle's CDN directly. Web builds can be served through
/// the dev proxy (`--dart-define=FLACKLE_MEDIA_PROXY=/media?url=`) because the
/// CDN does not send CORS headers for arbitrary origins.
library;

import 'package:flutter/material.dart';

const String _mediaProxy =
    String.fromEnvironment('FLACKLE_MEDIA_PROXY', defaultValue: '');

String mediaUrl(String url) {
  if (_mediaProxy.isEmpty || url.isEmpty) return url;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return url;
  if (uri.host == 'localhost' || uri.host == '127.0.0.1') return url;
  return '$_mediaProxy${Uri.encodeComponent(url)}';
}

/// Inline image that goes through the media resolver.
class AppImage extends StatelessWidget {
  const AppImage(
    this.url, {
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.errorBuilder,
    this.loadingBuilder,
    super.key,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return errorBuilder?.call(
            context,
            StateError('empty media url'),
            null,
          ) ??
          SizedBox(width: width, height: height);
    }
    return Image.network(
      mediaUrl(url),
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
      gaplessPlayback: true,
    );
  }
}
