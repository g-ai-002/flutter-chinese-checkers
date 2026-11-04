/// 日志服务：按平台选择实现——IO 平台落盘，Web 平台仅保留内存日志。
library;

export 'log_service_io.dart'
    if (dart.library.js_interop) 'log_service_web.dart';
