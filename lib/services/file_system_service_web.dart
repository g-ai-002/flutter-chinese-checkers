/// Web 平台文件系统服务：浏览器没有可写的本地目录。
class FileSystemService {
  FileSystemService._();

  static final FileSystemService instance = FileSystemService._();

  Future<String> getLogRootPath() async => '';

  Future<bool> openDirectory(String path) async => false;
}
