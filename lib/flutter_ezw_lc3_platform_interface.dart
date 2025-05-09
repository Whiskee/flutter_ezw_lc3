import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_ezw_lc3_method_channel.dart';

abstract class FlutterEzwLc3Platform extends PlatformInterface {
  /// Constructs a FlutterEzwLc3Platform.
  FlutterEzwLc3Platform() : super(token: _token);

  static final Object _token = Object();

  static FlutterEzwLc3Platform _instance = MethodChannelFlutterEzwLc3();

  /// The default instance of [FlutterEzwLc3Platform] to use.
  ///
  /// Defaults to [MethodChannelFlutterEzwLc3].
  static FlutterEzwLc3Platform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterEzwLc3Platform] when
  /// they register themselves.
  static set instance(FlutterEzwLc3Platform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
