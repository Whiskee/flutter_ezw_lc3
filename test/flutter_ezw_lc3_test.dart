import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ezw_lc3/flutter_ezw_lc3.dart';
import 'package:flutter_ezw_lc3/flutter_ezw_lc3_platform_interface.dart';
import 'package:flutter_ezw_lc3/flutter_ezw_lc3_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterEzwLc3Platform
    with MockPlatformInterfaceMixin
    implements FlutterEzwLc3Platform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterEzwLc3Platform initialPlatform = FlutterEzwLc3Platform.instance;

  test('$MethodChannelFlutterEzwLc3 is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterEzwLc3>());
  });

  test('getPlatformVersion', () async {
    FlutterEzwLc3 flutterEzwLc3Plugin = FlutterEzwLc3();
    MockFlutterEzwLc3Platform fakePlatform = MockFlutterEzwLc3Platform();
    FlutterEzwLc3Platform.instance = fakePlatform;

    expect(await flutterEzwLc3Plugin.getPlatformVersion(), '42');
  });
}
