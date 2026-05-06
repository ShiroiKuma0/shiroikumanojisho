import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shiroikumanojisho/models.dart';

/// Full-screen directory-tree browser for picking a single file by
/// extension. Generalisation of [FolderAudioPicker] used for backup
/// ZIPs, export bundles, and any other case where we need a real
/// `/storage/...` path without having `file_picker` route through SAF
/// and copy the picked file into `cache/file_picker/` first.
///
/// Walks the device's external storage volumes — internal storage at
/// `/storage/emulated/0/` plus an optional user-specified custom path
/// (typically the SD card root, e.g. `/storage/6262-6432`). Lists
/// subdirectories and files whose extension matches
/// [allowedExtensions], lets the user navigate in/out, and returns
/// the full path of the tapped file via `Navigator.pop(context, path)`
/// — or `null` if the user backs out without picking anything.
///
/// Volume handling and the rationale for direct filesystem traversal
/// (instead of using `file_picker`) match the documentation on
/// [FolderAudioPicker] — see that class for the full story. Short
/// version: `MANAGE_EXTERNAL_STORAGE` is granted, so direct
/// `Directory.listSync()` works and yields real paths instead of the
/// app-cache copies that `file_picker`'s SAF route produces.
///
/// This picker exists in addition to the audio one rather than
/// replacing it because audio entries need a context-specific icon
/// (`Icons.audio_file`) and have callers that depend on it. Keeping
/// them parallel avoids touching audio-source code.
class FolderFilePicker extends StatefulWidget {
  const FolderFilePicker({
    super.key,
    required this.appModel,
    required this.allowedExtensions,
    required this.fileIcon,
    this.title = 'Pick a file',
    this.initialDir,
  });

  /// Used to read the optional custom storage root path.
  final AppModel appModel;

  /// Lowercase extensions including the leading dot (e.g. `.zip`,
  /// `.json`). Non-matching files are hidden from the listing;
  /// directories are always shown regardless of their name.
  final List<String> allowedExtensions;

  /// Leading icon for files in the listing. Folders always render
  /// with [Icons.folder] regardless.
  final IconData fileIcon;

  /// AppBar title shown on the chooser and listing screens.
  final String title;

  /// Directory to open first. If null — or if it resolves to a path
  /// outside any known volume root — the picker starts at the
  /// chooser (multi-volume) or at internal storage directly (no
  /// custom path set).
  final String? initialDir;

  @override
  State<FolderFilePicker> createState() => _FolderFilePickerState();
}

class _FolderFilePickerState extends State<FolderFilePicker> {
  static const String _internalRoot = '/storage/emulated/0';

  late List<String> _volumeRoots;
  String? _currentDir;
  String? _currentVolumeRoot;
  List<FileSystemEntity> _entries = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _volumeRoots = _buildVolumeRoots();

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
      _currentDir = _volumeRoots.first;
      _currentVolumeRoot = _volumeRoots.first;
      _loadDir();
    }
  }

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
    if (dirPath == null) return;
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
      setState(() {
        _error = 'Error listing directory: $e';
        _entries = [];
      });
    }
  }

  void _navigateTo(String p) {
    setState(() {
      _currentDir = p;
    });
    _loadDir();
  }

  void _enterVolume(String volumeRoot) {
    setState(() {
      _currentDir = volumeRoot;
      _currentVolumeRoot = volumeRoot;
    });
    _loadDir();
  }

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

  String _labelForVolume(String p) {
    if (p == _internalRoot) return 'Internal storage';
    return p.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    final cur = _currentDir;
    final volRoot = _currentVolumeRoot;

    final String titleText;
    if (cur == null) {
      titleText = widget.title;
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
              final name = entity.path.split(Platform.pathSeparator).last;
              final isDir = entity is Directory;
              return ListTile(
                leading: Icon(
                  isDir ? Icons.folder : widget.fileIcon,
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
