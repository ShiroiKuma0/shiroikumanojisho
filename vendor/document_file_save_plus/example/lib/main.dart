import 'dart:typed_data';
import 'package:document_file_save_plus/document_file_save_plus.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    _saveFile();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('document_file_save_plus Plugin'),
        ),
        body: const Center(
          child: Text(
            'Please check file in Download folder (or Files App in iOS)',
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _saveFile,
          tooltip: 'Save File',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _saveFile() {
    List<int> htmlBytes =
        utf8.encode("<h1>Header 1</h1><p>This is sample text</p>");
    List<int> textBytes = utf8.encode("Some data");
    Uint8List htmlBytes1 = Uint8List.fromList(htmlBytes);
    Uint8List textBytes1 = Uint8List.fromList(textBytes);

    // save multiple files
    DocumentFileSavePlus().saveMultipleFiles(
      dataList: [htmlBytes1, textBytes1],
      fileNameList: ["htmlfile.html", "textfile.txt"],
      mimeTypeList: ["text/html", "text/plain"],
    );

    // save multiple files (case that file have same name). system will automatically append number to filename.
    //DocumentFileSave.saveMultipleFiles([htmlBytes, textBytes], ["file.txt", "file.txt"], ["text/html", "text/plain"]);

    // save single file
    // DocumentFileSave.saveFile(htmlBytes, "my test html file.html", "text/html");
  }
}
