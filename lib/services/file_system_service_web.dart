/// Web 平台文件系统服务：浏览器没有可写的本地目录。
class FileSystemService {
  FileSystemService._();

  static final FileSystemService instance = FileSystemService._();

  Future<String> getLogRootPath() async => '';

  /// 浏览器没有可写目录，导出统一走剪贴板。
  Future<String?> saveExport(String fileName, String content) async => null;

  Future<bool> openDirectory(String path) async => false;
}
