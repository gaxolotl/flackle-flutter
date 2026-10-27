import 'package:flutter/material.dart';

import '../core/media.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../core/theme.dart';
import 'emoji.dart';
import 'icons.dart';

class FlackleScope extends InheritedNotifier<AppState> {
  const FlackleScope({required AppState state, required super.child, super.key})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FlackleScope>();
    assert(scope != null, 'FlackleScope is missing above this widget.');
    return scope!.notifier!;
  }

  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<FlackleScope>();
    assert(scope != null, 'FlackleScope is missing above this widget.');
    return scope!.notifier!;
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.url,
    required this.name,
    this.size = 40,
    this.square = false,
    this.ring,
    super.key,
  });

  final String? url;
  final String name;
  final double size;
  final bool square;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final radius = square ? BorderRadius.circular(size * 0.3) : null;
    final fallbackColor = _colorFromHex(avatarColor(name)) ?? c.accent;
    final hasImage = url != null && url!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor.withValues(alpha: 0.18),
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: radius,
        border: Border.all(
          color: ring ??
              (hasImage ? c.line : fallbackColor.withValues(alpha: 0.32)),
          width: ring == null ? 1 : 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: !hasImage
          ? Text(
              initials(name),
              style: TextStyle(
                color: fallbackColor,
                fontSize: size * 0.32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            )
          : AppImage(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Center(
                child: Text(
                  initials(name),
                  style: TextStyle(
                    color: fallbackColor,
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : _avatarPlaceholder(fallbackColor, size),
            ),
    );
  }

  Widget _avatarPlaceholder(Color color, double size) => Center(
        child: SizedBox(
          width: size * 0.3,
          height: size * 0.3,
          child: CircularProgressIndicator(strokeWidth: 1.4, color: color),
        ),
      );
}

Color? _colorFromHex(String? hex) {
  if (hex == null || !hex.startsWith('#')) return null;
  final value = hex.substring(1);
  final parsed = int.tryParse(
      value.length == 3
          ? value.split('').map((char) => '$char$char').join()
          : value.padRight(6, '0').substring(0, 6),
      radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}

class RoleIcon extends StatelessWidget {
  const RoleIcon({required this.role, this.size = 12, super.key});

  final Role? role;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = role;
    if (value == null) return const SizedBox.shrink();
    final iconUrl = value.iconUrl;
    if (iconUrl != null && iconUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: AppImage(
          iconUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            final emoji = value.iconEmoji;
            return emoji == null || emoji.isEmpty
                ? SizedBox(width: size, height: size)
                : EmojiGlyph(emoji, size: size);
          },
        ),
      );
    }
    final emoji = value.iconEmoji;
    if (emoji != null && emoji.isNotEmpty) {
      return EmojiGlyph(emoji, size: size);
    }
    return const SizedBox.shrink();
  }
}

class PresenceDot extends StatelessWidget {
  const PresenceDot(this.status, {this.size = 8, super.key});

  final String? status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = status ?? 'offline';
    final color = switch (normalized) {
      'online' => context.c.green,
      'idle' => context.c.yellow,
      'dnd' => context.c.danger,
      _ => context.c.muted,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: context.c.sidebar, width: 1.6),
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge(
    this.count, {
    this.mentions = false,
    this.compact = false,
    super.key,
  });

  final int count;
  final bool mentions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : '$count';
    final roundDot = compact && label.length == 1;
    return Container(
      width: roundDot ? 16 : null,
      height: roundDot ? 16 : null,
      constraints:
          roundDot ? null : BoxConstraints(minWidth: compact ? 17 : 19),
      padding: roundDot
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(
              horizontal: compact ? 4 : 6, vertical: compact ? 1 : 2),
      decoration: BoxDecoration(
        color: mentions ? context.c.accent : context.c.panel3,
        borderRadius: BorderRadius.circular(99),
        border: mentions ? null : Border.all(color: context.c.lineStrong),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: mentions ? Colors.white : context.c.textDim,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.trailing, this.padding, super.key});

  final String text;
  final Widget? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(4, 16, 4, 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text.toUpperCase(),
                style: TextStyle(
                  color: context.c.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.05,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class EmptyPane extends StatelessWidget {
  const EmptyPane({
    required this.icon,
    required this.title,
    this.detail,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: context.c.muted),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.c.text,
                  )),
              if (detail != null) ...[
                const SizedBox(height: 6),
                Text(detail!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: context.c.muted, fontSize: 13, height: 1.5)),
              ],
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ],
            ],
          ),
        ),
      );
}

class ErrorPane extends StatelessWidget {
  const ErrorPane({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 34, color: context.c.danger),
              const SizedBox(height: 12),
              Text('Could not reach Flackle',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.c.text,
                  )),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: context.c.muted, fontSize: 12, height: 1.5)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}

class LoadingPane extends StatelessWidget {
  const LoadingPane({this.label, super.key});

  final String? label;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.c.accent,
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: 10),
              Text(label!,
                  style: TextStyle(color: context.c.muted, fontSize: 12)),
            ],
          ],
        ),
      );
}

void showAppToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
    ));
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? body,
  String confirmLabel = 'Confirm',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, softWrap: true),
      content: body == null ? null : Text(body, softWrap: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: danger
              ? FilledButton.styleFrom(backgroundColor: context.c.danger)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

class MenuEntry {
  const MenuEntry({
    required this.label,
    this.icon,
    this.iconAsset,
    this.danger = false,
    this.disabled = false,
    this.separator = false,
    this.trailing,
    this.run,
  });

  final String label;
  final String? icon;
  final String? iconAsset;
  final bool danger;
  final bool disabled;
  final bool separator;
  final Widget? trailing;
  final VoidCallback? run;
}

Future<void> showAppMenu(
  BuildContext context, {
  String? title,
  required List<MenuEntry> entries,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.c.text,
                    ),
                  ),
                ),
              for (final entry in entries)
                if (entry.separator)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Divider(color: context.c.line),
                  )
                else
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: entry.disabled || entry.run == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            entry.run!();
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 11),
                      child: Row(
                        children: [
                          if (entry.iconAsset != null)
                            AppIcon('hash',
                                asset: entry.iconAsset,
                                size: 17,
                                color: entry.danger ? context.c.danger : null)
                          else if (entry.icon != null)
                            AppIcon(entry.icon!,
                                size: 17,
                                color: entry.danger ? context.c.danger : null),
                          if (entry.icon != null || entry.iconAsset != null)
                            const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.label,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: entry.disabled
                                    ? context.c.muted
                                    : entry.danger
                                        ? context.c.danger
                                        : context.c.text,
                              ),
                            ),
                          ),
                          if (entry.trailing != null) entry.trailing!,
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
    this.danger = false,
    this.expand = false,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final bool filled;
  final bool danger;
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AppIcon(icon!, size: 16, color: filled ? Colors.white : null),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );
    final style = danger
        ? (filled
            ? FilledButton.styleFrom(backgroundColor: context.c.danger)
            : OutlinedButton.styleFrom(
                foregroundColor: context.c.danger,
                side:
                    BorderSide(color: context.c.danger.withValues(alpha: 0.4)),
              ))
        : null;
    final button = filled
        ? FilledButton(
            onPressed: busy ? null : onPressed,
            style: style,
            child: child,
          )
        : OutlinedButton(
            onPressed: busy ? null : onPressed,
            style: style,
            child: child,
          );
    return expand
        ? SizedBox(width: double.infinity, height: 44, child: button)
        : button;
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {this.color, this.icon, this.small = false, super.key});

  final String text;
  final Color? color;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.c.muted;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: (small ? 9 : 11), color: tint),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: tint,
              fontSize: small ? 9 : 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class RolePill extends StatelessWidget {
  const RolePill(this.role, {this.onTap, super.key});

  final Role role;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(role.color) ?? context.c.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (role.iconEmoji != null) ...[
              EmojiGlyph(role.iconEmoji!, size: 11),
              const SizedBox(width: 4),
            ] else if (role.iconUrl != null) ...[
              AppAvatar(
                  url: role.iconUrl, name: role.name, size: 12, square: true),
              const SizedBox(width: 4),
            ] else ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              role.name,
              style: TextStyle(
                  color: color, fontSize: 10.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class MembersSummary extends StatelessWidget {
  const MembersSummary({required this.online, required this.total, super.key});

  final int online;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: context.c.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text('$online online · $total members',
              style: TextStyle(color: context.c.muted, fontSize: 11)),
        ],
      );
}

class ChannelGlyph extends StatelessWidget {
  const ChannelGlyph({
    required this.name,
    required this.color,
    this.type,
    this.size = 16,
    super.key,
  });

  final String? name;
  final String? color;
  final String? type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = _colorFromHex(color);
    if (name != null && name!.isNotEmpty) {
      if (EmojiIndex.isEmoji(name!)) {
        return EmojiGlyph(name!, size: size);
      }
      final asset = 'assets/channel-icons/$name.svg';
      if (BrandAssets.has(asset)) {
        return AppIcon('hash',
            asset: name, size: size, color: tint ?? context.c.textDim);
      }
    }
    return Icon(
      channelFallbackIcon(type),
      size: size,
      color: tint ?? context.c.textDim,
    );
  }
}
