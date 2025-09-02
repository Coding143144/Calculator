import 'dart:io';
import 'dart:convert';
import 'package:calculator/home.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

class FileManagerScreen extends StatefulWidget {
  final List<LineData> lines;

  const FileManagerScreen({super.key, required this.lines});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  List<FileSystemEntity> _savedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadFileList();
  }

  Future<Directory> _getSaveDir() async {
    return await getApplicationDocumentsDirectory();
  }

  Future<void> _loadFileList() async {
    final dir = await _getSaveDir();
    final files = dir
        .listSync()
        .where((file) => file.path.endsWith('.calcnote'))
        .toList();

    setState(() {
      _savedFiles = files;
    });
  }

  Future<void> _saveToFile() async {
    try {
      final dir = await _getSaveDir();

      final content = jsonEncode({
        'lines': widget.lines.map((line) => {
              'expression': line.controller.text,
              'result': line.result,
              'error': line.error,
            }).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      });

      final file = File(
        '${dir.path}/calculation_${DateTime.now().millisecondsSinceEpoch}.calcnote',
      );

      await file.writeAsString(content);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File saved successfully')),
      );

      _loadFileList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save file: $e')),
      );
    }
  }

  Future<void> _loadFromFilePicker() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['calcnote'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      await _openFile(file);
    }
  }

  Future<void> _openFile(File file) async {
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content);
      Navigator.pop(context, data);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load file: $e')),
      );
    }
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    try {
      await file.delete();
      _loadFileList();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete file: $e')),
      );
    }
  }

  Widget _buildFileTile(FileSystemEntity file) {
    final name = file.path.split('/').last;
    return Dismissible(
      key: Key(name),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteFile(file),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file),
        title: Text(name),
        subtitle: Text('Saved at: ${File(file.path).lastModifiedSync()}'),
        onTap: () => _openFile(File(file.path)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('File Manager')),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.save),
            title: const Text('Save Current Calculation'),
            onTap: _saveToFile,
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Load Calculation from Picker'),
            onTap: _loadFromFilePicker,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Saved Files',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _savedFiles.isEmpty
                ? const Center(child: Text('No saved files found'))
                : ListView(
                    children: _savedFiles.map(_buildFileTile).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
