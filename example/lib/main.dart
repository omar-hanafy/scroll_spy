import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:viewport_focus/viewport_focus.dart';

void main() {
  runApp(const ViewportFocusExampleApp());
}

class ViewportFocusExampleApp extends StatelessWidget {
  const ViewportFocusExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'viewport_focus example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const ViewportFocusDemoPage(),
    );
  }
}

enum _RegionKind { zone, line }

enum _PolicyKind {
  closestToAnchor,
  largestVisibleFraction,
  largestFocusOverlap,
  largestFocusProgress,
}

enum _UpdatePolicyKind { perFrame, onScrollEnd, hybrid }

class ViewportFocusDemoPage extends StatefulWidget {
  const ViewportFocusDemoPage({super.key});

  @override
  State<ViewportFocusDemoPage> createState() => _ViewportFocusDemoPageState();
}

class _ViewportFocusDemoPageState extends State<ViewportFocusDemoPage> {
  final ViewportFocusController<int> _focusController =
      ViewportFocusController<int>();
  final ScrollController _scrollController = ScrollController();

  static const int _itemCount = 60;
  static const double _itemExtent = 220.0;

  bool _debug = false;
  bool _includeRects = false;
  bool _showNestedScroller = true;

  _RegionKind _regionKind = _RegionKind.zone;
  double _anchorFraction = 0.5;
  double _anchorOffsetPx = 0.0;
  double _zoneExtentPx = 180.0;
  double _lineThicknessPx = 0.0;

  _PolicyKind _policyKind = _PolicyKind.closestToAnchor;

  double _hysteresisPx = 24.0;
  int _minPrimaryDurationMs = 120;
  bool _preferCurrentPrimary = true;
  bool _allowPrimaryWhenNoItemFocused = true;

  _UpdatePolicyKind _updatePolicyKind = _UpdatePolicyKind.perFrame;
  int _scrollEndDebounceMs = 80;
  int _ballisticIntervalMs = 50;
  bool _computePerFrameWhileDragging = true;

  @override
  void dispose() {
    _scrollController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  ViewportAnchor _buildAnchor() {
    return ViewportAnchor.fraction(_anchorFraction, offsetPx: _anchorOffsetPx);
  }

  ViewportFocusRegion _buildRegion() {
    final anchor = _buildAnchor();
    return switch (_regionKind) {
      _RegionKind.zone => ViewportFocusRegion.zone(
        anchor: anchor,
        extentPx: _zoneExtentPx,
      ),
      _RegionKind.line => ViewportFocusRegion.line(
        anchor: anchor,
        thicknessPx: _lineThicknessPx,
      ),
    };
  }

  ViewportFocusPolicy<int> _buildPolicy() {
    return switch (_policyKind) {
      _PolicyKind.closestToAnchor =>
        const ViewportFocusPolicy<int>.closestToAnchor(),
      _PolicyKind.largestVisibleFraction =>
        const ViewportFocusPolicy<int>.largestVisibleFraction(),
      _PolicyKind.largestFocusOverlap =>
        const ViewportFocusPolicy<int>.largestFocusOverlap(),
      _PolicyKind.largestFocusProgress =>
        const ViewportFocusPolicy<int>.largestFocusProgress(),
    };
  }

  ViewportFocusStability _buildStability() {
    return ViewportFocusStability(
      hysteresisPx: _hysteresisPx,
      minPrimaryDuration: Duration(milliseconds: _minPrimaryDurationMs),
      preferCurrentPrimary: _preferCurrentPrimary,
      allowPrimaryWhenNoItemFocused: _allowPrimaryWhenNoItemFocused,
    );
  }

  ViewportUpdatePolicy _buildUpdatePolicy() {
    return switch (_updatePolicyKind) {
      _UpdatePolicyKind.perFrame => const ViewportUpdatePolicy.perFrame(),
      _UpdatePolicyKind.onScrollEnd => ViewportUpdatePolicy.onScrollEnd(
        debounce: Duration(milliseconds: _scrollEndDebounceMs),
      ),
      _UpdatePolicyKind.hybrid => ViewportUpdatePolicy.hybrid(
        scrollEndDebounce: Duration(milliseconds: _scrollEndDebounceMs),
        ballisticInterval: Duration(milliseconds: _ballisticIntervalMs),
        computePerFrameWhileDragging: _computePerFrameWhileDragging,
      ),
    };
  }

  ViewportFocusDebugConfig _buildDebugConfig() {
    return ViewportFocusDebugConfig(
      enabled: _debug,
      includeItemRectsInFrame: _includeRects,
      showLabels: false,
      showFocusRegion: true,
      showPrimaryOutline: true,
      showFocusedOutlines: true,
      showVisibleBounds: true,
      showItemBounds: false,
      showViewportBounds: false,
    );
  }

  int _currentPrimaryOr(int fallback) {
    final primary = _focusController.primaryId.value;
    if (primary == null) return fallback;
    return primary;
  }

  Future<void> _animateToIndex(int index) async {
    final clampedIndex = index.clamp(0, _itemCount - 1);
    final targetOffset = clampedIndex * _itemExtent;
    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final region = _buildRegion();
    final policy = _buildPolicy();
    final stability = _buildStability();
    final updatePolicy = _buildUpdatePolicy();

    return Scaffold(
      appBar: AppBar(
        title: const Text('viewport_focus'),
        actions: [
          IconButton(
            tooltip: 'Scroll to top',
            icon: const Icon(Icons.vertical_align_top),
            onPressed: () => _animateToIndex(0),
          ),
          IconButton(
            tooltip: 'Scroll to next primary',
            icon: const Icon(Icons.skip_next),
            onPressed: () => _animateToIndex(_currentPrimaryOr(0) + 1),
          ),
          IconButton(
            tooltip: 'Random jump',
            icon: const Icon(Icons.shuffle),
            onPressed: () {
              final next = math.Random().nextInt(_itemCount);
              _animateToIndex(next);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _HeaderPanel(
            controller: _focusController,
            onJumpPrimary: () => _animateToIndex(_currentPrimaryOr(0)),
          ),
          _SettingsPanel(
            regionKind: _regionKind,
            onRegionKindChanged: (v) => setState(() => _regionKind = v),
            anchorFraction: _anchorFraction,
            onAnchorFractionChanged: (v) => setState(() => _anchorFraction = v),
            anchorOffsetPx: _anchorOffsetPx,
            onAnchorOffsetPxChanged: (v) => setState(() => _anchorOffsetPx = v),
            zoneExtentPx: _zoneExtentPx,
            onZoneExtentPxChanged: (v) => setState(() => _zoneExtentPx = v),
            lineThicknessPx: _lineThicknessPx,
            onLineThicknessPxChanged: (v) =>
                setState(() => _lineThicknessPx = v),
            policyKind: _policyKind,
            onPolicyKindChanged: (v) => setState(() => _policyKind = v),
            hysteresisPx: _hysteresisPx,
            onHysteresisPxChanged: (v) => setState(() => _hysteresisPx = v),
            minPrimaryDurationMs: _minPrimaryDurationMs,
            onMinPrimaryDurationMsChanged: (v) =>
                setState(() => _minPrimaryDurationMs = v),
            preferCurrentPrimary: _preferCurrentPrimary,
            onPreferCurrentPrimaryChanged: (v) =>
                setState(() => _preferCurrentPrimary = v),
            allowPrimaryWhenNoItemFocused: _allowPrimaryWhenNoItemFocused,
            onAllowPrimaryWhenNoItemFocusedChanged: (v) =>
                setState(() => _allowPrimaryWhenNoItemFocused = v),
            updatePolicyKind: _updatePolicyKind,
            onUpdatePolicyKindChanged: (v) =>
                setState(() => _updatePolicyKind = v),
            scrollEndDebounceMs: _scrollEndDebounceMs,
            onScrollEndDebounceMsChanged: (v) =>
                setState(() => _scrollEndDebounceMs = v),
            ballisticIntervalMs: _ballisticIntervalMs,
            onBallisticIntervalMsChanged: (v) =>
                setState(() => _ballisticIntervalMs = v),
            computePerFrameWhileDragging: _computePerFrameWhileDragging,
            onComputePerFrameWhileDraggingChanged: (v) =>
                setState(() => _computePerFrameWhileDragging = v),
            debug: _debug,
            onDebugChanged: (v) => setState(() => _debug = v),
            includeRects: _includeRects,
            onIncludeRectsChanged: (v) => setState(() => _includeRects = v),
            showNestedScroller: _showNestedScroller,
            onShowNestedScrollerChanged: (v) =>
                setState(() => _showNestedScroller = v),
          ),
          Expanded(
            child: ViewportFocusScope<int>(
              controller: _focusController,
              region: region,
              policy: policy,
              stability: stability,
              updatePolicy: updatePolicy,
              scrollController: _scrollController,
              notificationDepth: 0,
              debug: _debug,
              debugConfig: _buildDebugConfig(),
              child: ListView.builder(
                controller: _scrollController,
                itemExtent: _itemExtent,
                itemCount: _itemCount,
                itemBuilder: (context, index) {
                  return ViewportFocusItem<int>(
                    id: index,
                    child: _FeedCardStatic(
                      index: index,
                      showNestedScroller: _showNestedScroller,
                    ),
                    builder: (context, focus, child) {
                      return _FeedCard(
                        index: index,
                        focus: focus,
                        child: child!,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel({required this.controller, required this.onJumpPrimary});

  final ViewportFocusController<int> controller;
  final VoidCallback onJumpPrimary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<int?>(
                valueListenable: controller.primaryId,
                builder: (context, primary, _) {
                  return Text(
                    'Primary: ${primary ?? "—"}',
                    style: textTheme.titleMedium,
                  );
                },
              ),
            ),
            ValueListenableBuilder<Set<int>>(
              valueListenable: controller.focusedIds,
              builder: (context, focused, _) {
                return Text(
                  'Focused: ${focused.length}',
                  style: textTheme.bodyMedium,
                );
              },
            ),
            const SizedBox(width: 10),
            FilledButton.tonal(
              onPressed: onJumpPrimary,
              child: const Text('Jump'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.regionKind,
    required this.onRegionKindChanged,
    required this.anchorFraction,
    required this.onAnchorFractionChanged,
    required this.anchorOffsetPx,
    required this.onAnchorOffsetPxChanged,
    required this.zoneExtentPx,
    required this.onZoneExtentPxChanged,
    required this.lineThicknessPx,
    required this.onLineThicknessPxChanged,
    required this.policyKind,
    required this.onPolicyKindChanged,
    required this.hysteresisPx,
    required this.onHysteresisPxChanged,
    required this.minPrimaryDurationMs,
    required this.onMinPrimaryDurationMsChanged,
    required this.preferCurrentPrimary,
    required this.onPreferCurrentPrimaryChanged,
    required this.allowPrimaryWhenNoItemFocused,
    required this.onAllowPrimaryWhenNoItemFocusedChanged,
    required this.updatePolicyKind,
    required this.onUpdatePolicyKindChanged,
    required this.scrollEndDebounceMs,
    required this.onScrollEndDebounceMsChanged,
    required this.ballisticIntervalMs,
    required this.onBallisticIntervalMsChanged,
    required this.computePerFrameWhileDragging,
    required this.onComputePerFrameWhileDraggingChanged,
    required this.debug,
    required this.onDebugChanged,
    required this.includeRects,
    required this.onIncludeRectsChanged,
    required this.showNestedScroller,
    required this.onShowNestedScrollerChanged,
  });

  final _RegionKind regionKind;
  final ValueChanged<_RegionKind> onRegionKindChanged;

  final double anchorFraction;
  final ValueChanged<double> onAnchorFractionChanged;
  final double anchorOffsetPx;
  final ValueChanged<double> onAnchorOffsetPxChanged;

  final double zoneExtentPx;
  final ValueChanged<double> onZoneExtentPxChanged;
  final double lineThicknessPx;
  final ValueChanged<double> onLineThicknessPxChanged;

  final _PolicyKind policyKind;
  final ValueChanged<_PolicyKind> onPolicyKindChanged;

  final double hysteresisPx;
  final ValueChanged<double> onHysteresisPxChanged;
  final int minPrimaryDurationMs;
  final ValueChanged<int> onMinPrimaryDurationMsChanged;
  final bool preferCurrentPrimary;
  final ValueChanged<bool> onPreferCurrentPrimaryChanged;
  final bool allowPrimaryWhenNoItemFocused;
  final ValueChanged<bool> onAllowPrimaryWhenNoItemFocusedChanged;

  final _UpdatePolicyKind updatePolicyKind;
  final ValueChanged<_UpdatePolicyKind> onUpdatePolicyKindChanged;
  final int scrollEndDebounceMs;
  final ValueChanged<int> onScrollEndDebounceMsChanged;
  final int ballisticIntervalMs;
  final ValueChanged<int> onBallisticIntervalMsChanged;
  final bool computePerFrameWhileDragging;
  final ValueChanged<bool> onComputePerFrameWhileDraggingChanged;

  final bool debug;
  final ValueChanged<bool> onDebugChanged;
  final bool includeRects;
  final ValueChanged<bool> onIncludeRectsChanged;

  final bool showNestedScroller;
  final ValueChanged<bool> onShowNestedScrollerChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: false,
      title: const Text('Settings'),
      subtitle: const Text('Region / policy / stability / update policy'),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _EnumDropdown<_RegionKind>(
                      label: 'Region',
                      value: regionKind,
                      values: _RegionKind.values,
                      onChanged: onRegionKindChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EnumDropdown<_PolicyKind>(
                      label: 'Policy',
                      value: policyKind,
                      values: _PolicyKind.values,
                      onChanged: onPolicyKindChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _EnumDropdown<_UpdatePolicyKind>(
                      label: 'Update policy',
                      value: updatePolicyKind,
                      values: _UpdatePolicyKind.values,
                      onChanged: onUpdatePolicyKindChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Debug overlay'),
                      value: debug,
                      onChanged: onDebugChanged,
                    ),
                  ),
                ],
              ),
              if (debug)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include rects'),
                  subtitle: const Text('More allocations (debug only).'),
                  value: includeRects,
                  onChanged: onIncludeRectsChanged,
                ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nested horizontal scrollers'),
                subtitle: const Text(
                  'Should not affect focus (depth filtering).',
                ),
                value: showNestedScroller,
                onChanged: onShowNestedScrollerChanged,
              ),
              const Divider(height: 20),
              _LabeledSlider(
                label: 'Anchor fraction',
                value: anchorFraction,
                min: 0,
                max: 1,
                divisions: 20,
                trailing: anchorFraction.toStringAsFixed(2),
                onChanged: onAnchorFractionChanged,
              ),
              _LabeledSlider(
                label: 'Anchor offset',
                value: anchorOffsetPx,
                min: -120,
                max: 120,
                divisions: 24,
                trailing: '${anchorOffsetPx.toStringAsFixed(0)}px',
                onChanged: onAnchorOffsetPxChanged,
              ),
              if (regionKind == _RegionKind.zone)
                _LabeledSlider(
                  label: 'Zone extent',
                  value: zoneExtentPx,
                  min: 60,
                  max: 320,
                  divisions: 26,
                  trailing: '${zoneExtentPx.toStringAsFixed(0)}px',
                  onChanged: onZoneExtentPxChanged,
                ),
              if (regionKind == _RegionKind.line)
                _LabeledSlider(
                  label: 'Line thickness',
                  value: lineThicknessPx,
                  min: 0,
                  max: 40,
                  divisions: 20,
                  trailing: '${lineThicknessPx.toStringAsFixed(1)}px',
                  onChanged: onLineThicknessPxChanged,
                ),
              const Divider(height: 20),
              _LabeledSlider(
                label: 'Hysteresis',
                value: hysteresisPx,
                min: 0,
                max: 80,
                divisions: 40,
                trailing: '${hysteresisPx.toStringAsFixed(0)}px',
                onChanged: onHysteresisPxChanged,
              ),
              _LabeledIntSlider(
                label: 'Min primary duration',
                value: minPrimaryDurationMs,
                min: 0,
                max: 300,
                divisions: 30,
                trailing: '${minPrimaryDurationMs}ms',
                onChanged: onMinPrimaryDurationMsChanged,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Prefer current primary'),
                value: preferCurrentPrimary,
                onChanged: onPreferCurrentPrimaryChanged,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow primary when no item focused'),
                value: allowPrimaryWhenNoItemFocused,
                onChanged: onAllowPrimaryWhenNoItemFocusedChanged,
              ),
              const Divider(height: 20),
              if (updatePolicyKind != _UpdatePolicyKind.perFrame) ...[
                _LabeledIntSlider(
                  label: 'Scroll end debounce',
                  value: scrollEndDebounceMs,
                  min: 0,
                  max: 800,
                  divisions: 40,
                  trailing: '${scrollEndDebounceMs}ms',
                  onChanged: onScrollEndDebounceMsChanged,
                ),
              ],
              if (updatePolicyKind == _UpdatePolicyKind.hybrid) ...[
                _LabeledIntSlider(
                  label: 'Ballistic interval',
                  value: ballisticIntervalMs,
                  min: 16,
                  max: 200,
                  divisions: 23,
                  trailing: '${ballisticIntervalMs}ms',
                  onChanged: onBallisticIntervalMsChanged,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Compute per frame while dragging'),
                  value: computePerFrameWhileDragging,
                  onChanged: onComputePerFrameWhileDraggingChanged,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EnumDropdown<T extends Enum> extends StatelessWidget {
  const _EnumDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isDense: true,
          value: value,
          items: values
              .map((e) => DropdownMenuItem<T>(value: e, child: Text(e.name)))
              .toList(growable: false),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.trailing,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String trailing;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                label: trailing,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        SizedBox(width: 70, child: Text(trailing, textAlign: TextAlign.right)),
      ],
    );
  }
}

class _LabeledIntSlider extends StatelessWidget {
  const _LabeledIntSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.trailing,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int divisions;
  final String trailing;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _LabeledSlider(
      label: label,
      value: value.toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      divisions: divisions,
      trailing: trailing,
      onChanged: (v) => onChanged(v.round()),
    );
  }
}

class _FeedCardStatic extends StatelessWidget {
  const _FeedCardStatic({
    required this.index,
    required this.showNestedScroller,
  });

  final int index;
  final bool showNestedScroller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Item $index', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Scroll me: primary should be stable and only one winner.',
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              if (showNestedScroller && index % 6 == 0) ...[
                Text(
                  'Nested horizontal scroller (depth > 0)',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 56,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 20,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: SizedBox(
                            width: 56,
                            child: Center(child: Text('$i')),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.index,
    required this.focus,
    required this.child,
  });

  final int index;
  final ViewportItemFocus<int> focus;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color alpha(Color color, double opacity) {
      final a = (opacity.clamp(0.0, 1.0) * 255).round();
      return color.withAlpha(a);
    }

    final Color border = focus.isPrimary
        ? Colors.green
        : (focus.isFocused ? Colors.orange : scheme.outlineVariant);

    final Color overlay = focus.isPrimary
        ? alpha(Colors.green, 0.10)
        : (focus.isFocused ? alpha(Colors.orange, 0.08) : Colors.transparent);

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: overlay,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border, width: 2),
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, right: 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: alpha(scheme.surfaceContainerHighest, 0.90),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        focus.isPrimary
                            ? 'PRIMARY'
                            : (focus.isFocused ? 'focused' : 'idle'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
