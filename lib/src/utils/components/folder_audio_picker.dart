import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shiroikumanojisho/models.dart';

/// Full-screen directory-tree browser for picking an audio file.
/// Walks the device's external storage volumes — internal storage at
/// `/storage/emulated/0/` plus an optional user-specified custom path
/// (typically the SD card root, e.g. `/storage/6262-6432`). Lists
/// subdirectories and files whose extension matches
/// [allowedExtensions], lets the user navigate in/out, and returns
/// the full path of the tapped file via `Navigator.pop(context, path)`
/// — or `null` if the user backs out without picking anything.
///
/// Volume handling:
/// - If [AppModel.customStorageRootPath] is null/empty (default), the
///   picker drops straight into internal storage. The up-button at
///   the volume root closes the picker.
/// - If a custom path is set, the picker shows a chooser screen first
///   listing "Internal storage" and the custom path as separate
///   entries. Picking one enters that volume. The up-button at a
///   volume root returns to the chooser.
///
/// Why we don't auto-discover other volumes: Android 11+ scoped
/// storage forbids `/storage/` listing for third-party apps even with
/// `MANAGE_EXTERNAL_STORAGE` granted. So `Directory('/storage').list()`
/// always returns empty/EPERM. SD cards mounted at `/storage/<UUID>`
/// remain readable by direct path access, but we have no way to
/// discover the UUID from inside the app sandbox. The user has to
/// supply it manually via Settings → "Custom storage path".
///
/// Why this picker exists at all: `file_picker`'s SAF-backed
/// implementation on some Android OEM builds (Huawei EMUI/HarmonyOS
/// confirmed, others suspected) materialises the picked file by
/// copying it into app-private cache under
/// `/data/user/0/<pkg>/cache/file_picker/` before returning its path.
/// The caller then can't enumerate the picked file's siblings in the
/// user's actual audiobook folder, which breaks chapter-navigation
/// and companion-srt auto-attach. Walking the filesystem directly via
/// `Directory.listSync()` (which works because
/// `MANAGE_EXTERNAL_STORAGE` is granted) keeps every returned path on
/// real storage, and the caller's downstream logic just works.
class FolderAudioPicker extends StatefulWidget {
  const FolderAudioPicker({
    super.key,
    required this.appModel,
    this.initialDir,
    this.allowedExtensions = const [
      '.mp3',
      '.m4a',
      '.m4b',
      '.ogg',
      '.wav',
      '.flac',
      '.aac',
    ],
  });

  /// Used to read the optional custom storage root path. We hold a
  /// reference here rather than going through `ref.watch` because the
  /// picker is a plain `StatefulWidget` (it predates the riverpod
  /// migration that the rest of the page tree uses).
  final AppModel appModel;

  /// Directory to open first. If null — or if it resolves to a path
  /// outside any known volume root (e.g. a cache path saved from a
  /// previous app version that used `file_picker`) — the picker
  /// starts at the chooser (multi-volume) or at internal storage
  /// directly (no custom path set).
  final String? initialDir;

  /// Lowercase extensions including the leading dot. Non-matching
  /// files are hidden from the listing; directories are always shown
  /// regardless of their name.
  final List<String> allowedExtensions;

  @override
  State<FolderAudioPicker> createState() => _FolderAudioPickerState();
}

class _FolderAudioPickerState extends State<FolderAudioPicker> {
  static const String _internalRoot = '/storage/emulated/0';

  /// All known volume roots in display order. Always starts with
  /// internal storage; if a custom path is configured, it follows.
  /// Computed once in initState and not refreshed during the browse
  /// session — if the user changes the custom path mid-pick they can
  /// close and reopen the picker.
  late List<String> _volumeRoots;

  /// Current directory being shown, OR null when the listing is the
  /// volume chooser. The chooser is shown only when there is more
  /// than one volume root; with just internal storage we drop
  /// straight in.
  String? _currentDir;

  /// The volume root [_currentDir] is currently inside, used as the
  /// stop-point for [_goUp]. Null whenever [_currentDir] is null
  /// (chooser screen).
  String? _currentVolumeRoot;

  List<FileSystemEntity> _entries = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _volumeRoots = _buildVolumeRoots();

    // Try to land in the requested initialDir if it lives inside any
    // known volume; otherwise pick a sensible default based on volume
    // count.
    String? targetDir;
    String? targetVolume;
    final requested = widget.initialDir;
    if (requested != null && Directory(requested).existsSync()) {
      for (final vol in _volumeRoots) {
        if (requested == vol || requested.startsWith('$vol/')) {
          targetDir = requested;
          targetVolume = vol;
          break;
        }
      }
    }

    if (targetDir != null) {
      _currentDir = targetDir;
      _currentVolumeRoot = targetVolume;
      _loadDir();
    } else if (_volumeRoots.length == 1) {
      // Only internal storage — skip the chooser and open it directly.
      _currentDir = _volumeRoots.first;
      _currentVolumeRoot = _volumeRoots.first;
      _loadDir();
    } else {
      // Multiple volumes — show the chooser. _currentDir stays null.
    }
  }

  /// Build the list of volume roots from configuration. Internal
  /// storage is always first; the user's custom path (if any) is
  /// second. We do NOT verify the custom path exists — if the user
  /// configured one but the SD card was ejected, [_loadDir] will
  /// surface that as an inline error when they try to enter it.
  List<String> _buildVolumeRoots() {
    final List<String> roots = [_internalRoot];
    final String? custom = widget.appModel.customStorageRootPath;
    if (custom != null && custom.isNotEmpty && custom != _internalRoot) {
      roots.add(custom);
    }
    return roots;
  }

  void _loadDir() {
    final dirPath = _currentDir;
    if (dirPath == null) return; // Chooser screen, nothing to load.
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        setState(() {
          _error = 'Directory does not exist';
          _entries = [];
        });
        return;
      }
      final all = dir.listSync(followLinks: false);
      // Filter: always include directories, include files only when
      // their extension is in the allow-list, hide dotfile/dotdir
      // entries so the listing doesn't fill with app-private noise
      // like `.thumbnails` or `.trashed-*`.
      final filtered = all.where((e) {
        final name = e.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.')) return false;
        if (e is Directory) return true;
        if (e is File) {
          final lower = e.path.toLowerCase();
          return widget.allowedExtensions.any(lower.endsWith);
        }
        return false;
      }).toList();
      // Directories first, then files; within each group sort
      // case-insensitive by basename.
      filtered.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
        final aName = a.path.split(Platform.pathSeparator).last.toLowerCase();
        final bName = b.path.split(Platform.pathSeparator).last.toLowerCase();
        return aName.compareTo(bName);
      });
      setState(() {
        _entries = filtered;
        _error = null;
      });
    } catch (e) {
      // Permission-denied on a subdirectory, or similar. Show the
      // error inline instead of blowing up the picker.
      setState(() {
        _error = 'Error listing directory: $e';
        _entries = [];
      });
    }
  }

  void _navigateTo(String path) {
    setState(() {
      _currentDir = path;
    });
    _loadDir();
  }

  /// Open a volume from the chooser screen. Sets both the current
  /// directory and the bounding volume root so [_goUp] knows where
  /// to stop.
  void _enterVolume(String volumeRoot) {
    setState(() {
      _currentDir = volumeRoot;
      _currentVolumeRoot = volumeRoot;
    });
    _loadDir();
  }

  /// Go to the parent directory. Stops at the current volume's root;
  /// from the volume root, returns to the chooser when more than one
  /// volume exists, or no-ops with a single volume (handled by the
  /// AppBar simply not showing the up button at root in that case).
  void _goUp() {
    final cur = _currentDir;
    final volRoot = _currentVolumeRoot;
    if (cur == null || volRoot == null) return;
    if (cur == volRoot) {
      if (_volumeRoots.length > 1) {
        setState(() {
          _currentDir = null;
          _currentVolumeRoot = null;
          _entries = [];
          _error = null;
        });
      }
      return;
    }
    final parent = Directory(cur).parent.path;
    if (parent.length < volRoot.length) return;
    _navigateTo(parent);
  }

  /// Human-readable label for a volume root.
  String _labelForVolume(String path) {
    if (path == _internalRoot) return 'Internal storage';
    return path.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    final cur = _currentDir;
    final volRoot = _currentVolumeRoot;

    final String titleText;
    if (cur == null) {
      titleText = 'Storage';
    } else if (volRoot != null && cur == volRoot) {
      titleText = _labelForVolume(volRoot);
    } else if (volRoot != null) {
      titleText = cur.length > volRoot.length
          ? cur.substring(volRoot.length + 1)
          : '/';
    } else {
      titleText = cur;
    }

    final bool showUpButton =
        cur != null && (cur != volRoot || _volumeRoots.length > 1);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFFFFFF00)),
        title: Text(
          titleText,
          style: const TextStyle(
            color: Color(0xFFFFFF00),
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (showUpButton)
            IconButton(
              tooltip: 'Parent folder',
              icon: const Icon(Icons.arrow_upward),
              color: const Color(0xFFFFFF00),
              onPressed: _goUp,
            ),
        ],
      ),
      body: cur == null ? _buildChooser() : _buildDirListing(),
    );
  }

  Widget _buildChooser() {
    return ListView.builder(
      itemCount: _volumeRoots.length,
      itemBuilder: (ctx, i) {
        final vol = _volumeRoots[i];
        return ListTile(
          leading: const Icon(
            Icons.sd_storage,
            color: Color(0xFFFFFF00),
          ),
          title: Text(
            _labelForVolume(vol),
            style: const TextStyle(color: Color(0xFFFFFF00)),
          ),
          subtitle: Text(
            vol,
            style: const TextStyle(
              color: Color(0xFFAAAA00),
              fontSize: 11,
            ),
          ),
          onTap: () => _enterVolume(vol),
        );
      },
    );
  }

  Widget _buildDirListing() {
    if (_entries.isEmpty && _error == null) {
      return const Center(
        child: Text(
          '(empty)',
          style: TextStyle(color: Color(0xFFFFFF00)),
        ),
      );
    }
    return Column(
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF220000),
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFFFFF00)),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _entries.length,
            itemBuilder: (ctx, i) {
              final entity = _entries[i];
              final name =
                  entity.path.split(Platform.pathSeparator).last;
              final isDir = entity is Directory;
              return ListTile(
                leading: Icon(
                  isDir ? Icons.folder : Icons.audio_file,
                  color: const Color(0xFFFFFF00),
                ),
                title: Text(
                  name,
                  style: const TextStyle(color: Color(0xFFFFFF00)),
                ),
                onTap: () {
                  if (isDir) {
                    _navigateTo(entity.path);
                  } else {
                    Navigator.pop(context, entity.path);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
