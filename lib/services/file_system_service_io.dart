import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log_service.dart';

/// 文件系统服务：定位用户目录下的日志目录，并调用系统文件管理器。
class FileSystemService {
  FileSystemService._();

  static final FileSystemService instance = FileSystemService._();

  Directory? _logRoot;

  Future<Directory> _baseDir() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      return external ?? await getApplicationDocumentsDirectory();
    }
    return getApplicationDocumentsDirectory();
  }

  /// 日志根目录：`<用户目录>/FlutterTiaoqi/logs`。
  Future<Directory> getLogRoot() async {
    if (_logRoot != null) return _logRoot!;
    final base = await _baseDir();
    final separator = Platform.pathSeparator;
    final logDir = Directory(
      '${base.path}${separator}FlutterTiaoqi${separator}logs',
    );
    if (!await logDir.exists()) await logDir.create(recursive: true);
    _logRoot = logDir;
    return logDir;
  }

  Future<String> getLogRootPath() async => (await getLogRoot()).path;

  /// 把棋谱写入用户目录下的 `FlutterTiaoqi/replays`，成功返回文件路径。
  Future<String?> saveExport(String fileName, String content) async {
    try {
      final base = await _baseDir();
      final separator = Platform.pathSeparator;
      final dir = Directory(
        '${base.path}${separator}FlutterTiaoqi${separator}replays',
      );
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}$separator$fileName');
      await file.writeAsString(content);
      return file.path;
    } catch (e, stack) {
      LogService.error('保存导出文件失败: $fileName', e, stack);
      return null;
    }
  }

  Future<bool> openDirectory(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
        return true;
      }
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
        return true;
      }
      if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
        return true;
      }
    } catch (e, stack) {
      LogService.error('打开目录失败: $path', e, stack);
    }
    return false;
  }
}
