import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme.dart';

/// Names bundled from the desktop client's Icon.svelte.
const kIconNames = <String>{
  'hash',
  'speaker',
  'settings',
  'plus',
  'search',
  'users',
  'send',
  'paperclip',
  'smile',
  'reply',
  'pencil',
  'trash',
  'close',
  'minimize',
  'maximize',
  'restore',
  'chevron',
  'home',
  'dm',
  'check',
  'clock',
  'alert',
  'more',
  'crown',
  'pin',
  'wifiOff',
  'bell',
  'image',
  'download',
  'at',
  'command',
  'palette',
  'sliders',
  'copy',
  'server',
  'lock',
  'link',
  'up',
  'down',
  'trendUp',
  'trendDown',
  'minus',
  'shield',
  'ban',
  'chart',
  'sparkles',
  'gift',
  'reload',
  'user',
  'userPlus',
  'mail',
  'translate',
  'languages',
};

class BrandAssets {
  static final Set<String> _assets = {};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _assets.addAll(manifest.listAssets());
    } catch (_) {
      _assets.addAll(kIconNames.map((name) => 'assets/icons/$name.svg'));
    }
    _loaded = true;
  }

  static bool has(String path) => _assets.contains(path);
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {this.size = 18, this.color, this.asset, super.key});

  final String name;
  final double size;
  final Color? color;

  /// Allows callers to show a Heroicons channel glyph by asset name.
  final String? asset;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.c.textDim;
    final channelAsset =
        asset == null ? null : 'assets/channel-icons/$asset.svg';
    if (channelAsset != null && BrandAssets.has(channelAsset)) {
      return SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          channelAsset,
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
        ),
      );
    }
    if (!kIconNames.contains(name)) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.circle_outlined, size: size * 0.8, color: tint),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/icons/$name.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      ),
    );
  }
}

class FlackleMark extends StatelessWidget {
  const FlackleMark({this.size = 28, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/brand/mark.svg',
        width: size,
        height: size,
        colorFilter:
            ColorFilter.mode(color ?? context.c.accent, BlendMode.srcIn),
      );
}

class FlackleWordmark extends StatelessWidget {
  const FlackleWordmark(
      {this.markSize = 26,
      this.fontSize = 20,
      this.showBeta = false,
      super.key});

  final double markSize;
  final double fontSize;
  final bool showBeta;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlackleMark(size: markSize),
          const SizedBox(width: 9),
          Flexible(
              child: Text(
            'Flackle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: context.c.text,
            ),
          )),
          if (showBeta) ...[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: context.c.accentDim,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'BETA',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: context.c.accent,
                ),
              ),
            ),
          ],
        ],
      );
}

IconData channelFallbackIcon(String? type) => switch (type) {
      'voice' => Icons.volume_up_outlined,
      'stats' => Icons.bar_chart_rounded,
      _ => Icons.tag_rounded,
    };
