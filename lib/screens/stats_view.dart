import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../ui/common.dart';
import '../ui/icons.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({required this.serverId, required this.channel, super.key});

  final String serverId;
  final Channel channel;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  AnalyticsBundle? _bundle;
  List<Map<String, dynamic>> _calendar = const [];
  List<Map<String, dynamic>> _punchcard = const [];
  String? _scope;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = FlackleScope.read(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle =
          await state.client.fetchAnalytics(widget.serverId, widget.channel.id);
      final results = await Future.wait([
        state.client
            .fetchActivityCalendar(
                widget.serverId, widget.channel.id, DateTime.now().year)
            .catchError((Object _) => <Map<String, dynamic>>[]),
        state.client
            .fetchPunchcard(widget.serverId, widget.channel.id, 30)
            .catchError((Object _) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _calendar = results[0];
        _punchcard = results[1];
        _scope = bundle.scopes.isEmpty ? null : bundle.scopes.keys.first;
      });
    } catch (failure) {
      if (mounted) setState(() => _error = failure.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bundle = _bundle;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.channel.name),
            Text('Channel analytics',
                style: TextStyle(
                    color: c.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh stats',
            icon: const Icon(Icons.refresh_rounded, size: 19),
          ),
        ],
      ),
      body: _loading
          ? const LoadingPane(label: 'Loading analytics')
          : _error != null
              ? ErrorPane(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      Row(
                        children: [
                          _metric(context, 'Members',
                              '${bundle?.memberCount ?? 0}', 'users'),
                          const SizedBox(width: 9),
                          _metric(context, 'Online',
                              '${bundle?.presenceCount ?? 0}', 'wifi'),
                          const SizedBox(width: 9),
                          _metric(context, 'In voice',
                              '${bundle?.voiceCount ?? 0}', 'speaker'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (bundle != null && bundle.scopes.isNotEmpty) ...[
                        Row(
                          children: [
                            Text('Activity',
                                style: context.display(16,
                                    weight: FontWeight.w600)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                child: Row(
                                  children: [
                                    for (final key in bundle.scopes.keys)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 5),
                                        child: ChoiceChip(
                                          label: Text(scopeLabel(key)),
                                          selected: _scope == key,
                                          onSelected: (_) =>
                                              setState(() => _scope = key),
                                          showCheckmark: false,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _chartCard(
                            context,
                            bundle.scopes[_scope] ??
                                bundle.scopes.values.first),
                        const SizedBox(height: 18),
                      ],
                      Text('Message heatmap',
                          style: context.display(16, weight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      _heatmap(context),
                      const SizedBox(height: 18),
                      Text('Hourly rhythm (30 days)',
                          style: context.display(16, weight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      _punchcardCard(context),
                      const SizedBox(height: 16),
                      Text(
                        'Stats channels are read-only snapshots provided by Flackle. Elevated figures follow your account permissions.',
                        style: context.label(11, color: c.muted, height: 1.5),
                      ),
                    ],
                  ),
                ),
    );
  }

  String scopeLabel(String key) => switch (key) {
        'hour' || 'hours' => '1h',
        'day' || 'daily' => '24h',
        'week' || 'weekly' => '7d',
        'month' || 'monthly' => '30d',
        _ => key,
      };

  Widget _metric(
      BuildContext context, String label, String value, String icon) {
    final c = context.c;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: c.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(icon, size: 13, color: c.accent),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.label(10,
                          color: c.muted, weight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(value,
                style: context.display(24,
                    weight: FontWeight.w600, letterSpacing: -0.8)),
          ],
        ),
      ),
    );
  }

  Widget _chartCard(BuildContext context, AnalyticsScope scope) {
    final c = context.c;
    final points = scope.series;
    if (points.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.line),
        ),
        child: Text('No samples for this range yet.',
            style: context.label(12, color: c.muted)),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _legend(c.green, 'Members'),
              const SizedBox(width: 12),
              _legend(c.accent, 'Online'),
              const SizedBox(width: 12),
              _legend(c.yellow, 'Voice'),
              const Spacer(),
              Text('${points.length} samples',
                  style: context.label(10, color: c.muted)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 170,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SeriesPainter(
                series: [
                  points.map((point) => point.memberCount.toDouble()).toList(),
                  points
                      .map((point) => point.presenceCount.toDouble())
                      .toList(),
                  points.map((point) => point.voicePeak.toDouble()).toList(),
                ],
                colors: [c.green, c.accent, c.yellow],
                grid: c.line,
                maxValue: _maxOf(points),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                points.first.at == null ? '' : formatShort(points.first.at!),
                style: context.label(9.5, color: c.muted),
              ),
              const Spacer(),
              Text(
                points.last.at == null ? '' : formatShort(points.last.at!),
                style: context.label(9.5, color: c.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: context.c.muted)),
        ],
      );

  double _maxOf(List<AnalyticsPoint> points) {
    var max = 1.0;
    for (final point in points) {
      max = math.max(max, point.memberCount.toDouble());
      max = math.max(max, point.presenceCount.toDouble());
      max = math.max(max, point.voicePeak.toDouble());
    }
    return max * 1.15;
  }

  Widget _heatmap(BuildContext context) {
    final c = context.c;
    final counts = <int, int>{};
    for (final day in _calendar) {
      final date = DateTime.tryParse('${day['date'] ?? ''}');
      final count = day['count'] is num ? (day['count'] as num).toInt() : 0;
      if (date != null) counts[date.day] = count;
    }
    final year = DateTime.now().year;
    final daysInYear =
        DateTime(year, 12, 31).difference(DateTime(year)).inDays + 1;
    final maxCount = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_calendar.isEmpty ? 'No calendar data yet.' : '$year',
              style: context.label(11, color: c.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [
              for (var i = 0; i < daysInYear; i++)
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _heatColor(c, counts[(i % 365) + 1] ?? 0, maxCount),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _heatColor(FlackleColors c, int value, int maxValue) {
    if (value <= 0) return c.panel3;
    final ratio = (value / maxValue).clamp(0.15, 1.0);
    return c.accent.withValues(alpha: 0.15 + ratio * 0.75);
  }

  Widget _punchcardCard(BuildContext context) {
    final c = context.c;
    final grid = List.generate(7, (_) => List<int>.filled(24, 0));
    for (final cell in _punchcard) {
      final date = DateTime.tryParse('${cell['date'] ?? ''}');
      final hour = cell['hour'] is num ? (cell['hour'] as num).toInt() : -1;
      final count = cell['count'] is num ? (cell['count'] as num).toInt() : 0;
      if (date == null || hour < 0 || hour > 23) continue;
      final index = (date.weekday - 1) % 7;
      grid[index][hour] += count;
    }
    var max = 1;
    for (final row in grid) {
      for (final value in row) {
        max = math.max(max, value);
      }
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line),
      ),
      child: _punchcard.isEmpty
          ? Text('No punchcard data yet.',
              style: context.label(12, color: c.muted))
          : Column(
              children: [
                for (var row = 0; row < 7; row++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text(
                            const [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun'
                            ][row],
                            style: context.label(8.5, color: c.muted),
                          ),
                        ),
                        for (var hour = 0; hour < 24; hour++)
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              height: 12,
                              decoration: BoxDecoration(
                                color: grid[row][hour] == 0
                                    ? c.panel3
                                    : c.accent.withValues(
                                        alpha: 0.18 +
                                            (grid[row][hour] / max)
                                                    .clamp(0.0, 1.0) *
                                                0.75),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  String formatShort(DateTime date) =>
      '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:00';
}

class _SeriesPainter extends CustomPainter {
  _SeriesPainter({
    required this.series,
    required this.colors,
    required this.grid,
    required this.maxValue,
  });

  final List<List<double>> series;
  final List<Color> colors;
  final Color grid;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var line = 1; line <= 3; line++) {
      final y = size.height * (line / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var index = 0; index < series.length; index++) {
      final values = series[index];
      if (values.length < 2) continue;
      final paint = Paint()
        ..color = colors[index % colors.length]
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final path = Path();
      for (var point = 0; point < values.length; point++) {
        final x = size.width * (point / (values.length - 1));
        final y = size.height - (values[point] / maxValue) * size.height;
        if (point == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SeriesPainter oldDelegate) =>
      oldDelegate.series != series || oldDelegate.maxValue != maxValue;
}
