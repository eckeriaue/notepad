import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

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
    await prefs.setBool('isDark', newMode == ThemeMode.dark);
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

  // Проверяем и запрашиваем разрешения для Android
  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true; // На macOS и Windows разрешения не нужны

    try {
      // Для Android < 10 (API 29) запрашиваем Permission.storage
      if (await Permission.storage.isDenied) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Разрешение на доступ к хранилищу отклонено'),
              action: SnackBarAction(
                label: 'Открыть настройки',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          return false;
        }
      }

      // Для Android 11+ (API 30+), если нужен полный доступ
      if (await Permission.manageExternalStorage.isDenied) {
        var status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Разрешение на управление хранилищем отклонено'),
              action: SnackBarAction(
                label: 'Открыть настройки',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          return false;
        }
      }

      // Для Android 13+ (API 33+), если работаем с медиафайлами
      if (await Permission.storage.isDenied == false) {
        var mediaStatus = await Permission.storage.request();
        if (!mediaStatus.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Разрешение на доступ к медиа отклонено'),
              action: SnackBarAction(
                label: 'Открыть настройки',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          return false;
        }
      }
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при запросе разрешений: $e')),
      );
      return false;
    }
  }

  // Альтернативный метод сохранения в папку приложения (без разрешений)
  Future<void> _saveFileToAppDir() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/new_note.txt');
      await file.writeAsString(_controller.value.text);
      setState(() {
        _currentFilePath = file.path;
        _appTitle = 'Notepad - ${file.uri.pathSegments.last}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Файл сохранен в ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при сохранении в папку приложения: $e')),
      );
    }
  }

  Future<void> _openFile() async {
    try {
      if (!await _requestStoragePermission()) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл успешно открыт')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при открытии файла: $e')),
      );
    }
  }

  Future<void> _saveFile() async {
    try {
      if (!await _requestStoragePermission()) {
        // Если разрешения не получены, сохраняем в папку приложения
        await _saveFileToAppDir();
        return;
      }

      if (_currentFilePath != null) {
        final file = File(_currentFilePath!);
        await file.writeAsString(_controller.value.text);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл успешно сохранен')),
        );
      } else {
        String? savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Сохранить как',
          fileName: 'new_note.txt',
          type: FileType.custom,
          allowedExtensions: ['txt'],
          lockParentWindow: true,
        );

        if (savePath != null) {
          if (Platform.isAndroid && !savePath.endsWith('.txt')) {
            savePath = '$savePath.txt';
          }

          final file = File(savePath);
          await file.writeAsString(_controller.value.text);
          setState(() {
            _currentFilePath = savePath;
            _appTitle = 'Notepad - ${file.uri.pathSegments.last}';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Файл успешно сохранен')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сохранение отменено')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при сохранении файла: $e')),
      );
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
