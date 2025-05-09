import 'dart:async';
import 'dart:developer';
import 'dart:ffi';

// ignore: depend_on_referenced_packages
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ezw_lc3/flutter_ezw_lc3.dart';
import 'package:flutter_ezw_lc3/lc3_codec.dart';
import 'package:flutter_ezw_lc3/lc3_ffi.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _flutterEzwLc3Plugin = FlutterEzwLc3();

  @override
  void initState() {
    super.initState();
    initPlatformState();
    // 测试LC3编码解码
    exampleEncodeDecode();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await _flutterEzwLc3Plugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text('Running on: $_platformVersion\n'),
        ),
      ),
    );
  }

  void exampleEncodeDecode() {
    final encoder = Lc3Encoder(dtUs: 10000, srHz: 48000);
    final decoder = Lc3Decoder(dtUs: 10000, srHz: 48000);

    const numSamples = 480; // for 10ms at 48kHz
    final pcmIn = malloc<Int16>(numSamples);
    final encoded = malloc<Uint8>(100); // 100 bytes frame
    final pcmOut = malloc<Int16>(numSamples);

    // 编码
    final encodeResult = encoder.encode(
      pcm: pcmIn.cast<Void>(),
      stride: 1,
      nBytes: 100,
      out: encoded,
      pcmFormat: lc3_pcm_format.LC3_PCM_FORMAT_S16,
    );

    // 解码
    final decodeResult = decoder.decode(
      input: encoded.asTypedList(100),
      pcmOut: pcmOut.cast<Void>(),
      pcmFormat: lc3_pcm_format.LC3_PCM_FORMAT_S16,
    );

    log('==============:encodeResult=$encodeResult, decodeResult=$decodeResult');

    malloc.free(pcmIn);
    malloc.free(pcmOut);
    malloc.free(encoded);

    encoder.dispose();
    decoder.dispose();
  }
}
