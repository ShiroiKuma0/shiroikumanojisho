import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'common.dart';
import 'isolate.dart';
import 'zip.dart';

const kDefaultCompressionLevel = 6;

/// Writes data to a Zip archive.
class ZipFileWriterSync {
  ZipHandle? _handle;

  /// Creates a new Zip archive in the speficied file.
  ///
  /// The [compressionLevel] indicates how much an item in the archive will
  /// be compressed. It ranges from 0 (no compression) to 9 (maximum
  /// compression).
  ///
  /// Throws a [ZipException] if the file cannot be created.
  void create(File file, {int compressionLevel = kDefaultCompressionLevel}) {
    if (_handle != null) {
      throw ZipException('ZipFileWriter already created; call close() first');
    }
    _handle = _create(file, compressionLevel);
  }

  /// Closes the writer. After closing no further write operations are
  /// allowed. You can however call [create] again using a new file.
  void close() {
    if (_handle != null) {
      _close(_handle!);
    }
    _handle = null;
  }

  /// Writes the data contained in the specified file as a Zip archive
  /// entry [name].
  ///
  /// Compression can be disabled using the [compress] argument. This
  /// can be useful for data that is already compressed such as a JPEG
  /// image.
  ///
  /// Throws a [ZipException] if the operation fails.
  void writeFile(String name, File file, {bool compress = true}) =>
      _writeFile(_checkCreated(_handle), name, file, compress);

  /// Writes the specified data as a Zip archive entry [name].
  ///
  /// Compression can be disabled using the [compress] argument. This
  /// can be useful for data that is already compressed such as a JPEG
  /// image.
  ///
  /// Throws a [ZipException] if the operation fails.
  void writeData(String name, Uint8List data, {bool compress = true}) =>
      _writeData(_checkCreated(_handle), name, data, compress);
}

/// Writes data to a Zip archive asynchronously.
class ZipFileWriter {
  final _manager = IsolateManager<_RequestType>(_zipWorker);

  /// Creates a new Zip archive in the speficied file.
  ///
  /// The [compressionLevel] indicates how much an item in the archive will
  /// be compressed. It ranges from 0 (no compression) to 9 (maximum
  /// compression).
  ///
  /// Throws a [ZipException] if the file cannot be created.
  Future<void> create(File file, {int compressionLevel = kDefaultCompressionLevel}) =>
      _manager.sendRequest<void>(_RequestType.create, [file, compressionLevel]);

  /// Closes the writer. After closing no further write operations are
  /// allowed. You can however call [create] again using a new file.
  Future<void> close() => _manager.sendRequest<void>(_RequestType.close);

  /// Writes the data contained in the specified file as a Zip archive
  /// entry [name].
  ///
  /// Compression can be disabled using the [compress] argument. This
  /// can be useful for data that is already compressed such as a JPEG
  /// image.
  ///
  /// Throws a [ZipException] if the operation fails.
  Future<void> writeFile(String name, File file, {bool compress = true}) =>
      _manager.sendRequest<void>(_RequestType.writeFile, [name, file, compress]);

  /// Writes the specified data as a Zip archive entry [name].
  ///
  /// Compression can be disabled using the [compress] argument. This
  /// can be useful for data that is already compressed such as a JPEG
  /// image.
  ///
  /// Throws a [ZipException] if the operation fails.
  Future<void> writeData(String name, Uint8List data, {bool compress = true}) =>
      _manager.sendRequest<void>(_RequestType.writeData, [name, data, compress]);

  static void _zipWorker(SendPort sendPort) async {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    ZipHandle? handle;
    await for (final message in receivePort) {
      if (message is IsolateRequest) {
        try {
          if (message.type == _RequestType.create) {
            if (handle != null) {
              throw ZipException('ZipFileWriter already created; call close() first');
            }
            final args = message.param as List<dynamic>;
            final file = args[0] as File;
            final compressionLevel = args[1] as int;
            handle = _create(file, compressionLevel);
            sendPort.send(IsolateResponse(message.id));
          } else if (message.type == _RequestType.close) {
            if (handle != null) {
              _close(handle);
            }
            sendPort.send(IsolateResponse(message.id));
            sendPort.send(IsolateQuitMessage());
            break;
          } else if (message.type == _RequestType.writeFile) {
            final args = message.param as List<dynamic>;
            final name = args[0] as String;
            final file = args[1] as File;
            final compress = args[2] as bool;
            _writeFile(_checkCreated(handle), name, file, compress);
            sendPort.send(IsolateResponse(message.id));
          } else if (message.type == _RequestType.writeData) {
            final args = message.param as List<dynamic>;
            final name = args[0] as String;
            final data = args[1] as Uint8List;
            final compress = args[2] as bool;
            _writeData(_checkCreated(handle), name, data, compress);
            sendPort.send(IsolateResponse(message.id));
          }
        } on ZipException catch (ex) {
          sendPort.send(IsolateResponse(message.id, null, ex.message));
        }
      }
    }
    asyncZipDebugPrint?.call('ZipFileWriterAsync isolate stopped');
  }
}

ZipHandle _create(File file, int compressionLevel) {
  final nativeFilePath = file.path.toNativeUtf8();
  final handle = zipOpen(nativeFilePath, compressionLevel, ModeWrite);
  malloc.free(nativeFilePath);
  if (handle.address == 0) {
    throw ZipException('Cannot create Zip file at "${file.path}"');
  }
  return handle;
}

void _writeFile(ZipHandle handle, String name, File file, bool compress) {
  var level = 0;
  if (!compress) {
    level = zipSetLevel(handle, 0);
  }

  try {
    final nativeName = name.toNativeUtf8();
    final openResult = zipEntryOpen(handle, nativeName);
    malloc.free(nativeName);

    if (openResult != 0) {
      throw ZipException('Cannot create entry "$name"');
    }

    final nativePath = file.path.toNativeUtf8();
    final writeResult = zipEntryFWrite(handle, nativePath);
    malloc.free(nativePath);

    if (writeResult != 0) {
      throw ZipException('Cannot write file "$file" to entry "$name"');
    }

    zipEntryClose(handle);
  } finally {
    if (!compress) {
      zipSetLevel(handle, level);
    }
  }
}

void _writeData(ZipHandle handle, String name, Uint8List data, bool compress) {
  var level = 0;
  if (!compress) {
    level = zipSetLevel(handle, 0);
  }

  try {
    final nativeName = name.toNativeUtf8();
    final openResult = zipEntryOpen(handle, nativeName);
    malloc.free(nativeName);

    if (openResult != 0) {
      throw ZipException('Cannot create entry "$name"');
    }

    final bufferPointer = malloc<Uint8>(data.length);
    final buffer = bufferPointer.asTypedList(data.length);
    buffer.setAll(0, data);

    final writeResult = zipEntryWrite(handle, bufferPointer, data.length);
    malloc.free(bufferPointer);

    if (writeResult != 0) {
      throw ZipException('Cannot write file ${data.length} bytes of data to entry "$name"');
    }

    zipEntryClose(handle);
  } finally {
    if (!compress) {
      zipSetLevel(handle, level);
    }
  }
}

void _close(ZipHandle handle) {
  zipClose(handle);
}

ZipHandle _checkCreated(ZipHandle? handle) {
  if (handle == null) {
    throw ZipException('Zip file has not yet been created');
  }
  return handle;
}

enum _RequestType {
  create,
  close,
  writeFile,
  writeData,
}
