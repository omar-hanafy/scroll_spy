import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// The small player state the feed UI needs.
///
/// Position changes are deliberately excluded so the feed does not rebuild at
/// the video player's polling frequency.
@immutable
class FeedVideoState {
  const FeedVideoState({
    this.isInitialized = false,
    this.isPlaying = false,
    this.isBuffering = false,
    this.aspectRatio = 1,
    this.errorDescription,
  });

  final bool isInitialized;
  final bool isPlaying;
  final bool isBuffering;
  final double aspectRatio;
  final String? errorDescription;

  @override
  bool operator ==(Object other) {
    return other is FeedVideoState &&
        other.isInitialized == isInitialized &&
        other.isPlaying == isPlaying &&
        other.isBuffering == isBuffering &&
        other.aspectRatio == aspectRatio &&
        other.errorDescription == errorDescription;
  }

  @override
  int get hashCode => Object.hash(
    isInitialized,
    isPlaying,
    isBuffering,
    aspectRatio,
    errorDescription,
  );
}

/// Testable seam around the platform video player.
abstract interface class FeedVideoHandle {
  ValueListenable<FeedVideoState> get state;

  Widget buildView();

  Future<void> initialize();

  Future<void> play();

  Future<void> pause();

  Future<void> dispose();
}

typedef FeedVideoHandleFactory = FeedVideoHandle Function(int index);

/// Keeps video resources bounded around the current primary item.
///
/// With the default retain radius the pool owns at most three controllers:
/// the primary, its previous neighbor, and its next neighbor. Reconciliation
/// is serialized so a fast scroll cannot race two controllers into playback.
class FeedVideoPool {
  FeedVideoPool({
    required FeedVideoHandleFactory factory,
    required this.itemCount,
    this.retainRadius = 1,
  }) : _factory = factory,
       assert(itemCount > 0),
       assert(retainRadius >= 0);

  final FeedVideoHandleFactory _factory;
  final int itemCount;
  final int retainRadius;

  final Map<int, FeedVideoHandle> _handles = <int, FeedVideoHandle>{};
  final Map<int, VoidCallback> _handleListeners = <int, VoidCallback>{};

  /// Notifies cards and the pool HUD when resources or playback state change.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<void> _tail = Future<void>.value();
  int? _primaryIndex;
  bool _active = true;
  bool _closed = false;

  int? get primaryIndex => _primaryIndex;

  int get controllerCount => _handles.length;

  int get maxControllerCount => 1 + retainRadius * 2;

  Set<int> get retainedIndices => Set<int>.unmodifiable(_handles.keys);

  Set<int> get playingIndices => Set<int>.unmodifiable(
    _handles.entries
        .where((entry) => entry.value.state.value.isPlaying)
        .map((entry) => entry.key),
  );

  FeedVideoHandle? handleFor(int index) => _handles[index];

  Future<void> setPrimary(int? index) {
    assert(index == null || (index >= 0 && index < itemCount));
    if (_closed) return Future<void>.value();
    _primaryIndex = index;
    return _enqueueReconcile();
  }

  Future<void> setActive(bool active) {
    if (_closed) return Future<void>.value();
    _active = active;
    if (!active) {
      // Lifecycle pauses should not sit behind a neighbor preload. The queued
      // reconcile still serializes ownership, while this best-effort pause
      // stops an already-playing primary immediately.
      final Future<void> immediatePause = _pauseAll();
      final Future<void> reconcile = _enqueueReconcile();
      return Future.wait<void>(<Future<void>>[
        immediatePause,
        reconcile,
      ]).then<void>((_) {});
    }
    return _enqueueReconcile();
  }

  Future<void> _enqueueReconcile() {
    final Completer<void> result = Completer<void>();
    _tail = _tail
        .catchError((Object _) {
          // A failed platform command must not poison future reconciliation.
        })
        .then((_) => _reconcile())
        .then(result.complete, onError: result.completeError);
    return result.future;
  }

  Future<void> _reconcile() async {
    if (_closed) return;

    final int? target = _primaryIndex;
    if (!_active || target == null) {
      await _pauseAll();
      if (target == null) {
        await _disposeWhere((_) => true);
      }
      return;
    }

    final Set<int> desired = <int>{
      for (
        int index = target - retainRadius;
        index <= target + retainRadius;
        index++
      )
        if (index >= 0 && index < itemCount) index,
    };

    // Pause the outgoing primary before any incoming controller can play.
    await _pauseWhere((index) => index != target);
    await _disposeWhere((index) => !desired.contains(index));

    // Initialize the primary first, then preload its retained neighbors.
    final List<int> initializationOrder = <int>[
      target,
      ...desired.where((index) => index != target),
    ];
    for (final int index in initializationOrder) {
      if (_closed) return;
      final FeedVideoHandle handle = _handles[index] ?? _create(index);
      try {
        await handle.initialize();
      } catch (_) {
        // Handles expose initialization errors as state for the demo UI. Keep
        // the failed slot bounded in the pool and continue preloading others.
      }
    }

    // Selection or lifecycle may have changed during asynchronous preload.
    if (_closed || !_active || _primaryIndex != target) return;

    await _pauseWhere((index) => index != target);
    final FeedVideoHandle? primary = _handles[target];
    if (primary?.state.value.isInitialized ?? false) {
      await primary!.play();
    }
  }

  FeedVideoHandle _create(int index) {
    final FeedVideoHandle handle = _factory(index);
    _handles[index] = handle;
    void listener() => _notify();
    _handleListeners[index] = listener;
    handle.state.addListener(listener);
    _notify();
    return handle;
  }

  Future<void> _pauseAll() => _pauseWhere((_) => true);

  Future<void> _pauseWhere(bool Function(int index) predicate) async {
    for (final MapEntry<int, FeedVideoHandle> entry in _handles.entries.toList(
      growable: false,
    )) {
      if (predicate(entry.key) && entry.value.state.value.isPlaying) {
        await entry.value.pause();
      }
    }
  }

  Future<void> _disposeWhere(bool Function(int index) predicate) async {
    final List<int> doomed = _handles.keys.where(predicate).toList();
    for (final int index in doomed) {
      final FeedVideoHandle handle = _handles.remove(index)!;
      final VoidCallback? listener = _handleListeners.remove(index);
      if (listener != null) handle.state.removeListener(listener);
      _notify();
      await handle.dispose();
    }
  }

  void _notify() {
    if (!_closed) revision.value++;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _active = false;
    _primaryIndex = null;
    await _tail.catchError((Object _) {});
    await _pauseAll();
    await _disposeWhere((_) => true);
    revision.dispose();
  }
}

FeedVideoHandle createBundledFeedVideo(int _) {
  return VideoPlayerFeedVideoHandle('assets/scroll_spy_feed.mp4');
}

/// [video_player] adapter used by the live example.
class VideoPlayerFeedVideoHandle implements FeedVideoHandle {
  VideoPlayerFeedVideoHandle(String assetPath)
    : _controller = VideoPlayerController.asset(
        assetPath,
        videoPlayerOptions: VideoPlayerOptions(
          // Disable video_player's independent pause/resume observer. The pool
          // is the single lifecycle owner, which also understands route cover.
          allowBackgroundPlayback: true,
          preventsDisplaySleepDuringVideoPlayback: false,
          webOptions: const VideoPlayerWebOptions(
            controls: VideoPlayerWebOptionsControls.disabled(),
            allowContextMenu: false,
            allowRemotePlayback: false,
          ),
        ),
      ) {
    _controller.addListener(_syncState);
  }

  final VideoPlayerController _controller;
  final ValueNotifier<FeedVideoState> _state = ValueNotifier<FeedVideoState>(
    const FeedVideoState(),
  );

  Future<void>? _initialization;
  bool _skipControllerDispose = false;
  bool _disposed = false;

  @override
  ValueListenable<FeedVideoState> get state => _state;

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  Future<void> initialize() {
    return _initialization ??= _initializeOnce();
  }

  Future<void> _initializeOnce() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      // Muted playback is deterministic across browser autoplay policies.
      await _controller.setVolume(0);
      _syncState();
    } on MissingPluginException catch (error) {
      // In widget tests and unsupported desktop targets the platform create
      // call never starts, and video_player's dispose would wait for it.
      _skipControllerDispose = true;
      _setError(error.message ?? 'video_player is unavailable on this target');
      rethrow;
    } on UnimplementedError catch (error) {
      _skipControllerDispose = true;
      _setError(error.message ?? 'video_player is unavailable on this target');
      rethrow;
    } catch (error) {
      _setError('$error');
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    if (_disposed || !_controller.value.isInitialized) return;
    await _controller.play();
    _syncState();
  }

  @override
  Future<void> pause() async {
    if (_disposed || !_controller.value.isInitialized) return;
    await _controller.pause();
    _syncState();
  }

  void _syncState() {
    if (_disposed) return;
    final VideoPlayerValue value = _controller.value;
    final FeedVideoState next = FeedVideoState(
      isInitialized: value.isInitialized,
      isPlaying: value.isPlaying,
      isBuffering: value.isBuffering,
      aspectRatio: value.aspectRatio,
      errorDescription: value.errorDescription,
    );
    if (_state.value != next) _state.value = next;
  }

  void _setError(String message) {
    if (!_disposed) {
      _state.value = FeedVideoState(errorDescription: message);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _controller.removeListener(_syncState);
    if (!_skipControllerDispose) await _controller.dispose();
  }
}
