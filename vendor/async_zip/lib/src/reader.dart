import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'isolate.dart';
import 'zip.dart';

/// Extracts a Zip archive into the specified directory.
///
/// if the optional [callback] is specified, it will be called for every
/// extracted file after the extraction has been completed.
void extractZipArchiveSync(File archive, Directory dir, {void Function(ZipEntry entry, int totalEntries)? callback}) {
  if (callback == null) {
    final archivePath = archive.path.toNativeUtf8();
    final dirPath = dir.path.toNativeUtf8();
    try {
      zipExtract(archivePath, dirPath, nullptr, nullptr);
    } finally {
      malloc.free(archivePath);
      malloc.free(dirPath);
    }
    return;
  }

  final reader = ZipFileReaderSync();
  reader.open(archive);
  final entries = reader.entries();
  for (final entry in entries) {
    if (entry.isDir) {
      Directory(path.join(dir.path, entry.name)).createSync(recursive: true);
    } else {
      final filePath = path.join(dir.path, entry.name);
      final fileDir = Directory(path.dirname(filePath));
      fileDir.createSync(recursive: true);
      reader.readToFile(entry.name, File(filePath));
    }
    callback.call(entry, entries.length);
  }
  reader.close();
}

/// Asynchronously extracts a Zip archive into the specified directory.
///
/// if the optional [callback] is specified, it will be called for every
/// extracted file after the extraction has been completed.
Future<void> extractZipArchive(File archive, Directory dir,
    {void Function(ZipEntry entry, int totalEntries)? callback}) async {
  final receivePort = ReceivePort();
  final sendPort = receivePort.sendPort;
  Isolate.spawn((args) {
    extractZipArchiveSync(archive, dir, callback: (entry, totalEntries) {
      sendPort.send((entry, totalEntries));
    });
    sendPort.send(null);
  }, null);
  await for (final message in receivePort) {
    switch (message) {
      case (ZipEntry entry, int totalEntries):
        callback?.call(entry, totalEntries);
      default:
        receivePort.close();
        break;
    }
  }
}

/// Reads data from a Zip archive.
class ZipFileReaderSync {
  ZipHandle? _handle;

  /// Opens the specified Zip archive for read access.
  ///
  /// Throws a [ZipException] if the file cannot be opened.
  void open(File file) {
    if (_handle != null) {
      throw ZipException('ZipFileReader already opened; call close() first');
    }
    _handle = _open(file);
  }

  /// Closes the reader. After closing no further read operations are
  /// allowed. You can however [open] the reader again using a new file.
  void close() {
    if (_handle != null) {
      _close(_handle!);
    }
    _handle = null;
  }

  /// Returns a list of all items contained in the Zip archive.
  ///
  /// Throws a [ZipException] if the operation fails.
  Iterable<ZipEntry> entries() => _entries(_checkOpened(_handle));

  /// Reads the entry specified by [name] and writes the unpacked data
  /// to [file].
  ///
  /// Throws a [ZipException] if the operation fails.
  void readToFile(String name, File file) => _readToFile(_checkOpened(_handle), name, file);

  /// Reads the entry specified by [name] and returns the unpached data
  /// as a [Uint8List].
  ///
  /// Throws a [ZipException] if the operation fails.
  Uint8List read(String name) => _read(_checkOpened(_handle), name);
}

/// Reads data from a Zip archive asynchronously.
class ZipFileReader {
  final _manager = IsolateManager<_RequestType>(_zipWorker);

  /// Opens the specified Zip archive for read access.
  ///
  /// Throws a [ZipException] if the file cannot be opened.
  Future<void> open(File file) => _manager.sendRequest<void>(_RequestType.open, file);

  /// Closes the reader. After closing no further read operations are
  /// allowed. You can however [open] the reader again using a new file.
  Future<void> close() => _manager.sendRequest<void>(_RequestType.close);

  /// Returns a list of all items contained in the Zip archive.
  ///
  /// Throws a [ZipException] if the operation fails.
  Future<List<ZipEntry>> entries() => _manager.sendRequest<List<ZipEntry>>(_RequestType.entries);

  /// Reads the entry specified by [name] and writes the unpacked data
  /// to [file].
  ///
  /// Throws a [ZipException] if the operation fails.
  Future<void> readToFile(String name, File file) => _manager.sendRequest<void>(_RequestType.readToFile, [name, file]);

  /// Reads the entry specified by [name] and returns the unpacked data
  /// as a [Uint8List].
  ///
  /// Throws a [ZipException] if the operation fails.
  Future<Uint8List> read(String name) => _manager.sendRequest<Uint8List>(_RequestType.read, name);

  static void _zipWorker(SendPort sendPort) async {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    ZipHandle? handle;
    await for (final message in receivePort) {
      if (message is IsolateRequest) {
        try {
          if (message.type == _RequestType.open) {
            if (handle != null) {
              throw ZipException('ZipFileReader already opened; call close() first');
            }
            final file = message.param as File;
            handle = _open(file);
            sendPort.send(IsolateResponse(message.id));
          } else if (message.type == _RequestType.close) {
            if (handle != null) {
              _close(handle);
            }
            sendPort.send(IsolateResponse(message.id));
            sendPort.send(IsolateQuitMessage());
            break;
          } else if (message.type == _RequestType.entries) {
            final entries = _entries(_checkOpened(handle));
            sendPort.send(IsolateResponse(message.id, entries));
          } else if (message.type == _RequestType.readToFile) {
            final args = message.param as List<dynamic>;
            final name = args[0] as String;
            final file = args[1] as File;
            _readToFile(_checkOpened(handle), name, file);
            sendPort.send(IsolateResponse(message.id));
          } else if (message.type == _RequestType.read) {
            final name = message.param as String;
            final data = _read(_checkOpened(handle), name);
            sendPort.send(IsolateResponse(message.id, data));
          }
        } on ZipException catch (ex) {
          sendPort.send(IsolateResponse(message.id, null, ex.message));
        }
      }
    }
    asyncZipDebugPrint?.call('ZipFileReaderAsync isolate stopped');
  }
}

ZipHandle _open(File file) {
  final nativeFilePath = file.path.toNativeUtf8();
  final handle = zipOpen(nativeFilePath, 0, ModeRead);
  malloc.free(nativeFilePath);
  if (handle.address == 0) {
    throw ZipException('Cannot open Zip file at "${file.path}"');
  }
  return handle;
}

void _close(ZipHandle handle) {
  zipClose(handle);
}

Iterable<ZipEntry> _entries(ZipHandle handle) {
  final numEntries = zipEntriesTotal(handle);
  if (numEntries < 0) {
    throw ZipException('Cannot determine number of Zip entries');
  }

  final entries = <ZipEntry>[];
  for (int i = 0; i < numEntries; i++) {
    int success = zipEntryOpenByIndex(handle, i);
    if (success == 0) {
      final name = zipEntryName(handle).toDartString();
      final size = zipEntrySize(handle);
      final isDir = zipEntryIsDir(handle) == 1;
      final crc32 = zipEntryCrc32(handle);
      entries.add(ZipEntry(name, isDir, size, crc32));
      zipEntryClose(handle);
    }
  }

  return entries;
}

void _readToFile(ZipHandle handle, String name, File file) {
  final nativeName = name.toNativeUtf8();
  final openResult = zipEntryOpen(handle, nativeName);
  malloc.free(nativeName);

  if (openResult != 0) {
    throw ZipException('Entry "$name" not found');
  }

  final nativePath = file.path.toNativeUtf8();
  final freadResult = zipEntryFRead(handle, nativePath);
  malloc.free(nativePath);
  zipEntryClose(handle);

  if (freadResult < 0) {
    throw ZipException('Cannot write "$name" to file "${file.path}');
  }
}

Uint8List _read(ZipHandle handle, String name) {
  final nativeName = name.toNativeUtf8();
  final openResult = zipEntryOpen(handle, nativeName);
  malloc.free(nativeName);

  if (openResult != 0) {
    throw ZipException('Entry "$name" not found');
  }

  final size = zipEntrySize(handle);
  final dataPointer = malloc<Uint8>(size);

  final bytesRead = zipEntryNoAllocRead(handle, dataPointer, size);
  if (bytesRead < 0) {
    malloc.free(dataPointer);
    zipEntryClose(handle);
    ZipException('Cannot read data from "$name"');
  }

  final data = Uint8List(bytesRead);
  data.setAll(0, dataPointer.asTypedList(bytesRead));

  malloc.free(dataPointer);
  zipEntryClose(handle);

  return data;
}

ZipHandle _checkOpened(ZipHandle? handle) {
  if (handle == null) {
    throw ZipException('Zip file has not yet been opened');
  }
  return handle;
}

enum _RequestType {
  open,
  close,
  entries,
  readToFile,
  read,
}
