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
  bool _isSeeking = false;
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
    const exts = {'.mp3', '.m4a', '.ogg', '.wav', '.flac', '.aac'};
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
    if (!mounted || _isSeeking) return;
    _positionNotifier.value = pos;

    if (_subtitles.isEmpty) return;

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
    int idx = _subtitles.lastIndexWhere(
        (s) => _positionNotifier.value > s.start + const Duration(milliseconds: 500));
    if (idx != -1) {
      _isSeeking = true;
      _currentSubtitle = null;
      _autoPauseMemory = null;
      await _audioPlayer.seek(_subtitles[idx].start);
      _isSeeking = false;
    }
  }

  void _seekNext() async {
    if (_subtitles.isEmpty) return;
    int idx = _subtitles.indexWhere((s) => s.start > _positionNotifier.value);
    if (idx != -1) {
      _isSeeking = true;
      _currentSubtitle = null;
      _autoPauseMemory = null;
      await _audioPlayer.seek(_subtitles[idx].start);
      _isSeeking = false;
    }
  }

  void _replay() async {
    Subtitle? sub = _getNearestSubtitle();
    if (sub != null) {
      _isSeeking = true;
      _currentSubtitle = null;
      _autoPauseMemory = null;
      await _audioPlayer.seek(sub.start);
      _isSeeking = false;
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
        builder: (_) => FolderAudioPicker(initialDir: initDir),
      ),
    );
    if (path != null) {
      // Explicit pick is always a fresh start; resume-where-you-were
      // is owned exclusively by _init when reopening the book.
      await _setAudio(path);
    }
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
                _showReaderSettings(widget.bookKey);
              },
            ),
            if (widget.hasSecondary && widget.secondaryBookKey != null)
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Translation book appearance'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReaderSettings(widget.secondaryBookKey!);
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
  void _showReaderSettings(String bookKey) async {
    String key = _safeKey(bookKey);
    ReaderAppearanceSettings current =
        ReaderAppearanceSettings.load(_box, key);
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
    // When no audio is set, keep the same 48 px bar height as the
    // expanded view and preserve the right-side controls (translate-
    // book toggle, three-dot menu) so users can still set the
    // translation book or open settings. The left region becomes a
    // tappable "Select audio file" prompt that opens the same menu
    // as the three-dot button.
    return Container(
      height: 48,
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
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Icon(Icons.audiotrack,
                            size: 18, color: Color(0xFFFFFF00)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Select audio file',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFFFFF00)),
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
      height: 48,
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
    return Material(
      color: Colors.transparent,
      child: JidoujishoIconButton(
          size: 24, icon: icon, tooltip: tooltip, onTap: onTap,
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
        size: 24,
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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('$p / $d',
              style: const TextStyle(
                  fontSize: 10,
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
                          fontSize: 16,
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
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 10),
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
                  _audioPlayer.seek(Duration(milliseconds: v.toInt()));
                  _sliderBeingDragged = false;
                  _autoPauseMemory = null;
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
