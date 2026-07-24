import 'package:flutter/material.dart';

class FileIconHelper {
  /// Set the icon for a file
  static double iconSize = 32;

  static Icon getIcon(String filename, Color color) {
    var icon = Icons.description;

    final _extension = filename.split('.').last.toLowerCase();
    if (_extension == 'db' ||
        _extension == 'sqlite' ||
        _extension == 'sqlite3') {
      icon = Icons.dns;
    } else if (_extension == 'jpg' ||
        _extension == 'jpeg' ||
        _extension == 'bmp' ||
        _extension == 'png') {
      icon = Icons.image;
    } else if (videoExtensions.contains(_extension)) {
      icon = Icons.movie;
    } else if (subtitlesExtensions.contains(_extension)) {
      icon = Icons.subtitles;
    }

    // default
    return Icon(
      icon,
      color: color,
      size: iconSize,
    );
  }

  static List<String> subtitlesExtensions = [
    'srt',
    'ass',
  ];

  static List<String> videoExtensions = [
    '3gp',
    'aaf',
    'asf',
    'avchd',
    'avi',
    'drc',
    'flv',
    'm2v',
    'm4p',
    'm4v',
    'mkv',
    'mng',
    'mov',
    'mp2',
    'mp4',
    'mpe',
    'mpeg',
    'mpg',
    'mpv',
    'mxf',
    'nsv',
    'ogg',
    'ogv',
    'ogm',
    'qt',
    'rm',
    'rmvb',
    'roq',
    'srt',
    'svi',
    'vob',
    'webm',
    'wmv',
    'yuv'
  ];
}
