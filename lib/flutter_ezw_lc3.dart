
import 'flutter_ezw_lc3_platform_interface.dart';

class FlutterEzwLc3 {
  Future<String?> getPlatformVersion() {
    return FlutterEzwLc3Platform.instance.getPlatformVersion();
  }
}
