import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

const ModeRead = 0x72;
const ModeWrite = 0x77;
const ModeAppend = 0x61;

final DynamicLibrary zipLib = Platform.isAndroid
    ? DynamicLibrary.open("libasync_zip.so")
    : DynamicLibrary.process();

typedef ZipHandle = Pointer<Void>;
typedef CharPointer = Pointer<Utf8>;
typedef DataPointer = Pointer<Uint8>;

// extern ZIP_EXPORT struct zip_t *zip_open(const char *zipname, int level, char mode);
typedef ZipOpenNative = ZipHandle Function(CharPointer, Int32, Int8);
typedef ZipOpen = ZipHandle Function(CharPointer zipName, int level, int mode);

final zipOpen = zipLib.lookupFunction<ZipOpenNative, ZipOpen>('zip_open');

// extern ZIP_EXPORT void zip_close(struct zip_t *zip);
typedef ZipCloseNative = Void Function(ZipHandle);
typedef ZipClose = void Function(ZipHandle);

final zipClose = zipLib.lookupFunction<ZipCloseNative, ZipClose>('zip_close');

// extern ZIP_EXPORT int zip_set_level(struct zip_t *zip, int level);
typedef ZipSetLevelNative = Int32 Function(ZipHandle, Int32);
typedef ZipSetLevel = int Function(ZipHandle, int);

final zipSetLevel = zipLib.lookupFunction<ZipSetLevelNative, ZipSetLevel>('zip_set_level');

// extern ZIP_EXPORT ssize_t zip_entries_total(struct zip_t *zip);
typedef ZipEntriesTotalNative = Int32 Function(ZipHandle);
typedef ZipEntriesTotal = int Function(ZipHandle);

final zipEntriesTotal = zipLib.lookupFunction<ZipEntriesTotalNative, ZipEntriesTotal>('zip_entries_total');

// extern ZIP_EXPORT int zip_entry_openbyindex(struct zip_t *zip, int index);
typedef ZipEntryOpenByIndexNative = Int32 Function(ZipHandle, Int32 index);
typedef ZipEntryOpenByIndex = int Function(ZipHandle, int index);

final zipEntryOpenByIndex = zipLib.lookupFunction<ZipEntryOpenByIndexNative, ZipEntryOpenByIndex>('zip_entry_openbyindex');

// extern ZIP_EXPORT int zip_entry_open(struct zip_t *zip, const char *entryname);
typedef ZipEntryOpenNative = Int32 Function(ZipHandle, Pointer<Utf8>);
typedef ZipEntryOpen = int Function(ZipHandle, Pointer<Utf8>);

final zipEntryOpen = zipLib.lookupFunction<ZipEntryOpenNative, ZipEntryOpen>('zip_entry_open');

// extern ZIP_EXPORT int zip_entry_close(struct zip_t *zip);
typedef ZipEntryCloseNative = Int32 Function(ZipHandle);
typedef ZipEntryClose = int Function(ZipHandle);

final zipEntryClose = zipLib.lookupFunction<ZipEntryCloseNative, ZipEntryClose>('zip_entry_close');

// extern ZIP_EXPORT const char *zip_entry_name(struct zip_t *zip);
typedef ZipEntryNameNative = CharPointer Function(ZipHandle);
typedef ZipEntryName = CharPointer Function(ZipHandle);

final zipEntryName = zipLib.lookupFunction<ZipEntryNameNative, ZipEntryName>('zip_entry_name');

// extern ZIP_EXPORT unsigned long long zip_entry_size(struct zip_t *zip);
typedef ZipEntrySizeNative = Int64 Function(ZipHandle);
typedef ZipEntrySize = int Function(ZipHandle);

final zipEntrySize = zipLib.lookupFunction<ZipEntrySizeNative, ZipEntrySize>('zip_entry_size');

// extern ZIP_EXPORT int zip_entry_isdir(struct zip_t *zip);
typedef ZipEntryIsDirNative = Int32 Function(ZipHandle);
typedef ZipEntryIsDir = int Function(ZipHandle);

final zipEntryIsDir = zipLib.lookupFunction<ZipEntryIsDirNative, ZipEntryIsDir>('zip_entry_isdir');

// extern ZIP_EXPORT unsigned int zip_entry_crc32(struct zip_t *zip);
typedef ZipEntryCrc32Native = Int32 Function(ZipHandle);
typedef ZipEntryCrc32 = int Function(ZipHandle);

final zipEntryCrc32 = zipLib.lookupFunction<ZipEntryCrc32Native, ZipEntryCrc32>('zip_entry_crc32');

// extern ZIP_EXPORT int zip_entry_fread(struct zip_t *zip, const char *filename);
typedef ZipEntryFReadNative = Int32 Function(ZipHandle, CharPointer);
typedef ZipEntryFRead = int Function(ZipHandle, CharPointer);

final zipEntryFRead = zipLib.lookupFunction<ZipEntryFReadNative, ZipEntryFRead>('zip_entry_fread');

// extern ZIP_EXPORT ssize_t zip_entry_read(struct zip_t *zip, void **buf, size_t *bufsize);
typedef ZipEntryReadNative = IntPtr Function(ZipHandle, Pointer<DataPointer>, Pointer<IntPtr>);
typedef ZipEntryRead = int Function(ZipHandle, Pointer<DataPointer>, Pointer<IntPtr>);

final zipEntryRead = zipLib.lookupFunction<ZipEntryReadNative, ZipEntryRead>('zip_entry_read');

// extern ZIP_EXPORT ssize_t zip_entry_noallocread(struct zip_t *zip, void *buf, size_t bufsize);
typedef ZipEntryNoAllocReadNative = IntPtr Function(ZipHandle, DataPointer, IntPtr);
typedef ZipEntryNoAllocRead = int Function(ZipHandle, DataPointer, int);

final zipEntryNoAllocRead = zipLib.lookupFunction<ZipEntryNoAllocReadNative, ZipEntryNoAllocRead>('zip_entry_noallocread');

// extern ZIP_EXPORT int zip_entry_fwrite(struct zip_t *zip, const char *filename);
typedef ZipEntryFWriteNative = Int32 Function(ZipHandle, CharPointer);
typedef ZipEntryFWrite = int Function(ZipHandle, CharPointer);

final zipEntryFWrite = zipLib.lookupFunction<ZipEntryFWriteNative, ZipEntryFWrite>('zip_entry_fwrite');

// extern ZIP_EXPORT int zip_entry_write(struct zip_t *zip, const void *buf, size_t bufsize);
typedef ZipEntryWriteNative = Int32 Function(ZipHandle, DataPointer, Int32);
typedef ZipEntryWrite = int Function(ZipHandle, DataPointer, int);

final zipEntryWrite = zipLib.lookupFunction<ZipEntryWriteNative, ZipEntryWrite>('zip_entry_write');

// extern ZIP_EXPORT int zip_extract(const char *zipname, const char *dir,
//     int (*on_extract_entry)(const char *filename, void *arg), void *arg);
typedef ZipExtractCallbackNative = Int32 Function(CharPointer, DataPointer);
typedef ZipExtractNative = Int32 Function(CharPointer, CharPointer, Pointer<NativeFunction<ZipExtractCallbackNative>>, DataPointer);
typedef ZipExtract = int Function(CharPointer, CharPointer, Pointer<NativeFunction<ZipExtractCallbackNative>>, DataPointer);

final zipExtract = zipLib.lookupFunction<ZipExtractNative, ZipExtract>('zip_extract');
