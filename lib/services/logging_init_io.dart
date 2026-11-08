import 'dart:io';

import 'file_system_service.dart';
import 'log_service.dart';

Future<void> initLogging() async {
  await LogService.init(
    logRoot: () async => Directory(await FileSystemService.instance.getLogRootPath()),
  );
}
