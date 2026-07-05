import 'package:flutter/material.dart';

import 'theme.dart';

/// Signature for building a demo page.
///
/// The demo's own [DemoInfo] is passed back so the page can forward its
/// description / API list to [DemoScaffold] without duplicating the text.
typedef DemoPageBuilder = Widget Function(BuildContext context, DemoInfo info);

/// Metadata describing a single showcase demo.
///
/// The home gallery renders one card per [DemoInfo], and [DemoScaffold] reuses
/// the same [description] / [apis] to build the "About this demo" sheet.
@immutable
class DemoInfo {
  const DemoInfo({
    required this.title,
    required this.tagline,
    required this.description,
    required this.apis,
    required this.icon,
    required this.accent,
    required this.builder,
  });

  /// Short display name (e.g. "Autoplay feed").
  final String title;

  /// One-line hook shown on the gallery card.
  final String tagline;

  /// Longer paragraph shown in the about sheet.
  final String description;

  /// Public scroll_spy API names this demo exercises.
  final List<String> apis;

  /// Icon shown on the gallery card and app bar.
  final IconData icon;

  /// Accent color for this demo.
  final Color accent;

  /// Builds the demo page (receives this same [DemoInfo]).
  final DemoPageBuilder builder;
}

/// Shared scaffold for every demo page.
///
/// Provides a consistent app bar with an info button that reveals what
/// scroll_spy APIs the demo demonstrates.
class DemoScaffold extends StatelessWidget {
  const DemoScaffold({
    super.key,
    required this.title,
    required this.body,
    this.accent = SpyColors.accent,
    this.description,
    this.apis = const <String>[],
    this.actions = const <Widget>[],
    this.floatingActionButton,
    this.bottomBar,
    this.extendBodyBehindAppBar = false,
  });

  final String title;
  final Widget body;
  final Color accent;
  final String? description;
  final List<String> apis;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final Widget? bottomBar;
  final bool extendBodyBehindAppBar;

  void _showAbout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SpyColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    description!,
                    style: const TextStyle(
                      color: SpyColors.muted,
                      height: 1.5,
                      fontSize: 15,
                    ),
                  ),
                ],
                if (apis.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const SectionLabel('APIs in this demo'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final api in apis) CodeChip(api, accent: accent),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: extendBodyBehindAppBar
            ? Colors.transparent
            : SpyColors.bg,
        actions: [
          ...actions,
          if (description != null)
            IconButton(
              tooltip: 'About this demo',
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () => _showAbout(context),
            ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
      body: body,
    );
  }
}

/// A small uppercase section label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color = SpyColors.muted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// A monospace-looking chip for API / code names.
class CodeChip extends StatelessWidget {
  const CodeChip(this.label, {super.key, this.accent = SpyColors.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Color.lerp(accent, Colors.white, 0.35),
          fontSize: 12.5,
          fontFamily: 'monospace',
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// A rounded status pill with an icon, color, and active/idle styling.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    this.active = true,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color c = active ? color : SpyColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: active ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// A labeled thin progress bar for showing a normalized 0..1 metric.
class MetricBar extends StatelessWidget {
  const MetricBar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.trailing,
  });

  final String label;
  final double value;
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final double v = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SpyColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailing ?? '${(v * 100).round()}%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: v,
            minHeight: 6,
            backgroundColor: SpyColors.surfaceHigh,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

/// A legend swatch + label used to explain overlay colors.
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: SpyColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// A surface container with hairline border and rounded corners.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = SpyColors.surface,
    this.borderColor = SpyColors.stroke,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

/// Deterministic pleasant gradient for a given index (used by mock content).
LinearGradient demoGradient(int index) {
  const List<List<Color>> palettes = [
    [Color(0xFF7C5CFF), Color(0xFF4423B0)],
    [Color(0xFF22D3EE), Color(0xFF0E7490)],
    [Color(0xFFFF6B6B), Color(0xFFB01919)],
    [Color(0xFF34C759), Color(0xFF15803D)],
    [Color(0xFFFFB020), Color(0xFFB45309)],
    [Color(0xFFFF5CA8), Color(0xFF9D174D)],
    [Color(0xFF5C9BFF), Color(0xFF1D4ED8)],
    [Color(0xFF9D5CFF), Color(0xFF6B21A8)],
  ];
  final colors = palettes[index % palettes.length];
  return LinearGradient(
    colors: colors,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
