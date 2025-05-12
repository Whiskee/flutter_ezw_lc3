import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_ezw_lc3/lc3_ffi.dart';

// -------------------- Load Dynamic Library --------------------

final DynamicLibrary _lib = Platform.isAndroid
    ? DynamicLibrary.open("liblc3.so")
    : DynamicLibrary.process(); // iOS 使用静态链接

final Lc3Bindings _lc3 = Lc3Bindings(_lib);

// -------------------- Enum Constants --------------------

class Lc3PcmFormat {
  static const int s16 = 0;
  static const int s24 = 1;
  static const int s24_3le = 2;
  static const int floatFmt = 3; // 避免与 Dart 内置 float 冲突
}

// -------------------- LC3 Encoder Wrapper --------------------

class Lc3Encoder {
  final bool hrMode;
  final int dtUs;
  final int srHz;
  final int srPcmHz;

  late final Pointer<Uint8> _mem;
  late final Pointer<Void> _memVoid;
  late final Pointer<lc3_encoder> _encoder;

  bool _initialized = false;

  Lc3Encoder({
    this.hrMode = false,
    required this.dtUs,
    required this.srHz,
    this.srPcmHz = 0,
  }) {
    _initialize();
  }

  void _initialize() {
    final size = hrMode
        ? _lc3.lc3_hr_encoder_size(hrMode, dtUs, srHz)
        : _lc3.lc3_encoder_size(dtUs, srHz);

    if (size <= 0) {
      throw Exception('Invalid encoder size');
    }

    _mem = malloc.allocate<Uint8>(size);
    _memVoid = _mem.cast<Void>();

    _encoder = hrMode
        ? _lc3.lc3_hr_setup_encoder(hrMode, dtUs, srHz, srPcmHz, _memVoid)
        : _lc3.lc3_setup_encoder(dtUs, srHz, srPcmHz, _memVoid);

    if (_encoder == nullptr) {
      malloc.free(_mem);
      throw Exception('Failed to initialize LC3 encoder');
    }

    _initialized = true;
  }

  void disableLtpf() {
    if (_initialized) {
      _lc3.lc3_encoder_disable_ltpf(_encoder);
    }
  }

  /// 编码一帧 PCM 数据为 LC3 比特流
  int encode({
    required Pointer<Void> pcm,
    required int stride,
    required int nBytes,
    required Pointer<Uint8> out,
    required lc3_pcm_format pcmFormat,
  }) {
    if (!_initialized) {
      throw StateError('Encoder not initialized');
    }

    return _lc3.lc3_encode(
        _encoder, pcmFormat, pcm, stride, nBytes, out.cast<Void>());
  }

  int frameSamples() => hrMode
      ? _lc3.lc3_hr_frame_samples(hrMode, dtUs, srHz)
      : _lc3.lc3_frame_samples(dtUs, srHz);

  void dispose() {
    if (_initialized) {
      malloc.free(_mem);
      _initialized = false;
    }
  }
}

// -------------------- LC3 Decoder Wrapper --------------------

class Lc3Decoder {
  final bool hrMode;
  final int dtUs;
  final int srHz;
  final int srPcmHz;

  late final Pointer<Uint8> _mem;
  late final Pointer<Void> _memVoid;
  late final Pointer<lc3_decoder> _decoder;

  bool _initialized = false;

  Lc3Decoder({
    this.hrMode = false,
    required this.dtUs,
    required this.srHz,
    this.srPcmHz = 0,
  }) {
    _initialize();
  }

  void _initialize() {
    final size = hrMode
        ? _lc3.lc3_hr_decoder_size(hrMode, dtUs, srHz)
        : _lc3.lc3_decoder_size(dtUs, srHz);

    if (size <= 0) {
      throw Exception('Invalid decoder size');
    }

    _mem = malloc.allocate<Uint8>(size);
    _memVoid = _mem.cast<Void>();

    _decoder = hrMode
        ? _lc3.lc3_hr_setup_decoder(hrMode, dtUs, srHz, srPcmHz, _memVoid)
        : _lc3.lc3_setup_decoder(dtUs, srHz, srPcmHz, _memVoid);

    if (_decoder == nullptr) {
      malloc.free(_mem);
      throw Exception('Failed to initialize LC3 decoder');
    }

    _initialized = true;
  }

  /// 解码一个 LC3 帧
  int decode({
    required Uint8List input,
    required Pointer<Void> pcmOut,
    required lc3_pcm_format pcmFormat,
    int stride = 1,
  }) {
    if (!_initialized) {
      throw StateError('Decoder not initialized');
    }

    final inputPtr = malloc.allocate<Uint8>(input.length);
    final inputBytes = inputPtr.asTypedList(input.length);
    inputBytes.setAll(0, input);

    final result = _lc3.lc3_decode(
      _decoder,
      inputPtr.cast<Void>(),
      input.length,
      pcmFormat,
      pcmOut,
      stride,
    );

    malloc.free(inputPtr);
    return result;
  }

  /// 执行 PLC（Packet Loss Concealment）
  int conceal({
    required Pointer<Void> pcmOut,
    required lc3_pcm_format pcmFormat,
    int stride = 1,
  }) {
    if (!_initialized) {
      throw StateError('Decoder not initialized');
    }

    return _lc3.lc3_decode(
      _decoder,
      nullptr,
      0,
      pcmFormat,
      pcmOut,
      stride,
    );
  }

  int frameSamples() => hrMode
      ? _lc3.lc3_hr_frame_samples(hrMode, dtUs, srHz)
      : _lc3.lc3_frame_samples(dtUs, srHz);

  void dispose() {
    if (_initialized) {
      malloc.free(_mem);
      _initialized = false;
    }
  }
}
