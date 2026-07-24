# document_file_save_plus
Save bytes data into Download folder (Android), or show save dialog (iOS). You can save any file types (Ex. .txt, .png, .jpg, .pdf, etc)

## Install plugin
add this line into pubspec.yaml
```
document_file_save_plus: ^1.0.4
```

## Permission
### Android
if your project set android target >= Android Q, you don't have to add any permission.
Otherwise, Add the following statement in `AndroidManifest.xml`:
```
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### iOS
No permission needed.

## Function description
```
// call function 'saveFile' if you 1 file to save.
void saveFile(Uint8List data, String fileName, String mimeType)

// call function 'saveMultipleFiles' if you have mutiple files to save. iOS will show save dialog only once
void saveMultipleFiles(List<Uint8List> dataList, List<String> fileNameList, List<String> mimeTypeList)
```

## Example usage
```
import 'package:document_file_save_plus/document_file_save_plus.dart';

//Save multiple files
List<int> textBytes = utf8.encode("Some data");
List<int> textBytes2 = utf8.encode("Another data");
DocumentFileSave.saveMultipleFiles([textBytes, textBytes2], ["text1.txt", "text2.txt"], ["text/plain", "text/plain"]);

//Save single text file
DocumentFileSave.saveFile(textBytes, "my_sample_file.txt", "text/plain");

//Save single pdf file
DocumentFileSave.saveFile(pdfBytes, "my_sample_file.pdf", "appliation/pdf");

//Save single image file
DocumentFileSave.saveFile(imageJPGBytes, "my_sample_file.jpg", "image/jpeg");
```



