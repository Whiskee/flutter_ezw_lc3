import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_ezw_lc3_platform_interface.dart';

/// An implementation of [FlutterEzwLc3Platform] that uses method channels.
class MethodChannelFlutterEzwLc3 extends FlutterEzwLc3Platform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_ezw_lc3');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
