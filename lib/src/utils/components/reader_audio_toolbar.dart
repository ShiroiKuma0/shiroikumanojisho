import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:subtitle/subtitle.dart';
import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/models.dart';
import 'package:shiroikumanojisho/src/utils/components/folder_audio_picker.dart';
import 'package:shiroikumanojisho/utils.dart';

/// A toolbar for playing audiobook MP3 files synced with SRT subtitles,
/// displayed at the bottom of the reader page.
class ReaderAudioToolbar extends StatefulWidget {
  const ReaderAudioToolbar({
    required this.bookKey,
    required this.appModel,
    this.secondaryBookKey,
    this.onToggleSecondary,
    this.onOpenSecondaryManager,
    this.onRemoveSecondary,
    this.onSettingsChanged,
    this.secondaryShown = false,
    this.hasSecondary = false,
    this.secondaryTitle,
    super.key,
  });

  final String bookKey;

  /// Stable storage key for the translation book's reader appearance
  /// settings. Null when no translation book is attached.
  final String? secondaryBookKey;

  final AppModel appModel;
  final VoidCallback? onToggleSecondary;
  final VoidCallback? onOpenSecondaryManager;
  final VoidCallback? onRemoveSecondary;
  final VoidCallback? onSettingsChanged;
  final bool secondaryShown;
  final bool hasSecondary;
  final String? secondaryTitle;

  @override
  State<ReaderAudioToolbar> createState() => ReaderAudioToolbarState();
}

class ReaderAudioToolbarState extends State<ReaderAudioToolbar> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  final ValueNotifier<Duration> _positionNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _playingNotifier = ValueNotifier(false);

  List<Subtitle> _subtitles = [];
  Subtitle? _currentSubtitle;
  Subtitle? _autoPauseMemory;

  /// When non-null, an in-flight seek is pending: the audio player
  /// has been told to seek to this position but the position stream
  /// hasn't yet caught up. While this is set, [_onPosition] ignores
  /// stale emissions (which would otherwise reflect the OLD position
  /// for one or two updates after the seek call returns) so the
  /// auto-pause / condensed-playback logic doesn't see a fake
  /// "subtitle changed" event right after a seek.
  ///
  /// Cleared when [_onPosition] receives a position within
  /// [_seekTolerance] of the target, or by [_seekWatchdog] firing,
  /// whichever comes first. The watchdog is a safety net: if the
  /// position stream never emits a near-target value (uncommon but
  /// possible after very short seeks), we don't want playback's
  /// auto-pause to be permanently disabled.
  Duration? _pendingSeekTarget;
  Timer? _seekWatchdog;
  static const Duration _seekTolerance = Duration(milliseconds: 250);
  static const Duration _seekWatchdogTimeout = Duration(seconds: 1);

  bool _sliderBeingDragged = false;
  bool _audioLoaded = false;
  bool _collapsed = true;

  String? _mp3Path;
  String? _srtPath;

  late Box _box;
  bool _boxReady = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration?>? _durationSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant ReaderAudioToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the TTU SPA navigates between books, the parent page
    // rebuilds the toolbar with a new [bookKey]. The old state
    // (mp3 path, srt path, audio player, subtitle list, saved
    // position) belongs to the previous book and must not leak
    // into the new book's session. Save the old book's position,
    // tear down the audio pipeline, reset display fields, then
    // re-run [_init] against the new key.
    if (oldWidget.bookKey != widget.bookKey) {
      // Save position under the OLD key — `widget.bookKey` has
      // already flipped to the new value by the time didUpdateWidget
      // runs, so the normal [_saveAudioPosition] helper would write
      // the leaving book's position into the entering book's slot.
      // Guard on [_boxReady] because the initial [_init] is async and
      // the first bookKey change could land before Hive opens.
      if (_boxReady &&
          _audioLoaded &&
          _positionNotifier.value > Duration.zero) {
        final oldKey = _safeKey(oldWidget.bookKey);
        _box.put('pos_$oldKey', _positionNotifier.value.inMilliseconds);
      }
      _audioPlayer.stop();
      _positionSub?.cancel();
      _playerStateSub?.cancel();
      _durationSub?.cancel();
      _positionNotifier.value = Duration.zero;
      _durationNotifier.value = Duration.zero;
      _playingNotifier.value = false;
      _subtitles = [];
      _currentSubtitle = null;
      _autoPauseMemory = null;
      _audioLoaded = false;
      _collapsed = true;
      _mp3Path = null;
      _srtPath = null;
      if (mounted) setState(() {});
      _init();
    }
  }

  Future<void> _init() async {
    _box = await Hive.openBox('readerAudio');
    _boxReady = true;
    String key = _safeKey(widget.bookKey);
    _mp3Path = _box.get('mp3_$key');
    _srtPath = _box.get('srt_$key');

    if (_mp3Path != null && File(_mp3Path!).existsSync()) {
      // If there's no persisted srt, or the one we remember no longer
      // exists on disk (user moved files), try the same-basename
      // companion in the mp3's directory. Persist the find so the
      // auto-lookup cost is paid only once per chapter.
      if (_srtPath == null || !File(_srtPath!).existsSync()) {
        final companion = _findCompanionSrt(_mp3Path!);
        if (companion != null) {
          _srtPath = companion;
          await _box.put('srt_$key', companion);
        } else {
          _srtPath = null;
        }
      }
      await _loadAudio();
      if (_srtPath != null && File(_srtPath!).existsSync()) {
        await _loadSubtitles();
      }
      _collapsed = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _saveAudioPosition();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _seekWatchdog?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Save current audio position for resuming later. Per book: one
  /// slot stores the position in whichever chapter is currently
  /// loaded, because chapter navigation resets position to zero and
  /// writes a fresh saved position, so there's only ever one
  /// meaningful value to remember per book.
  void _saveAudioPosition() {
    if (_boxReady &&
        _audioLoaded &&
        _positionNotifier.value > Duration.zero) {
      String key = _safeKey(widget.bookKey);
      _box.put('pos_$key', _positionNotifier.value.inMilliseconds);
    }
  }

  String _safeKey(String k) =>
      k.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

  /// Return the basename of a path without its extension, e.g.
  /// `/storage/.../04 Nice trip.mp3` → `04 Nice trip`.
  String _basenameWithoutExt(String p) {
    final name = p.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  bool _isDigit(int code) => code >= 0x30 && code <= 0x39;

  /// Natural-order comparison for filenames so
  /// `"2 Foo"` < `"10 Foo"` as humans expect, instead of the default
  /// lexicographic `"10 Foo"` < `"2 Foo"`. Runs of digits compare
  /// numerically; everything else compares case-insensitively.
  int _naturalCompare(String a, String b) {
    int i = 0, j = 0;
    while (i < a.length && j < b.length) {
      final aDigit = _isDigit(a.codeUnitAt(i));
      final bDigit = _isDigit(b.codeUnitAt(j));
      if (aDigit && bDigit) {
        final aStart = i, bStart = j;
        while (i < a.length && _isDigit(a.codeUnitAt(i))) {
          i++;
        }
        while (j < b.length && _isDigit(b.codeUnitAt(j))) {
          j++;
        }
        final aNum = int.parse(a.substring(aStart, i));
        final bNum = int.parse(b.substring(bStart, j));
        if (aNum != bNum) return aNum.compareTo(bNum);
      } else if (aDigit != bDigit) {
        // Digits sort before letters when types differ.
        return aDigit ? -1 : 1;
      } else {
        final cmp =
            a[i].toLowerCase().compareTo(b[j].toLowerCase());
        if (cmp != 0) return cmp;
        i++;
        j++;
      }
    }
    return a.length.compareTo(b.length);
  }

  /// If an `.srt` file exists in the same directory as [mp3Path] with
  /// the same basename (e.g. `04 Nice trip.mp3` → `04 Nice trip.srt`),
  /// return its full path. Otherwise `null`. Used to auto-attach the
  /// companion subtitle track the moment the user picks an audio file
  /// or flips to a new chapter, since for this user's audiobooks the
  /// mp3/srt pair is always co-located and same-named.
  ///
  /// Implemented as a directory scan with case-insensitive matching,
  /// rather than a single-path `File(base.srt).existsSync()` check, so
  /// `.SRT`/`.Srt`/`.srt` all match and any minor casing drift in the
  /// basename itself is tolerated.
  String? _findCompanionSrt(String mp3Path) {
    final base = _basenameWithoutExt(mp3Path);
    final dir = File(mp3Path).parent;
    if (!dir.existsSync()) return null;
    final baseLower = base.toLowerCase();
    try {
      final entries = dir.listSync(followLinks: false);
      for (final entity in entries) {
        if (entity is! File) continue;
        final name = entity.path.split(Platform.pathSeparator).last;
        if (!name.toLowerCase().endsWith('.srt')) continue;
        if (_basenameWithoutExt(name).toLowerCase() == baseLower) {
          return entity.path;
        }
      }
    } catch (_) {
      // Directory listing failed (permission, I/O). Treat as
      // "no companion found" — caller handles null.
    }
    return null;
  }

  /// Return the list of audio files in the same directory as the
  /// currently-loaded mp3, natural-sorted by filename. Used by
  /// [_prevChapter] and [_nextChapter] to walk chapter order.
  /// Extensions match [_pickMp3]'s picker filter.
  List<String> _listChapterAudios() {
    if (_mp3Path == null) return [];
    final dir = File(_mp3Path!).parent;
    if (!dir.existsSync()) return [];
    const exts = {'.mp3', '.m4a', '.m4b', '.ogg', '.wav', '.flac', '.aac'};
    final List<String> files = [];
    try {
      final entries = dir.listSync(followLinks: false);
      for (final entity in entries) {
        if (entity is! File) continue;
        final lower = entity.path.toLowerCase();
        if (exts.any(lower.endsWith)) files.add(entity.path);
      }
    } catch (_) {
      // Directory listing failed — chapter nav becomes a no-op for
      // this book until the cause clears.
      return [];
    }
    files.sort((a, b) => _naturalCompare(
          a.split(Platform.pathSeparator).last,
          b.split(Platform.pathSeparator).last,
        ));
    return files;
  }

  /// Switch the player to [newPath]: stop current audio, attach the
  /// companion srt if one exists, reload from position zero, persist.
  /// Used by the explicit-pick flow and by prev/next chapter
  /// navigation.
  ///
  /// Always starts the new file at zero and overwrites the book's
  /// saved position accordingly. This matches the user's mental model
  /// that picking or stepping to a file is a fresh start; the
  /// resume-where-you-were behavior is owned exclusively by [_init],
  /// which runs only when the book is first opened.
  Future<void> _setAudio(String newPath) async {
    final newSrt = _findCompanionSrt(newPath);

    await _audioPlayer.stop();
    _subtitles = [];
    _currentSubtitle = null;
    _autoPauseMemory = null;
    _audioLoaded = false;

    _mp3Path = newPath;
    _srtPath = newSrt;

    await _loadAudio(restorePosition: false);
    if (_srtPath != null) {
      await _loadSubtitles();
    }
    await _persist();
    // Overwrite the book's saved position so a force-kill before the
    // next dispose-time save doesn't reopen into the old offset
    // against what is now a different audio file.
    final key = _safeKey(widget.bookKey);
    await _box.put('pos_$key', 0);
    _collapsed = false;
    if (mounted) setState(() {});
  }

  /// Index of [_mp3Path] within [list], matched by the final path
  /// component. Direct full-path `indexOf` is brittle across
  /// normalization differences between what `FilePicker` returns and
  /// what `Directory.listSync` produces (trailing slashes, symlink
  /// resolution, URI-encoded segments), but basenames under a single
  /// directory have to be unique, so basename matching is both safe
  /// and robust.
  int _currentChapterIndex(List<String> list) {
    if (_mp3Path == null) return -1;
    final mine = _mp3Path!.split(Platform.pathSeparator).last;
    return list.indexWhere(
      (p) => p.split(Platform.pathSeparator).last == mine,
    );
  }

  Future<void> _prevChapter() async {
    if (_mp3Path == null) return;
    final list = _listChapterAudios();
    if (list.length < 2) return;
    final idx = _currentChapterIndex(list);
    if (idx <= 0) return; // already first, or current not found in listing
    await _setAudio(list[idx - 1]);
  }

  Future<void> _nextChapter() async {
    if (_mp3Path == null) return;
    final list = _listChapterAudios();
    if (list.length < 2) return;
    final idx = _currentChapterIndex(list);
    if (idx < 0 || idx >= list.length - 1) return;
    await _setAudio(list[idx + 1]);
  }

  Future<void> _persist() async {
    String key = _safeKey(widget.bookKey);
    if (_mp3Path != null) await _box.put('mp3_$key', _mp3Path!);
    if (_srtPath != null) await _box.put('srt_$key', _srtPath!);
  }

  Future<void> _loadAudio({bool restorePosition = true}) async {
    if (_mp3Path == null) return;
    try {
      await _audioPlayer.setFilePath(_mp3Path!);
      double speed = (_box.get('playback_speed') as num?)?.toDouble() ?? 1.0;
      await _audioPlayer.setSpeed(speed);

      _durationSub?.cancel();
      _durationSub = _audioPlayer.durationStream.listen((d) {
        _durationNotifier.value = d ?? Duration.zero;
      });

      _positionSub?.cancel();
      _positionSub = _audioPlayer.positionStream.listen(_onPosition);

      _playerStateSub?.cancel();
      _playerStateSub = _audioPlayer.playerStateStream.listen((s) {
        _playingNotifier.value = s.playing;
      });

      if (restorePosition) {
        String key = _safeKey(widget.bookKey);
        int? savedPosMs = _box.get('pos_$key');
        if (savedPosMs != null && savedPosMs > 0) {
          await _audioPlayer.seek(Duration(milliseconds: savedPosMs));
        }
      }

      _audioLoaded = true;
    } catch (e) {
      debugPrint('Error loading audio: $e');
      _audioLoaded = false;
    }
  }

  Future<void> _loadSubtitles() async {
    if (_srtPath == null) return;
    try {
      String content = await File(_srtPath!).readAsString();
      SubtitleController ctrl = SubtitleController(
        provider: SubtitleProvider.fromString(
          data: content,
          type: SubtitleType.srt,
        ),
      );
      await ctrl.initial();
      _subtitles = ctrl.subtitles;
    } catch (e) {
      debugPrint('Error loading subtitles: $e');
      _subtitles = [];
    }
  }

  void _onPosition(Duration pos) {
    if (!mounted) return;

    // Always reflect the audio player's reported position in the
    // notifier — the display must equal reality. We can't gate this
    // on closeness to a seek target, because just_audio sometimes
    // lands a seek several seconds away from the requested target
    // (codec frame boundaries, container quirks) and gating would
    // leave the display frozen at a fictional position forever.
    _positionNotifier.value = pos;

    if (_subtitles.isEmpty) return;

    // After a seek, the position stream may emit ONE stale
    // pre-seek position before settling on the actual post-seek
    // position. If we processed that stale emission with the
    // subtitle-change logic, it would set _currentSubtitle to the
    // OLD subtitle, then the next emission (real new position)
    // would look like a subtitle change and trigger auto-pause /
    // condensed-skip spuriously. We swallow exactly one such
    // emission's subtitle-change processing per seek by checking
    // whether the position is anywhere near the seek target.
    final target = _pendingSeekTarget;
    if (target != null) {
      final diff = pos - target;
      final absDiffMs = diff.isNegative ? -diff.inMilliseconds : diff.inMilliseconds;
      if (absDiffMs > _seekTolerance.inMilliseconds) {
        // Stale — suppress subtitle-change processing for this one
        // emission, but DO update the position notifier (above).
        // _currentSubtitle was preset to the seek target's subtitle
        // by [_beginSeek] so it stays consistent.
        return;
      }
      // Caught up: clear pending state and fall through.
      _pendingSeekTarget = null;
      _seekWatchdog?.cancel();
      _seekWatchdog = null;
    }

    // Find current subtitle at this position
    Subtitle? newSub;
    for (Subtitle s in _subtitles) {
      if (pos >= s.start && pos <= s.end) {
        newSub = s;
        break;
      }
    }

    // Only act when subtitle state changes
    if (newSub != _currentSubtitle) {
      // Auto-pause: pause when leaving a subtitle
      if (widget.appModel.playbackMode == PlaybackMode.autoPausePlayback &&
          !_sliderBeingDragged &&
          _currentSubtitle != null &&
          _autoPauseMemory != _currentSubtitle) {
        _audioPlayer.pause();
        _autoPauseMemory = _currentSubtitle;
      }

      // Condensed playback: skip gaps between subtitles
      if (widget.appModel.playbackMode == PlaybackMode.condensedPlayback &&
          _audioPlayer.playing &&
          !_sliderBeingDragged &&
          _currentSubtitle != null &&
          newSub == null) {
        int nextIdx = _subtitles.indexWhere((s) => s.start > pos);
        if (nextIdx != -1) {
          _audioPlayer.seek(_subtitles[nextIdx].start);
        }
      }

      _currentSubtitle = newSub;
    }
  }

  /// Begin an audio seek with the racy-position-stream guarding
  /// described on [_pendingSeekTarget]. Pre-sets [_currentSubtitle]
  /// to whatever subtitle the target lands in (or null if it lands
  /// in a gap), so a stale post-seek emission can't drive the
  /// auto-pause logic into a bad state. Updates [_positionNotifier]
  /// to the target so the UI reflects the new position immediately
  /// — the position stream may not emit anything for a while when
  /// paused, and we don't want the user staring at the old time.
  /// The notifier WILL be overwritten with the audio player's real
  /// position when the next position emission arrives.
  void _beginSeek(Duration target) {
    _pendingSeekTarget = target;
    _seekWatchdog?.cancel();
    _seekWatchdog = Timer(_seekWatchdogTimeout, () {
      // Watchdog fires when the position stream never emitted a
      // near-target value — gives up and resumes normal stream
      // processing. Better than leaving auto-pause suppressed
      // forever.
      _pendingSeekTarget = null;
      _seekWatchdog = null;
    });
    _positionNotifier.value = target;
    // Pre-set _currentSubtitle to whatever subtitle the target
    // lands in. This means the post-seek "real" emission won't
    // look like a subtitle change to [_onPosition], so auto-pause
    // won't mis-fire.
    Subtitle? targetSub;
    for (Subtitle s in _subtitles) {
      if (target >= s.start && target <= s.end) {
        targetSub = s;
        break;
      }
    }
    _currentSubtitle = targetSub;
    // Reset auto-pause memory so the user gets a chance to hear
    // the targeted subtitle's auto-pause if they keep playing.
    _autoPauseMemory = null;
  }

  Subtitle? _getNearestSubtitle() {
    if (_subtitles.isEmpty) return null;
    Subtitle? last;
    for (Subtitle s in _subtitles) {
      if (_positionNotifier.value < s.start) return last;
      last = s;
    }
    return last;
  }

  void _seekPrev() async {
    if (_subtitles.isEmpty) return;
    final pos = _positionNotifier.value;
    // Find the subtitle currently containing the position, if any.
    Subtitle? containing;
    int containingIdx = -1;
    for (int i = 0; i < _subtitles.length; i++) {
      final s = _subtitles[i];
      if (pos >= s.start && pos <= s.end) {
        containing = s;
        containingIdx = i;
        break;
      }
    }

    Duration? target;
    const Duration restartThreshold = Duration(milliseconds: 500);
    if (containing != null && pos - containing.start > restartThreshold) {
      // Mid-subtitle, well past its start — restart the current one.
      target = containing.start;
    } else {
      // At/near a subtitle's start, in a gap, or past end of all
      // subtitles — go to the start of the previous subtitle.
      // Reference index for "previous" is the containing subtitle
      // if any, otherwise the first subtitle whose start is past
      // the current position (so prev = the one before that).
      int referenceIdx;
      if (containingIdx != -1) {
        referenceIdx = containingIdx;
      } else {
        // Not inside any subtitle (in a gap or past end). Find the
        // first subtitle with start > pos; reference = that. If
        // none (we're past end of all subs), reference = length
        // (so prev = last subtitle).
        referenceIdx = _subtitles.indexWhere((s) => s.start > pos);
        if (referenceIdx == -1) referenceIdx = _subtitles.length;
      }
      final prevIdx = referenceIdx - 1;
      if (prevIdx >= 0) target = _subtitles[prevIdx].start;
    }

    if (target != null) {
      _beginSeek(target);
      await _audioPlayer.seek(target);
    }
  }

  void _seekNext() async {
    if (_subtitles.isEmpty) return;
    final pos = _positionNotifier.value;
    final idx = _subtitles.indexWhere((s) => s.start > pos);
    if (idx != -1) {
      final target = _subtitles[idx].start;
      _beginSeek(target);
      await _audioPlayer.seek(target);
    }
  }

  void _replay() async {
    Subtitle? sub = _getNearestSubtitle();
    if (sub != null) {
      _beginSeek(sub.start);
      await _audioPlayer.seek(sub.start);
      if (!_audioPlayer.playing) await _audioPlayer.play();
    }
  }

  Future<void> _playPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      _autoPauseMemory = null;
      await _audioPlayer.play();
    }
  }

  Future<void> _pickMp3() async {
    // Custom folder browser rather than `file_picker.pickFiles` —
    // on Huawei (and some other Android flavours) file_picker's
    // SAF-backed implementation caches the selected file into
    // app-private storage and returns the cache path, which makes
    // chapter-nav and companion-srt lookup useless because the
    // cache dir doesn't contain the user's other chapter files.
    // Walking the real filesystem gives us a real path that the
    // rest of the toolbar's logic can meaningfully use.
    final initDir =
        _mp3Path != null ? File(_mp3Path!).parent.path : null;
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FolderAudioPicker(
          appModel: widget.appModel,
          initialDir: initDir,
        ),
      ),
    );
    if (path != null) {
      // MP3-format seek imprecision warning. ExoPlayer (just_audio's
      // Android backend) seeks MP3 by estimating frame position from
      // average bitrate, which on most files lands the decoder
      // several seconds away from the requested timestamp — even
      // after re-encoding with a Xing seek-info header. The result:
      // Prev/Next/slider seek to a point inside subtitle N but the
      // audio actually plays from somewhere mid-subtitle-(N-1) or
      // -(N+1), and auto-pause fires at a wrong sentence boundary.
      // We can't fix this from inside Dart — the player API only
      // reports the requested position, never the decoder's true
      // position. Re-encoding to AAC-in-MP4 (.m4a) gives sample-
      // accurate seeks via the moov atom's sample table, so we tell
      // the user to convert. Shown once per distinct MP3 path so the
      // user isn't re-nagged every time they reopen a book.
      if (path.toLowerCase().endsWith('.mp3') && mounted) {
        final shouldShow = await _shouldShowMp3Warning(path);
        if (shouldShow && mounted) {
          await _showMp3SeekWarningDialog(path);
          await _markMp3WarningShown(path);
        }
      }
      // Explicit pick is always a fresh start; resume-where-you-were
      // is owned exclusively by _init when reopening the book.
      await _setAudio(path);
    }
  }

  /// Whether the MP3-seek warning should be shown for this path. We
  /// store dismissed paths in a Hive set so the user is warned once
  /// per file, not every time. Returns false if the box isn't ready
  /// yet (don't block the audio load on a warning we can't track).
  Future<bool> _shouldShowMp3Warning(String path) async {
    if (!_boxReady) return false;
    final List<dynamic>? dismissed =
        _box.get('mp3_warning_dismissed') as List<dynamic>?;
    if (dismissed == null) return true;
    return !dismissed.contains(path);
  }

  Future<void> _markMp3WarningShown(String path) async {
    if (!_boxReady) return;
    final List<dynamic>? existing =
        _box.get('mp3_warning_dismissed') as List<dynamic>?;
    final List<String> updated = [
      ...?existing?.cast<String>(),
      if (existing == null || !existing.contains(path)) path,
    ];
    await _box.put('mp3_warning_dismissed', updated);
  }

  /// Modal informing the user that MP3 seek is imprecise on Android
  /// and offering the ffmpeg one-liner to convert to .m4a / .m4b.
  /// Tap-to-dismiss; selectable text on the commands so they can
  /// copy them.
  Future<void> _showMp3SeekWarningDialog(String path) async {
    final filename = path.split('/').last;
    final stem = filename.replaceAll(
        RegExp(r"\.mp3$", caseSensitive: false), '');
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('MP3 seek precision warning'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You picked an MP3 file. The Android audio player '
                  'cannot seek MP3 files accurately — Prev/Next and '
                  'the slider will land several seconds away from '
                  'the requested position, and auto-pause will fire '
                  'at the wrong sentence boundaries. This is a '
                  'limitation of the MP3 format and the player; not '
                  'something the app can fix.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Recommended fix: convert to .m4a or .m4b (AAC in '
                  'an MP4 container). Both share the same container '
                  'and codec — the only difference is convention: '
                  '.m4b is the audiobook flavor that some players '
                  'auto-file separately and remember playback '
                  'position for. .m4a is the generic flavor. Both '
                  'have a sample-accurate index so seeks land '
                  'precisely. The app picks up either when you '
                  're-attach from the same folder.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Single file → .m4b (audiobook):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  'ffmpeg -i "$filename" \\\n'
                  '  -map 0 -c:a aac -b:a 128k \\\n'
                  '  -c:v copy -disposition:v attached_pic \\\n'
                  '  "$stem.m4b"',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '(Replace .m4b with .m4a if you prefer the generic '
                  'flavor.)',
                  style: TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Whole folder of MP3s → ./fixed/*.m4b:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const SelectableText(
                  'mkdir -p fixed\n'
                  'for f in *.mp3; do\n'
                  '  ffmpeg -i "\$f" \\\n'
                  '    -map 0 -c:a aac -b:a 128k \\\n'
                  '    -c:v copy -disposition:v attached_pic \\\n'
                  '    "fixed/\${f%.mp3}.m4b"\n'
                  'done',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You will not be warned again for this file.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK, continue with MP3'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickSrt() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt'],
    );
    if (result != null && result.files.single.path != null) {
      _srtPath = result.files.single.path!;
      await _loadSubtitles();
      await _persist();
      if (mounted) setState(() {});
    }
  }

  Future<void> _clearAudio() async {
    await _audioPlayer.stop();
    _mp3Path = null;
    _srtPath = null;
    _subtitles = [];
    _currentSubtitle = null;
    _autoPauseMemory = null;
    _audioLoaded = false;
    _collapsed = true;
    String key = _safeKey(widget.bookKey);
    await _box.delete('mp3_$key');
    await _box.delete('srt_$key');
    await _box.delete('pos_$key');
    if (mounted) setState(() {});
  }

  void _showMenu() {
    PlaybackMode mode = widget.appModel.playbackMode;
    Map<PlaybackMode, String> modeLabels = {
      PlaybackMode.normalPlayback: t.playback_normal,
      PlaybackMode.condensedPlayback: t.playback_condensed,
      PlaybackMode.autoPausePlayback: t.playback_auto_pause,
    };
    Map<PlaybackMode, IconData> modeIcons = {
      PlaybackMode.normalPlayback: Icons.play_arrow,
      PlaybackMode.condensedPlayback: Icons.skip_next,
      PlaybackMode.autoPausePlayback: Icons.pause,
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      builder: (ctx) => Theme(
        // Force the reader bottom-sheet menu into the same yellow-on-black
        // palette the rest of the reader uses; without this override the
        // system picks up the light Material defaults and renders white
        // text on a grey surface.
        data: Theme.of(ctx).copyWith(
          iconTheme: const IconThemeData(color: Color(0xFFFFFF00)),
          listTileTheme: const ListTileThemeData(
            iconColor: Color(0xFFFFFF00),
            textColor: Color(0xFFFFFF00),
          ),
          dividerTheme: const DividerThemeData(
            color: Color(0xFF333333),
            thickness: 1,
            space: 8,
          ),
          textTheme: Theme.of(ctx).textTheme.apply(
                bodyColor: const Color(0xFFFFFF00),
                displayColor: const Color(0xFFFFFF00),
              ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            ListTile(
              leading: const Icon(Icons.audiotrack),
              title: Text(_mp3Path != null
                  ? _mp3Path!.split('/').last
                  : 'Select audio file'),
              subtitle: _mp3Path != null ? const Text('Tap to change') : null,
              onTap: () { Navigator.pop(ctx); _pickMp3(); },
            ),
            ListTile(
              leading: const Icon(Icons.subtitles),
              title: Text(_srtPath != null
                  ? _srtPath!.split('/').last
                  : 'Select subtitle file (.srt)'),
              subtitle: _srtPath != null
                  ? Text('${_subtitles.length} lines')
                  : null,
              onTap: () { Navigator.pop(ctx); _pickSrt(); },
            ),
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Playback speed'),
              subtitle: Text('${_audioPlayer.speed.toStringAsFixed(1)}x'),
              onTap: () { Navigator.pop(ctx); _showSpeedDialog(); },
            ),
            ListTile(
              leading: Icon(modeIcons[mode]),
              title: Text(modeLabels[mode] ?? ''),
              subtitle: const Text('Tap to cycle'),
              onTap: () {
                int next = (mode.index + 1) % PlaybackMode.values.length;
                widget.appModel.setPlaybackMode(PlaybackMode.values[next]);
                Navigator.pop(ctx);
                setState(() {});
              },
            ),
            if (_mp3Path != null)
              ListTile(
                leading: const Icon(Icons.clear, color: Colors.red),
                title: const Text('Remove audio',
                    style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(ctx); _clearAudio(); },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.palette),
              title: Text(widget.hasSecondary
                  ? 'Primary book appearance'
                  : 'Reader appearance'),
              onTap: () {
                Navigator.pop(ctx);
                _showReaderSettings(widget.bookKey, isSecondary: false);
              },
            ),
            if (widget.hasSecondary && widget.secondaryBookKey != null)
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Translation book appearance'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReaderSettings(widget.secondaryBookKey!,
                      isSecondary: true);
                },
              ),
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: Text(widget.hasSecondary
                  ? (widget.secondaryTitle ?? 'Translation book')
                  : 'Set translation book'),
              subtitle: widget.hasSecondary
                  ? const Text('Tap to change')
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                widget.onOpenSecondaryManager?.call();
              },
            ),
            if (widget.hasSecondary)
              ListTile(
                leading: const Icon(Icons.clear, color: Colors.red),
                title: const Text('Remove translation book',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onRemoveSecondary?.call();
                },
              ),
            const Divider(),
            StatefulBuilder(
              builder: (sbCtx, sbSetState) {
                final src = ReaderTtuSource.instance;
                return SwitchListTile(
                  secondary: const Icon(Icons.exit_to_app),
                  title: Text(t.confirm_exit_reader),
                  value: src.confirmExit,
                  onChanged: (_) {
                    src.toggleConfirmExit();
                    sbSetState(() {});
                  },
                );
              },
            ),
          ],
        ),
        ),
        ),
      ),
    );
  }

  void _showSpeedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Playback speed'),
        children: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((spd) {
          return SimpleDialogOption(
            onPressed: () {
              _audioPlayer.setSpeed(spd);
              _box.put('playback_speed', spd);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: Text(
              '${spd.toStringAsFixed(2)}x',
              style: TextStyle(
                fontWeight:
                    spd == _audioPlayer.speed ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Open the reader appearance dialog for the given book. Pass the
  /// Open the reader appearance page for the given book. Pass the
  /// primary book's key when no translation book is shown, or either
  /// book's key in split mode.
  ///
  /// Uses `Navigator.push` with a full-screen route instead of
  /// `showDialog` because TextField focus and the system IME are
  /// unreliable when a dialog overlays an immersive-mode scaffold —
  /// taps don't always raise the keyboard, and long-press sometimes
  /// raises it without accepting typed input. A pushed page goes
  /// through the normal route-focus machinery and behaves predictably.
  void _showReaderSettings(String bookKey,
      {required bool isSecondary}) async {
    String key = _safeKey(bookKey);
    ReaderAppearanceSettings current = ReaderAppearanceSettings.load(
      _box,
      key,
      isSecondary: isSecondary,
      languageCode: widget.appModel.targetLanguage.languageCode,
    );
    // Release any focus held by the previous route (e.g. the WebView
    // reader) before opening the page. Without this, TextField focus
    // on the pushed page is intermittently broken because Flutter's
    // focus tree still thinks the WebView owns input.
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await Future.delayed(const Duration(milliseconds: 5), () {});
    ReaderAppearanceSettings? result =
        await Navigator.of(context).push<ReaderAppearanceSettings>(
      MaterialPageRoute(
        builder: (ctx) => ReaderSettingsDialog(settings: current),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 5), () {});
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (result != null) {
      await result.save(_box, key);
      widget.onSettingsChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_collapsed && !_audioLoaded) return _buildCollapsed();
    return _buildExpanded();
  }

  Widget _buildCollapsed() {
    // When no audio is set, mirror the expanded view's configurable
    // height and preserve the right-side controls (translate-book
    // toggle, navigate, three-dot menu) so users can still set the
    // translation book or open settings. The left region becomes a
    // tappable "Select audio file" prompt that opens the same menu
    // as the three-dot button. Sizes are read from AppModel so the
    // toolbar scales with [readerAudioToolbarHeight].
    final double barHeight =
        widget.appModel.readerAudioToolbarHeight.toDouble();
    final double textSize = widget.appModel.readerAudioToolbarTextSize;
    final double promptIconSize =
        (textSize * 1.4).clamp(12.0, 64.0);
    return Container(
      height: barHeight,
      color: Colors.black.withOpacity(0.9),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  onTap: _showMenu,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Icon(Icons.audiotrack,
                            size: promptIconSize,
                            color: const Color(0xFFFFFF00)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Select audio file',
                              style: TextStyle(
                                  fontSize: textSize,
                                  color: const Color(0xFFFFFF00)),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSecondaryToggle(),
              _btn(Icons.more_vert, t.show_options, _showMenu),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded() {
    return Container(
      height: widget.appModel.readerAudioToolbarHeight.toDouble(),
      color: Colors.black.withOpacity(0.9),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const SizedBox(width: 4),
              _btn(Icons.fast_rewind, t.seek_control, _seekPrev),
              _btn(Icons.replay, t.replay_subtitle, _replay),
              _buildPlayPause(),
              _btn(Icons.fast_forward, t.seek_control, _seekNext),
              _buildTime(),
              _btn(Icons.skip_previous, 'Previous chapter', _prevChapter),
              Expanded(child: _buildSlider()),
              _btn(Icons.skip_next, 'Next chapter', _nextChapter),
              _buildSecondaryToggle(),
              _btn(Icons.more_vert, t.show_options, _showMenu),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(IconData icon, String tooltip, VoidCallback onTap) {
    final double iconSize =
        widget.appModel.readerAudioToolbarIconSize.toDouble();
    return Material(
      color: Colors.transparent,
      child: JidoujishoIconButton(
          size: iconSize, icon: icon, tooltip: tooltip, onTap: onTap,
          enabledColor: const Color(0xFFFFFF00)),
    );
  }

  Widget _buildPlayPause() {
    return ValueListenableBuilder<bool>(
      valueListenable: _playingNotifier,
      builder: (_, playing, __) => _btn(
        playing ? Icons.pause : Icons.play_arrow,
        playing ? t.pause : t.play,
        _playPause,
      ),
    );
  }

  Widget _buildSecondaryToggle() {
    return Material(
      color: Colors.transparent,
      child: JidoujishoIconButton(
        size: widget.appModel.readerAudioToolbarIconSize.toDouble(),
        icon: widget.secondaryShown
            ? Icons.chrome_reader_mode
            : Icons.chrome_reader_mode_outlined,
        tooltip: 'Toggle translation book',
        enabledColor: const Color(0xFFFFFF00),
        onTap: () {
          if (widget.secondaryShown) {
            widget.onToggleSecondary?.call();
          } else if (widget.hasSecondary) {
            widget.onToggleSecondary?.call();
          } else {
            widget.onOpenSecondaryManager?.call();
          }
        },
      ),
    );
  }

  Widget _buildTime() {
    return MultiValueListenableBuilder(
      valueListenables: [_positionNotifier, _durationNotifier],
      builder: (_, values, __) {
        Duration pos = values.elementAt(0);
        Duration dur = values.elementAt(1);
        if (dur == Duration.zero) return const SizedBox.shrink();
        String p = JidoujishoTimeFormat.getVideoDurationText(pos).trim();
        String d = JidoujishoTimeFormat.getVideoDurationText(dur).trim();
        // The 0.21 factor matches the time text to roughly 10 px at
        // the default 48 px toolbar height (the previous hardcoded
        // value), and scales linearly with custom heights.
        final double timeFontSize =
            (widget.appModel.readerAudioToolbarHeight * 0.21)
                .clamp(8.0, 36.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('$p / $d',
              style: TextStyle(
                  fontSize: timeFontSize,
                  color: const Color(0xFFFFFF00))),
        );
      },
    );
  }

  Widget _buildSlider() {
    return MultiValueListenableBuilder(
      valueListenables: [_positionNotifier, _durationNotifier],
      builder: (_, values, __) {
        Duration pos = values.elementAt(0);
        Duration dur = values.elementAt(1);
        if (dur == Duration.zero) return const SizedBox.shrink();
        double val = pos.inMilliseconds.toDouble()
            .clamp(0, dur.inMilliseconds.toDouble());
        final String label = () {
          if (_mp3Path == null) return '';
          final mp3Name = _mp3Path!.split(Platform.pathSeparator).last;
          if (_srtPath != null) return '$mp3Name/srt';
          return mp3Name;
        }();
        return Stack(
          alignment: Alignment.center,
          children: [
            // Filename painted behind the slider at low opacity so the
            // user can always see which chapter is playing without
            // allocating extra vertical space for a label. IgnorePointer
            // keeps the slider fully hit-testable over the top — the
            // thumb sweeps across the label without stealing touches.
            // Label shows the full mp3 filename (with extension), and
            // appends "/srt" when a companion subtitle track is
            // attached, so at a glance the user sees both which
            // chapter is playing and whether subtitles are live.
            if (label.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color:
                              const Color(0xFFFFFF00).withOpacity(0.35),
                          // Scale label with toolbar height. Default
                          // 48 px → 16 px font, matching the prior
                          // hardcoded value.
                          fontSize:
                              (widget.appModel.readerAudioToolbarHeight *
                                      0.33)
                                  .clamp(10.0, 48.0),
                          height: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                // Scale thumb and overlay so they stay grabbable in
                // tall toolbars. Default 6 px thumb radius is fine
                // at 48 px toolbar; we want it bigger as the bar
                // grows. The 0.13 / 0.21 factors approximate the
                // existing 6/10 at default 48 px.
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius:
                      widget.appModel.readerAudioToolbarThumbRadius
                          .clamp(4.0, 24.0),
                ),
                overlayShape: RoundSliderOverlayShape(
                  overlayRadius:
                      (widget.appModel.readerAudioToolbarThumbRadius * 1.6)
                          .clamp(8.0, 48.0),
                ),
                activeTrackColor: const Color(0xFFFFFF00),
                inactiveTrackColor:
                    const Color(0xFFFFFF00).withOpacity(0.3),
                thumbColor: const Color(0xFFFFFF00),
                overlayColor: const Color(0xFFFFFF00).withOpacity(0.2),
              ),
              child: Slider(
                value: val,
                max: dur.inMilliseconds.toDouble(),
                onChangeStart: (_) => _sliderBeingDragged = true,
                onChanged: (v) => _positionNotifier.value =
                    Duration(milliseconds: v.toInt()),
                onChangeEnd: (v) {
                  final target = Duration(milliseconds: v.toInt());
                  _beginSeek(target);
                  _audioPlayer.seek(target);
                  _sliderBeingDragged = false;
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
