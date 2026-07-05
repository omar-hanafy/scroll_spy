import 'package:flutter/material.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../common.dart';
import '../theme.dart';

enum _RegionKind { line, zone, custom }

enum _PolicyKind { closest, visible, overlap, progress }

enum _UpdateKind { perFrame, onScrollEnd, hybrid }

/// Interactive lab exposing every scroll_spy configuration knob with the
/// built-in debug overlay always on, so changes are immediately visible.
class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({super.key, required this.info});

  final DemoInfo info;

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  final ScrollSpyController<int> _spy = ScrollSpyController<int>();
  final ScrollController _scroll = ScrollController();

  static const int _itemCount = 40;

  // Config state.
  _RegionKind _region = _RegionKind.zone;
  _PolicyKind _policy = _PolicyKind.closest;
  _UpdateKind _update = _UpdateKind.hybrid;
  double _anchor = 0.5;
  double _zoneExtent = 200;
  double _lineThickness = 2;
  double _hysteresis = 20;
  double _minPrimaryMs = 120;
  bool _preferCurrent = true;
  bool _allowWhenNone = true;

  @override
  void dispose() {
    _spy.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ScrollSpyRegion get _regionConfig {
    final anchor = ScrollSpyAnchor.fraction(_anchor);
    switch (_region) {
      case _RegionKind.line:
        return ScrollSpyRegion.line(
          anchor: anchor,
          thicknessPx: _lineThickness,
        );
      case _RegionKind.zone:
        return ScrollSpyRegion.zone(anchor: anchor, extentPx: _zoneExtent);
      case _RegionKind.custom:
        return ScrollSpyRegion.custom(anchor: anchor, evaluator: _customBand);
    }
  }

  /// A custom asymmetric band: focus extends 180px *below* the anchor only.
  static ScrollSpyRegionResult _customBand(ScrollSpyRegionInput input) {
    const double band = 180;
    final double start = input.anchorOffsetPx;
    final double end = start + band;
    final double s = input.itemMainAxisStart;
    final double e = input.itemMainAxisEnd;
    final double overlap = (e < end ? e : end) - (s > start ? s : start);
    if (overlap <= 0) return ScrollSpyRegionResult.notFocused;
    final double center = input.itemMainAxisCenter;
    final double dist = (center - (start + end) / 2).abs();
    return ScrollSpyRegionResult(
      isFocused: true,
      focusProgress: (1 - dist / (band / 2)).clamp(0.0, 1.0),
      overlapFraction: (overlap / band).clamp(0.0, 1.0),
    );
  }

  ScrollSpyPolicy<int> get _policyConfig {
    switch (_policy) {
      case _PolicyKind.closest:
        return const ScrollSpyPolicy.closestToAnchor();
      case _PolicyKind.visible:
        return const ScrollSpyPolicy.largestVisibleFraction();
      case _PolicyKind.overlap:
        return const ScrollSpyPolicy.largestFocusOverlap();
      case _PolicyKind.progress:
        return const ScrollSpyPolicy.largestFocusProgress();
    }
  }

  ScrollSpyUpdatePolicy get _updateConfig {
    switch (_update) {
      case _UpdateKind.perFrame:
        return const ScrollSpyUpdatePolicy.perFrame();
      case _UpdateKind.onScrollEnd:
        return ScrollSpyUpdatePolicy.onScrollEnd();
      case _UpdateKind.hybrid:
        return ScrollSpyUpdatePolicy.hybrid();
    }
  }

  void _openControls() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SpyColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            // Apply a mutation to both the page and the sheet.
            void apply(VoidCallback fn) {
              setState(fn);
              setSheet(() {});
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.92,
              minChildSize: 0.4,
              builder: (context, controller) {
                return ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    const SectionLabel('Focus region'),
                    const SizedBox(height: 10),
                    SegmentedButton<_RegionKind>(
                      segments: const [
                        ButtonSegment(
                          value: _RegionKind.line,
                          label: Text('Line'),
                        ),
                        ButtonSegment(
                          value: _RegionKind.zone,
                          label: Text('Zone'),
                        ),
                        ButtonSegment(
                          value: _RegionKind.custom,
                          label: Text('Custom'),
                        ),
                      ],
                      selected: {_region},
                      onSelectionChanged: (s) => apply(() => _region = s.first),
                    ),
                    const SizedBox(height: 8),
                    _SliderRow(
                      label: 'anchor fraction',
                      valueLabel: _anchor.toStringAsFixed(2),
                      value: _anchor,
                      min: 0,
                      max: 1,
                      onChanged: (v) => apply(() => _anchor = v),
                    ),
                    if (_region == _RegionKind.zone)
                      _SliderRow(
                        label: 'zone extentPx',
                        valueLabel: '${_zoneExtent.round()}px',
                        value: _zoneExtent,
                        min: 40,
                        max: 400,
                        onChanged: (v) => apply(() => _zoneExtent = v),
                      ),
                    if (_region == _RegionKind.line)
                      _SliderRow(
                        label: 'line thicknessPx',
                        valueLabel: '${_lineThickness.round()}px',
                        value: _lineThickness,
                        min: 0,
                        max: 80,
                        onChanged: (v) => apply(() => _lineThickness = v),
                      ),
                    if (_region == _RegionKind.custom)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Custom evaluator: focus extends 180px below the '
                          'anchor only (asymmetric band).',
                          style: TextStyle(
                            color: SpyColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 22),
                    const SectionLabel('Selection policy'),
                    const SizedBox(height: 10),
                    _policyDropdown(apply),
                    const SizedBox(height: 22),
                    const SectionLabel('Stability'),
                    const SizedBox(height: 10),
                    _SliderRow(
                      label: 'hysteresisPx',
                      valueLabel: '${_hysteresis.round()}px',
                      value: _hysteresis,
                      min: 0,
                      max: 80,
                      onChanged: (v) => apply(() => _hysteresis = v),
                    ),
                    _SliderRow(
                      label: 'minPrimaryDuration',
                      valueLabel: '${_minPrimaryMs.round()}ms',
                      value: _minPrimaryMs,
                      min: 0,
                      max: 600,
                      onChanged: (v) => apply(() => _minPrimaryMs = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('preferCurrentPrimary'),
                      value: _preferCurrent,
                      onChanged: (v) => apply(() => _preferCurrent = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('allowPrimaryWhenNoItemFocused'),
                      value: _allowWhenNone,
                      onChanged: (v) => apply(() => _allowWhenNone = v),
                    ),
                    const SizedBox(height: 12),
                    const SectionLabel('Update cadence'),
                    const SizedBox(height: 10),
                    SegmentedButton<_UpdateKind>(
                      segments: const [
                        ButtonSegment(
                          value: _UpdateKind.perFrame,
                          label: Text('perFrame'),
                        ),
                        ButtonSegment(
                          value: _UpdateKind.onScrollEnd,
                          label: Text('scrollEnd'),
                        ),
                        ButtonSegment(
                          value: _UpdateKind.hybrid,
                          label: Text('hybrid'),
                        ),
                      ],
                      selected: {_update},
                      onSelectionChanged: (s) => apply(() => _update = s.first),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: widget.info.title,
      accent: widget.info.accent,
      description: widget.info.description,
      apis: widget.info.apis,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openControls,
        backgroundColor: widget.info.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.tune_rounded),
        label: const Text('Configure'),
      ),
      body: Column(
        children: [
          _StatusHeader(controller: _spy, itemCount: _itemCount),
          Expanded(
            child: ScrollSpyScope<int>(
              controller: _spy,
              scrollController: _scroll,
              region: _regionConfig,
              policy: _policyConfig,
              updatePolicy: _updateConfig,
              stability: ScrollSpyStability(
                hysteresisPx: _hysteresis,
                minPrimaryDuration: Duration(
                  milliseconds: _minPrimaryMs.round(),
                ),
                preferCurrentPrimary: _preferCurrent,
                allowPrimaryWhenNoItemFocused: _allowWhenNone,
              ),
              debug: true,
              debugConfig: const ScrollSpyDebugConfig(
                showViewportBounds: true,
                showFocusRegion: true,
                showItemBounds: true,
                showVisibleBounds: true,
                showPrimaryOutline: true,
                showFocusedOutlines: true,
                showLabels: true,
              ),
              child: ListView.builder(
                controller: _scroll,
                itemCount: _itemCount,
                itemExtent: 108,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  return ScrollSpyItem<int>(
                    id: index,
                    builder: (context, focus, _) =>
                        _PlaygroundTile(index: index, focus: focus),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _policyDropdown(void Function(VoidCallback) apply) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: SpyColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_PolicyKind>(
          value: _policy,
          isExpanded: true,
          dropdownColor: SpyColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          items: const [
            DropdownMenuItem(
              value: _PolicyKind.closest,
              child: Text('closestToAnchor'),
            ),
            DropdownMenuItem(
              value: _PolicyKind.visible,
              child: Text('largestVisibleFraction'),
            ),
            DropdownMenuItem(
              value: _PolicyKind.overlap,
              child: Text('largestFocusOverlap'),
            ),
            DropdownMenuItem(
              value: _PolicyKind.progress,
              child: Text('largestFocusProgress'),
            ),
          ],
          onChanged: (v) => apply(() => _policy = v ?? _policy),
        ),
      ),
    );
  }
}

/// A labeled slider row used inside the controls sheet.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13.5)),
            const Spacer(),
            Text(
              valueLabel,
              style: const TextStyle(
                color: SpyColors.accent,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

/// Live readout of the engine's published state, driven by the snapshot.
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.controller, required this.itemCount});

  final ScrollSpyController<int> controller;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SpyColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: ScrollSpySnapshotBuilder<int>(
        controller: controller,
        builder: (context, snap, _) {
          final primary = snap.primaryId;
          return Row(
            children: [
              Expanded(
                child: _stat(
                  'primary',
                  primary == null ? '-' : '#$primary',
                  SpyColors.primary,
                ),
              ),
              Expanded(
                child: _stat(
                  'focused',
                  '${snap.focusedIds.length}',
                  SpyColors.focused,
                ),
              ),
              Expanded(
                child: _stat(
                  'visible',
                  '${snap.visibleIds.length}',
                  SpyColors.visible,
                ),
              ),
              Expanded(
                child: _stat(
                  'measured',
                  '${snap.items.length}',
                  SpyColors.muted,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label, color: color),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _PlaygroundTile extends StatelessWidget {
  const _PlaygroundTile({required this.index, required this.focus});

  final int index;
  final ScrollSpyItemFocus<int> focus;

  @override
  Widget build(BuildContext context) {
    final Color border = focus.isPrimary
        ? SpyColors.primary
        : focus.isFocused
        ? SpyColors.focused
        : focus.isVisible
        ? SpyColors.visible.withValues(alpha: 0.5)
        : SpyColors.stroke;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GlassCard(
        borderColor: border,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: demoGradient(index),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: MetricBar(
                label: 'visible',
                value: focus.visibleFraction,
                color: SpyColors.visible,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: MetricBar(
                label: 'focus',
                value: focus.focusProgress,
                color: SpyColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
