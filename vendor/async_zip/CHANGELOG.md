## 0.1.0

- Add functions to extract an archive into a directory.
- Rename classes to be more Dart idiomatic:
  - `ZipFileReader` becomes `ZipFileReaderSync`
  - `ZipFileReaderAsync` becomes `ZipFileReader`
  - `ZipFileWriter` becomes `ZipFileWriterSync`
  - `ZipFileWriterAsync` becomes `ZipFileWriter`

## 0.0.4

- Update C library to version 0.2.6.
- Change behavior of C library for Zip entries without a timestamp. Instead of
  interpreting the zero timestamp value as 1979-11-30 00:00:00 the current
  timestamp used.

## 0.0.3

- Remove unnecessary imports in order to satisfy static analyzer.
- Update dependencies.
- Fix async example in README.md and use ZipFileWriterAsync instead of ZipFileWriter
  (thank you ioridev) .
- Migrate Android code to SDK and API 33.

## 0.0.2

- Reformat source files with a line length of 80 characters and increase the
  length of the description in pubspec.yaml to increase the package score on
  `pub.dev`.

## 0.0.1

- Initial release with support for reading and writing Zip files synchronously
  and asynchronously.
