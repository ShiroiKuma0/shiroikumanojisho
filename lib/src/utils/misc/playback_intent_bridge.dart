import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge between Android broadcast intents and the in-app audio
/// toolbar's playback controls.
///
/// External apps (Tasker, automation widgets, button-mapper apps,
/// or any tool that can fire a broadcast intent) can control the
/// reader audio toolbar by sending one of the following intent
/// actions to this app's package:
///
///   * `shiroikuma.jisho.action.PLAYBACK_NEXT_SUBTITLE`
///       Seek to the start of the next subtitle.
///   * `shiroikuma.jisho.action.PLAYBACK_PREVIOUS_SUBTITLE`
///       Seek to the start of the previous subtitle.
///   * `shiroikuma.jisho.action.PLAYBACK_REPLAY_SUBTITLE`
///       Seek to the start of the current (or nearest preceding)
///       subtitle and resume playback.
///   * `shiroikuma.jisho.action.PLAYBACK_TOGGLE_PLAY_PAUSE`
///       Toggle play/pause.
///   * `shiroikuma.jisho.action.PLAYBACK_PREVIOUS_CHAPTER`
///       Jump to the previous chapter audio file in the same
///       folder, if any.
///   * `shiroikuma.jisho.action.PLAYBACK_NEXT_CHAPTER`
///       Jump to the next chapter audio file in the same folder,
///       if any.
///   * `shiroikuma.jisho.action.PLAYBACK_CYCLE_MODE`
///       Cycle the playback mode: normal → condensed → auto-pause
///       → normal. Used to switch in and out of shadowing mode
///       (auto-pause) without opening the toolbar menu.
///
/// In Tasker, use a "Send Intent" action with the appropriate
/// action string, target package `shiroikuma.jisho`, and target
/// "Broadcast Receiver". No payload (extras) is required.
///
/// The intents only take effect while the app process is alive and
/// a reader-audio toolbar is currently mounted (i.e., the user is
/// on a TTU reader page with audio loaded). If no toolbar has
/// registered callbacks when the intent arrives, the intent is a
/// no-op — it does not bring the app to the foreground or start
/// audio playback from a cold state.
///
/// The native side (`MainActivity.java`) registers a
/// `BroadcastReceiver` for these actions and translates each into
/// a method call on the `shiroikuma.jisho/playback_intent`
/// `MethodChannel`. This Dart-side bridge installs a handler on
/// the same channel and dispatches to whichever callbacks are
/// currently registered.
class PlaybackIntentBridge {
  static const MethodChannel _channel =
      MethodChannel('shiroikuma.jisho/playback_intent');

  static VoidCallback? _onNextSubtitle;
  static VoidCallback? _onPreviousSubtitle;
  static VoidCallback? _onReplaySubtitle;
  static VoidCallback? _onTogglePlayPause;
  static VoidCallback? _onPreviousChapter;
  static VoidCallback? _onNextChapter;
  static VoidCallback? _onCycleMode;

  static bool _initialised = false;

  /// Install the method-call handler. Idempotent; call once during
  /// app startup before any UI is built. Subsequent calls are a
  /// no-op so it is safe to invoke from a `main()` that might run
  /// twice in hot-restart scenarios.
  static void initialise() {
    if (_initialised) return;
    _initialised = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'nextSubtitle':
          _onNextSubtitle?.call();
          return null;
        case 'previousSubtitle':
          _onPreviousSubtitle?.call();
          return null;
        case 'replaySubtitle':
          _onReplaySubtitle?.call();
          return null;
        case 'togglePlayPause':
          _onTogglePlayPause?.call();
          return null;
        case 'previousChapter':
          _onPreviousChapter?.call();
          return null;
        case 'nextChapter':
          _onNextChapter?.call();
          return null;
        case 'cycleMode':
          _onCycleMode?.call();
          return null;
      }
      return null;
    });
  }

  /// Register callbacks. Whatever component is currently the
  /// canonical playback target (the visible audio toolbar) should
  /// call this in `initState` and call [unregister] in `dispose`.
  ///
  /// Subsequent registrations replace previous ones — there is
  /// only one active playback target at a time. If two toolbars
  /// were ever mounted simultaneously (not the current design but
  /// not impossible in future), the more recently mounted one
  /// wins until it disposes.
  static void register({
    VoidCallback? onNextSubtitle,
    VoidCallback? onPreviousSubtitle,
    VoidCallback? onReplaySubtitle,
    VoidCallback? onTogglePlayPause,
    VoidCallback? onPreviousChapter,
    VoidCallback? onNextChapter,
    VoidCallback? onCycleMode,
  }) {
    _onNextSubtitle = onNextSubtitle;
    _onPreviousSubtitle = onPreviousSubtitle;
    _onReplaySubtitle = onReplaySubtitle;
    _onTogglePlayPause = onTogglePlayPause;
    _onPreviousChapter = onPreviousChapter;
    _onNextChapter = onNextChapter;
    _onCycleMode = onCycleMode;
  }

  /// Clear all registered callbacks. Safe to call multiple times.
  static void unregister() {
    _onNextSubtitle = null;
    _onPreviousSubtitle = null;
    _onReplaySubtitle = null;
    _onTogglePlayPause = null;
    _onPreviousChapter = null;
    _onNextChapter = null;
    _onCycleMode = null;
  }
}
