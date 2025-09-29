import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final newMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setState(() {
      _themeMode = newMode;
    });
    prefs.setBool('isDark', newMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notepad',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: const NotepadScreen(),
    );
  }
}

class NotepadScreen extends StatefulWidget {
  const NotepadScreen({super.key});

  @override
  State<NotepadScreen> createState() => _NotepadScreenState();
}

class _NotepadScreenState extends State<NotepadScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _currentFilePath;
  String _appTitle = 'Notepad';

  Future<void> _openFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      setState(() {
        _controller.text = content;
        _currentFilePath = result.files.single.path;
        _appTitle = 'Notepad - ${result.files.single.name}';
      });
    }
  }

  Future<void> _saveFile() async {
    if (_currentFilePath != null) {
      // Сохраняем в существующий файл
      final file = File(_currentFilePath!);
      await file.writeAsString(_controller.value.text);
    } else {
      // Сохраняем как новый файл
      final directory = await getApplicationDocumentsDirectory();
      final defaultPath = '${directory.path}/new_note.txt';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить как',
        fileName: 'new_note.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (savePath != null) {
        final file = File(savePath);
        await file.writeAsString(_controller.value.text);
        setState(() {
          _currentFilePath = savePath;
          _appTitle = 'Notepad - ${file.uri.pathSegments.last}';
        });
      }
    }
  }

  void _newFile() {
    setState(() {
      _controller.clear();
      _currentFilePath = null;
      _appTitle = 'Notepad';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: _newFile,
            tooltip: 'Новый файл',
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _openFile,
            tooltip: 'Открыть файл',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveFile,
            tooltip: 'Сохранить',
          ),
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.light
                ? Icons.dark_mode
                : Icons.light_mode),
            onPressed: () {
              final myAppState = context.findAncestorStateOfType<_MyAppState>()!;
              myAppState._toggleTheme();
            },
            tooltip: 'Сменить тему',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: 'Введите текст...',
            hintStyle: TextStyle(color: Colors.grey),
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}
