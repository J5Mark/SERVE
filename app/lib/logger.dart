import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static File? _logFile;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/app_logs.txt');
      // Write startup log
      await _write('App started at ${DateTime.now()}');
      _initialized = true;
    } catch (e) {
      print('Failed to initialize logger: $e');
    }
  }

  static Future<void> log(String message) async {
    print(message); // still print to console
    await _write(message);
  }

  static Future<void> _write(String message) async {
    try {
      if (_logFile == null) await init();
      if (_logFile != null) {
        await _logFile!.writeAsString(
          '${DateTime.now().toIso8601String()} - $message\n',
          mode: FileMode.append,
        );
      }
    } catch (e) {
      print('Failed to write log: $e');
    }
  }

  static Future<String> getLogs() async {
    try {
      if (_logFile == null) await init();
      if (_logFile != null && await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
    } catch (e) {
      print('Failed to read logs: $e');
    }
    return 'No logs available';
  }

  static Future<void> clearLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.delete();
      }
    } catch (e) {
      print('Failed to clear logs: $e');
    }
  }
}
