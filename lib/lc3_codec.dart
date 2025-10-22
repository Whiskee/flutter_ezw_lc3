import 'dart:developer';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_ezw_lc3/lc3_ffi.dart';

// -------------------- Load Dynamic Library --------------------

final DynamicLibrary _lib = Platform.isAndroid
    ? DynamicLibrary.open("liblc3.so")
    : DynamicLibrary.process(); // iOS 使用静态链接

final Lc3Bindings _lc3 = Lc3Bindings(_lib);

// -------------------- Global LC3 Decoder Manager --------------------

/// LC3解码器配置参数
class Lc3DecoderConfig {
  final int dtUs;
  final int srHz;

  const Lc3DecoderConfig(this.dtUs, this.srHz);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Lc3DecoderConfig &&
        other.dtUs == dtUs &&
        other.srHz == srHz;
  }

  @override
  int get hashCode => dtUs.hashCode ^ srHz.hashCode;

  @override
  String toString() => 'Lc3DecoderConfig(dtUs: $dtUs, srHz: $srHz)';
}

/// LC3解码器实例包装器
class Lc3DecoderInstance {
  final lc3_decoder_t decoder;
  final Pointer<Uint8> decoderMemory;
  final Pointer<Uint8> outputBuffer;
  final Lc3DecoderConfig config;
  final int samplesPerFrame;
  final int bytesPerFrame;
  DateTime lastUsed;

  Lc3DecoderInstance({
    required this.decoder,
    required this.decoderMemory,
    required this.outputBuffer,
    required this.config,
    required this.samplesPerFrame,
    required this.bytesPerFrame,
  }) : lastUsed = DateTime.now();

  void updateLastUsed() {
    lastUsed = DateTime.now();
  }

  void dispose() {
    calloc.free(outputBuffer);
    calloc.free(decoderMemory);
  }
}

/// 全局LC3解码器管理器
class Lc3DecoderManager {
  static final Lc3DecoderManager _instance = Lc3DecoderManager._internal();
  factory Lc3DecoderManager() => _instance;
  Lc3DecoderManager._internal();

  final Map<Lc3DecoderConfig, Lc3DecoderInstance> _decoders = {};
  static const int _maxDecoders = 5; // 最大缓存解码器数量
  static const Duration _decoderTimeout = Duration(minutes: 5); // 解码器超时时间

  /// 获取或创建解码器实例
  Lc3DecoderInstance? getDecoder(Lc3DecoderConfig config) {
    // 如果已存在相同配置的解码器，直接返回
    if (_decoders.containsKey(config)) {
      final decoder = _decoders[config]!;
      decoder.updateLastUsed();
      return decoder;
    }
    // 如果解码器数量达到上限，清理最旧的解码器
    if (_decoders.length >= _maxDecoders) {
      _cleanupOldestDecoder();
    }
    // 创建新的解码器实例
    try {
      final decodeSize = _lc3.lc3_decoder_size(config.dtUs, config.srHz);
      final samplesPerFrame = _lc3.lc3_frame_samples(config.dtUs, config.srHz);
      final bytesPerFrame = samplesPerFrame * 2; // 16位采样，每个采样2字节
      final decoderMemory = calloc<Uint8>(decodeSize);
      final decoder = _lc3.lc3_setup_decoder(
          config.dtUs, config.srHz, 0, decoderMemory.cast<Void>());
      final outputBuffer = calloc<Uint8>(bytesPerFrame);
      final decoderInstance = Lc3DecoderInstance(
        decoder: decoder,
        decoderMemory: decoderMemory,
        outputBuffer: outputBuffer,
        config: config,
        samplesPerFrame: samplesPerFrame,
        bytesPerFrame: bytesPerFrame,
      );
      _decoders[config] = decoderInstance;
      log("Lc3DecoderManager - Created new decoder for config: $config");
      return decoderInstance;
    } catch (e) {
      log("Lc3DecoderManager - Failed to create decoder: $e");
      return null;
    }
  }

  /// 清理最旧的解码器
  void _cleanupOldestDecoder() {
    if (_decoders.isEmpty) return;

    Lc3DecoderConfig? oldestConfig;
    DateTime oldestTime = DateTime.now();

    for (final entry in _decoders.entries) {
      if (entry.value.lastUsed.isBefore(oldestTime)) {
        oldestTime = entry.value.lastUsed;
        oldestConfig = entry.key;
      }
    }

    if (oldestConfig != null) {
      final decoder = _decoders.remove(oldestConfig)!;
      decoder.dispose();
      log("Lc3DecoderManager - Cleaned up oldest decoder for config: $oldestConfig");
    }
  }

  /// 清理超时的解码器
  void cleanupTimeoutDecoders() {
    final now = DateTime.now();
    final timeoutConfigs = <Lc3DecoderConfig>[];

    for (final entry in _decoders.entries) {
      if (now.difference(entry.value.lastUsed) > _decoderTimeout) {
        timeoutConfigs.add(entry.key);
      }
    }

    for (final config in timeoutConfigs) {
      final decoder = _decoders.remove(config)!;
      decoder.dispose();
      log("Lc3DecoderManager - Cleaned up timeout decoder for config: $config");
    }
  }

  /// 清理所有解码器
  void disposeAll() {
    for (final decoder in _decoders.values) {
      decoder.dispose();
    }
    _decoders.clear();
    log("Lc3DecoderManager - Disposed all decoders");
  }

  /// 获取当前解码器数量
  int get decoderCount => _decoders.length;

  /// 获取所有配置信息
  List<Lc3DecoderConfig> get allConfigs => _decoders.keys.toList();
}

// 全局解码器管理器实例
final Lc3DecoderManager _decoderManager = Lc3DecoderManager();

// -------------------- LC3 Encoder Wrapper --------------------

/// Encodes PCM audio data to LC3 format using FFI
///
/// Parameters:
/// - pcmBytes: Raw PCM audio data (16-bit signed)
/// - dtUs: Frame duration in microseconds (default 10000 = 10ms)
/// - srHz: Sample rate in Hz (default 16000 = 16kHz)
/// - frameBytes: Target bytes per encoded frame (default 20)
///
/// Returns:
/// - Encoded LC3 byte stream, or null on failure
Future<Uint8List?> encodeLc3({
  required Uint8List pcmBytes,
  int dtUs = 10000,
  int srHz = 16000,
  int frameBytes = 20,
}) async {
  try {
    //  1. 初始化编码参数
    //  - 1.1 计算编码器内存需求
    final encodeSize = _lc3.lc3_encoder_size(dtUs, srHz);
    //  - 1.2 获取每帧采样数
    final samplesPerFrame = _lc3.lc3_frame_samples(dtUs, srHz);
    //  2. 参数验证
    //  - 2.1 校验帧字节数范围（16kbps-320kbps）
    if (frameBytes < _lc3.lc3_hr_frame_bytes(false, dtUs, srHz, 16000) ||
        frameBytes > _lc3.lc3_hr_frame_bytes(false, dtUs, srHz, 320000)) {
      log("Lc3Codec::Encode - Invalid frameBytes: $frameBytes");
      return null;
    }
    //  3. 内存分配
    //  - 3.1 编码器实例内存
    final encMem = calloc<Uint8>(encodeSize);
    //  - 3.2 初始化编码器实例
    final lc3Encoder =
        _lc3.lc3_setup_encoder(dtUs, srHz, 0, encMem.cast<Void>());
    //  Allocate encode buffers
    final inBuf = calloc<Int16>(samplesPerFrame);
    final outBuf = calloc<Uint8>(frameBytes);
    //  Prepare output buffer
    final encodedData =
        Uint8List(pcmBytes.length ~/ (samplesPerFrame * 2) * frameBytes);
    var encodedOffset = 0;
    var pcmOffset = 0;
    while (pcmOffset < pcmBytes.length) {
      //  4. 帧数据处理
      //  - 4.1 检查剩余采样是否足够组成完整帧
      final remainingSamples = (pcmBytes.length - pcmOffset) ~/ 2;
      if (remainingSamples < samplesPerFrame) {
        log("Lc3Codec::Encode - Incomplete PCM frame (${remainingSamples}samples)");
        break;
      }
      //  Load PCM samples to input buffer
      final pcmChunk =
          pcmBytes.buffer.asInt16List(pcmOffset ~/ 2, samplesPerFrame);
      inBuf.asTypedList(samplesPerFrame).setAll(0, pcmChunk);
      //  Perform LC3 encoding
      //  5. 执行编码
      //  - 5.1 调用LC3原生编码接口
      final result = _lc3.lc3_encode(
        lc3Encoder,
        lc3_pcm_format.LC3_PCM_FORMAT_S16,
        inBuf.cast<Void>(),
        1, // 采样步长
        frameBytes,
        outBuf.cast<Void>(),
      );
      if (result != 0) {
        log("Lc3Codec::Encode - Encoding failed with code: $result");
        calloc.free(inBuf);
        calloc.free(outBuf);
        calloc.free(encMem);
        return null;
      }
      // Store encoded frame
      encodedData.setRange(encodedOffset, encodedOffset + frameBytes,
          outBuf.asTypedList(frameBytes));
      encodedOffset += frameBytes;
      pcmOffset += samplesPerFrame * 2;
    }

    // Cleanup resources
    calloc.free(inBuf);
    calloc.free(outBuf);
    calloc.free(encMem);

    return encodedData.sublist(0, encodedOffset);
  } catch (e) {
    log("Lc3Codec::Encode - Error: $e");
    return null;
  }
}

// -------------------- LC3 Decoder Wrapper --------------------

/// 使用 LC3 FFI 直接解码 LC3 音频数据为 PCM 数据（优化版本）
///
/// 参数:
/// - streamBytes: LC3 编码的音频数据（流式数据）
/// - dtUs: 帧长度，单位为微秒，默认10000（10ms）
/// - srHz: 采样率，默认16000（16kHz）
/// - outputByteCount: 每帧编码后的字节数，默认20
/// - isLittleEndian: 是否是小端序，默认false
///
/// 返回:
/// - 解码后的 PCM 数据，如果解码失败则返回 null
Future<Uint8List?> decodeLc3({
  required Uint8List streamBytes,
  int dtUs = 10000,
  int srHz = 16000,
  int outputByteCount = 20,
  bool isLittleEndian = false,
}) async {
  try {
    // 1. 获取或创建解码器实例（使用全局管理器）
    final config = Lc3DecoderConfig(dtUs, srHz);
    final decoderInstance = _decoderManager.getDecoder(config);
    if (decoderInstance == null) {
      log("Lc3Codec::Decode - Failed to get decoder instance for config: $config");
      return null;
    }
    // 2. 计算总字节数和已读取字节数
    final totalBytes = streamBytes.length;
    var bytesRead = 0;
    // 3. 创建输出数据
    final pcmData = Uint8List(
        totalBytes * decoderInstance.bytesPerFrame ~/ outputByteCount);
    var pcmOffset = 0;
    // 4. 逐帧解码
    while (bytesRead < totalBytes) {
      // 计算当前帧要读取的字节数
      final bytesToRead = math.min(outputByteCount, totalBytes - bytesRead);

      // 获取当前帧数据
      final frameData = streamBytes.sublist(bytesRead, bytesRead + bytesToRead);

      // 为输入分配内存并复制数据
      final inBuf = calloc<Uint8>(bytesToRead);
      for (var i = 0; i < bytesToRead; i++) {
        inBuf[i] = frameData[i];
      }

      // 解码当前帧（使用缓存的解码器实例）
      final result = _lc3.lc3_decode(
        decoderInstance.decoder,
        inBuf.cast<Void>(),
        bytesToRead,
        lc3_pcm_format.LC3_PCM_FORMAT_S16,
        decoderInstance.outputBuffer.cast<Void>(),
        1, // stride
      );

      if (result < 0) {
        log("Lc3Codec::Decode - Error:FFI decoding failed: $result");
        calloc.free(inBuf);
        return null;
      }

      // 5. 获取解码数据
      final decodedFrame = decoderInstance.outputBuffer
          .asTypedList(decoderInstance.bytesPerFrame);

      // 6. 处理字节序转换
      if (isLittleEndian) {
        // 将字节数组转换为Int16List以便进行字节序转换
        final int16Data = Int16List.view(decodedFrame.buffer);
        final convertedData = Uint8List(decoderInstance.bytesPerFrame);

        // 手动交换字节序（小端序转大端序）
        for (var i = 0; i < int16Data.length; i++) {
          final value = int16Data[i];
          // 在小端序中，低位字节在前，高位字节在后
          // 所以直接使用原始字节顺序即可
          convertedData[i * 2] = value & 0xFF; // 低位字节
          convertedData[i * 2 + 1] = (value >> 8) & 0xFF; // 高位字节
        }

        // 将转换后的数据复制到输出缓冲区
        pcmData.setRange(pcmOffset, pcmOffset + decoderInstance.bytesPerFrame,
            convertedData);
      } else {
        // 直接复制数据
        pcmData.setRange(
            pcmOffset, pcmOffset + decoderInstance.bytesPerFrame, decodedFrame);
      }

      // 释放输入缓冲区
      calloc.free(inBuf);

      // 更新偏移量
      bytesRead += bytesToRead;
      pcmOffset += decoderInstance.bytesPerFrame;
    }

    // 7. 返回解码后的 PCM 数据（裁剪到实际大小）
    return pcmData.sublist(0, pcmOffset);
  } catch (e) {
    log("Lc3Codec::Decode - Error: $e");
    return null;
  }
}

// -------------------- Public Decoder Management Functions --------------------

/// 清理超时的解码器实例
/// 建议定期调用此方法以防止内存泄漏
void cleanupTimeoutDecoders() => _decoderManager.cleanupTimeoutDecoders();

/// 清理所有解码器实例
/// 在应用退出或不再需要LC3解码时调用
void disposeAllDecoders() => _decoderManager.disposeAll();

/// 获取当前活跃的解码器数量
int getActiveDecoderCount() => _decoderManager.decoderCount;

/// 获取所有活跃解码器的配置信息
List<Lc3DecoderConfig> getActiveDecoderConfigs() => _decoderManager.allConfigs;

/// 预创建指定配置的解码器实例
/// 可以在应用启动时调用，提前创建常用的解码器配置
bool preCreateDecoder({
  int dtUs = 10000,
  int srHz = 16000,
}) {
  final config = Lc3DecoderConfig(dtUs, srHz);
  final decoder = _decoderManager.getDecoder(config);
  return decoder != null;
}

// -------------------- Usage Examples --------------------

/*
使用示例：

1. 基本使用（推荐）：
```dart
// 解码LC3音频流
final pcmData = await decodeLc3(
  streamBytes: lc3AudioData,
  dtUs: 10000,  // 10ms帧长度
  srHz: 16000,  // 16kHz采样率
  outputByteCount: 20,
);
```

2. 预创建解码器（性能优化）：
```dart
// 在应用启动时预创建常用配置
preCreateDecoder(dtUs: 10000, srHz: 16000);
preCreateDecoder(dtUs: 10000, srHz: 48000);

// 后续解码调用会复用预创建的解码器
final pcmData = await decodeLc3(streamBytes: audioData);
```

3. 内存管理：
```dart
// 定期清理超时的解码器（建议每5分钟调用一次）
cleanupTimeoutDecoders();

// 获取当前活跃解码器数量
final count = getActiveDecoderCount();

// 应用退出时清理所有解码器
disposeAllDecoders();
```

4. 性能监控：
```dart
// 获取所有活跃解码器配置
final configs = getActiveDecoderConfigs();
for (final config in configs) {
  print('Active decoder: ${config.dtUs}μs, ${config.srHz}Hz');
}
```

优化效果：
- 消除了频繁创建/销毁解码器导致的音频噪音
- 支持多种参数配置的自动缓存和复用
- 自动内存管理，防止内存泄漏
- 显著提升连续音频流的解码性能
*/
