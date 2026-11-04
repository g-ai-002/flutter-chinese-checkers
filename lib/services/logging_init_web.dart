import 'log_service.dart';

/// Web 平台：日志只保留在内存，设置页仍可查看。
Future<void> initLogging() => LogService.init();
