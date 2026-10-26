import 'package:characters/characters.dart';
import 'package:intl/intl.dart';

enum RichStyle { bold, italic, underline, strike, code, block }

enum MentionKind { user, role, channel }

class RichToken {
  const RichToken.text(this.text,
      {this.styles = const {}, this.mention, this.mentionId, this.url})
      : newline = false;

  const RichToken.mention(MentionKind kind, this.mentionId)
      : text = '',
        styles = const {},
        mention = kind,
        url = null,
        newline = false;

  const RichToken.link(this.url, this.text)
      : styles = const {},
        mention = null,
        mentionId = null,
        newline = false;

  const RichToken.lineBreak()
      : text = '\n',
        styles = const {},
        mention = null,
        mentionId = null,
        url = null,
        newline = true;

  final String text;
  final Set<RichStyle> styles;
  final MentionKind? mention;
  final String? mentionId;
  final String? url;
  final bool newline;
}

const _refStart = '\uE000';
const _refEnd = '\uE001';

/// Parses Flackle's message markup into tokens. Mentions stay symbolic until
/// the renderer resolves them against the server's members and roles.
List<RichToken> parseMessageContent(String content) {
  final refs = <RichToken>[];
  final source = content.replaceAllMapped(
    RegExp(r'<@&(\d+)>|<@!?(\d+)>|<#(\d+)>'),
    (match) {
      final index = refs.length;
      if (match.group(1) != null) {
        refs.add(RichToken.mention(MentionKind.role, match.group(1)));
      } else if (match.group(2) != null) {
        refs.add(RichToken.mention(MentionKind.user, match.group(2)));
      } else {
        refs.add(RichToken.mention(MentionKind.channel, match.group(3)));
      }
      return '$_refStart$index$_refEnd';
    },
  );

  final raw = <RichToken>[];
  _parseMarkdown(source, const {}, raw);

  final result = <RichToken>[];
  for (final token in raw) {
    if (token.mention != null || token.url != null || token.newline) {
      result.add(token);
      continue;
    }
    var remaining = token.text;
    while (remaining.isNotEmpty) {
      final start = remaining.indexOf(_refStart);
      if (start == -1) {
        result.add(RichToken.text(remaining, styles: token.styles));
        break;
      }
      if (start > 0) {
        result.add(RichToken.text(remaining.substring(0, start),
            styles: token.styles));
      }
      final end = remaining.indexOf(_refEnd, start);
      if (end == -1) {
        result.add(RichToken.text(remaining, styles: token.styles));
        break;
      }
      final number = int.tryParse(remaining.substring(start + 1, end));
      if (number != null && number < refs.length) {
        result.add(refs[number]);
      }
      remaining = remaining.substring(end + 1);
    }
  }
  return result;
}

void _parseMarkdown(String text, Set<RichStyle> styles, List<RichToken> out) {
  var index = 0;
  final buffer = StringBuffer();

  void flush() {
    if (buffer.isEmpty) return;
    out.add(RichToken.text(buffer.toString(), styles: styles));
    buffer.clear();
  }

  while (index < text.length) {
    final rest = text.substring(index);
    if (rest.startsWith('```')) {
      final end = text.indexOf('```', index + 3);
      flush();
      final body = end == -1
          ? text.substring(index + 3)
          : text.substring(index + 3, end);
      out.add(
          RichToken.text(body.trim(), styles: {...styles, RichStyle.block}));
      index = end == -1 ? text.length : end + 3;
      continue;
    }
    if (rest.startsWith('**')) {
      final end = _findClosing(text, index + 2, '**');
      if (end != -1) {
        flush();
        _parseMarkdown(
            text.substring(index + 2, end), {...styles, RichStyle.bold}, out);
        index = end + 2;
        continue;
      }
    }
    if (rest.startsWith('__')) {
      final end = _findClosing(text, index + 2, '__');
      if (end != -1) {
        flush();
        _parseMarkdown(text.substring(index + 2, end),
            {...styles, RichStyle.underline}, out);
        index = end + 2;
        continue;
      }
    }
    if (rest.startsWith('~~')) {
      final end = _findClosing(text, index + 2, '~~');
      if (end != -1) {
        flush();
        _parseMarkdown(
            text.substring(index + 2, end), {...styles, RichStyle.strike}, out);
        index = end + 2;
        continue;
      }
    }
    if (rest.startsWith('`')) {
      final end = text.indexOf('`', index + 1);
      if (end != -1) {
        flush();
        out.add(RichToken.text(text.substring(index + 1, end),
            styles: {...styles, RichStyle.code}));
        index = end + 1;
        continue;
      }
    }
    if (rest.startsWith('*') && !rest.startsWith('**')) {
      final end = _findClosing(text, index + 1, '*');
      if (end != -1) {
        flush();
        _parseMarkdown(
            text.substring(index + 1, end), {...styles, RichStyle.italic}, out);
        index = end + 1;
        continue;
      }
    }
    if (rest.startsWith('_') && !rest.startsWith('__')) {
      final end = text.indexOf('_', index + 1);
      if (end != -1) {
        flush();
        _parseMarkdown(
            text.substring(index + 1, end), {...styles, RichStyle.italic}, out);
        index = end + 1;
        continue;
      }
    }
    if (rest.startsWith('http://') || rest.startsWith('https://')) {
      final match = RegExp(r'^https?://[^\s<>]+').firstMatch(rest);
      if (match != null) {
        var url = match.group(0)!;
        while (url.isNotEmpty && '.,!?)"]}\''.contains(url[url.length - 1])) {
          url = url.substring(0, url.length - 1);
        }
        if (url.length > 8) {
          flush();
          out.add(RichToken.link(url, url));
          index += url.length;
          continue;
        }
      }
    }
    if (rest.startsWith('\n')) {
      flush();
      out.add(const RichToken.lineBreak());
      index += 1;
      continue;
    }
    buffer.write(text[index]);
    index += 1;
  }
  flush();
}

int _findClosing(String text, int start, String delimiter) {
  final index = text.indexOf(delimiter, start);
  if (index == -1 || index == start) return -1;
  return index;
}

String formatTime(DateTime? date, {bool use24h = false}) {
  if (date == null) return '';
  return DateFormat(use24h ? 'HH:mm' : 'h:mm a').format(date);
}

String formatDay(DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return DateFormat.yMMMMd().format(date);
}

String formatDayShort(DateTime? date) {
  if (date == null) return '';
  return DateFormat.MMMd().format(date);
}

String formatSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

String relativeTime(DateTime? date) {
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.yMMMd().format(date);
}

String initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  if (parts.isEmpty) return 'F';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

const _avatarPalette = [
  '#ff6b5e',
  '#7c5cff',
  '#2ec4a6',
  '#f2a33c',
  '#4aa8ff',
  '#e05ea8',
  '#9ad14b',
];

String avatarColor(String name) {
  if (name.isEmpty) return _avatarPalette[0];
  return _avatarPalette[name.codeUnitAt(0) % _avatarPalette.length];
}

String truncateText(String value, [int limit = 60]) {
  final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= limit) return compact;
  return '${compact.substring(0, limit).trimRight()}...';
}

bool sameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String formatMonthDay(DateTime date) => DateFormat.MMMd().format(date);

String formatSlowmode(int seconds) {
  if (seconds <= 0) return '';
  if (seconds >= 3600) {
    final hours = seconds / 3600;
    return hours == hours.roundToDouble()
        ? '${hours.round()}H'
        : '${hours.toStringAsFixed(1)}H';
  }
  if (seconds >= 60) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return rest == 0 ? '${minutes}M' : '${minutes}M ${rest}S';
  }
  return '${seconds}S';
}
