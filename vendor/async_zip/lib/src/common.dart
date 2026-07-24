Function(String)? asyncZipDebugPrint;

/// Describes a Zip archive item.
class ZipEntry {
  /// The name of the entry.
  final String name;

  /// Whether the entry is a directory or a file.
  final bool isDir;

  /// The size in bytes of the entry.
  final int size;

  /// The CRC32 checksum of the entry.
  final int crc32;

  /// Creates a new entry object.
  ZipEntry(this.name, this.isDir, this.size, this.crc32);
}

/// Notifies the caller about a failed operation when dealing with
/// [ZipFileReader] and [ZipFileWriter] or their respective asynchronous
/// counterparts [ZipFileReaderAsync] and [ZipFileWriterAsync].
class ZipException implements Exception {
  /// The message describing the failed operation.
  final String message;

  /// Creates a new exception with the specified message.
  ZipException(this.message);

  @override
  String toString() {
    return 'ZipException($message)';
  }
}
