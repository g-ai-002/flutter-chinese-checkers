import 'dart:io';

import 'file_system_service.dart';
import 'log_service.dart';

/// IO 平台：日志按天写入用户目录。
Future<void> initLogging() async {
  await LogService.init(
    logRoot: () async =>
        Directory(await FileSystemService.instance.getLogRootPath()),
  );
}
