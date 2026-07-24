# Asynchronous Zip library

![Pub Version](https://img.shields.io/pub/v/async_zip)

This package allows fast reading and writing Zip archives asynchronously and
with low memory consumption.

There is already a [standard archive library](https://pub.dev/packages/archive)
for Dart. But the standard library has two major issues:
- It cannot be used asynchronously
- It reads Zip files completely to memory and unpacks them from there. This is
  an issue when reading large Zip files on low or medium range devices.

Zip files can be read and written synchronously as well as asynchronously.
Synchronous access may be faster in some situations. Choose whatever you need.

Make sure to call `close()` in any case after having worked with a Zip file.
You are leaking resources otherwise or risk ending up with an unfinished Zip
file when working with `ZipFileWriter` and `ZipFileWriterSync`.

## Reading Zip files

### Reading data synchronously

```dart
import 'package:async_zip/async_zip.dart';

final reader = ZipFileReaderSync();
try {
  reader.open(File('path-to-archive.zip'));
  
  // Get all Zip entries
  final entries = reader.entries();
  for (final entry in entries) {
    print('${entry.name} ${entry.size}');
  }

  // Read a specific file
  reader.readFile('specific-image.jpg', File('/somewhere/on/disk/image.jpg'));

  // Read specific data as Uint8List
  final data = reader.readFile('README.md');

} on ZipException catch (ex) {
  print('Could not read Zip file: ${$ex.message}');
} finally {
  reader.close();
}
```

### Reading data asynchronously

```dart
import 'package:async_zip/async_zip.dart';

final reader = ZipFileReader();
try {
  reader.open(File('path-to-archive.zip'));
  
  // Get all Zip entries
  final entries = await reader.entries();
  for (final entry in entries) {
    print('${entry.name} ${entry.size}');
  }

  // Read a specific file
  await reader.readFile('specific-image.jpg', File('/somewhere/on/disk/image.jpg'));

  // Read specific data as Uint8List
  final data = await reader.readFile('README.md');

} on ZipException catch (ex) {
  print('Could not read Zip file: ${$ex.message}');
} finally {
  await reader.close();
}
```

## Writing Zip files

### Writing data synchronously

```dart
import 'package:async_zip/async_zip.dart';

final reader = ZipFileWriterSync();
try {
  reader.create(File('path-to-archive.zip'));

  // Write a file to the Zip file
  reader.writeFile('image.jpg', File('/somewhere/on/disk/image.jpg'));

  // Write Uint8List data to the Zip file
  Uint8List data = …; // some binary data
  reader.writeData('data.txt', data);

} on ZipException catch (ex) {
  print('Could not create Zip file: ${$ex.message}');
} finally {
  reader.close();
}
```

### Write data asynchronously

```dart
import 'package:async_zip/async_zip.dart';

final reader = ZipFileWriter();
try {
  await reader.create(File('path-to-archive.zip'));

  // Write a file to the Zip file
  await reader.writeFile('image.jpg', File('/somewhere/on/disk/image.jpg'));

  // Write Uint8List data to the Zip file
  Uint8List data = …; // some binary data
  await reader.writeData('data.txt', data);

} on ZipException catch (ex) {
  print('Could not create Zip file: ${$ex.message}');
} finally {
  await reader.close();
}
```

## Extract a Zip archive to a folder

Two functions allow extraction of a Zip archive to a folder.
`extractZipArchive()` works asynchronously, `extractZipArchiveSync()` works
synchronously. Both can take an optional callback parameter that is called
once for every extracted file (after the file has been copied to the folder).

```dart
import 'package:async_zip/async_zip.dart';

final archive = File(…);
final extractTo = Directory(…);
var copied = 0;
var percentage = 0;
await extractZipArchive(archive, extractTo, callback: (entry, totalEntries) {
  copied++;
  final newPercentage = (copied * 100 / totalEntries).round();
  if (newPercentage != percentage) {
    percentage = newPercentage;
    print('$percentage%');
  }
});

```

## Internals

This package uses the following C library for reading and writing:  
<https://github.com/kuba--/zip>

The library is integrated using Dart's
[foreign function interface](https://dart.dev/guides/libraries/c-interop) (FFI).