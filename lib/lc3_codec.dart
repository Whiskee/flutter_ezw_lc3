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
    // 1. 初始化编码参数
    // 1.1 计算编码器内存需求
    final encodeSize = _lc3.lc3_encoder_size(dtUs, srHz);
    // 1.2 获取每帧采样数
    final samplesPerFrame = _lc3.lc3_frame_samples(dtUs, srHz);

    // 2. 参数验证
    // 2.1 校验帧字节数范围（16kbps-320kbps）
    if (frameBytes < _lc3.lc3_hr_frame_bytes(false, dtUs, srHz, 16000) ||
        frameBytes > _lc3.lc3_hr_frame_bytes(false, dtUs, srHz, 320000)) {
      log("Lc3Codec::Encode - Invalid frameBytes: $frameBytes");
      return null;
    }
    // 3. 内存分配
    // 3.1 编码器实例内存
    final encMem = calloc<Uint8>(encodeSize);
    // 3.2 初始化编码器实例
    final lc3Encoder =
        _lc3.lc3_setup_encoder(dtUs, srHz, 0, encMem.cast<Void>());
    // Allocate encode buffers
    final inBuf = calloc<Int16>(samplesPerFrame);
    final outBuf = calloc<Uint8>(frameBytes);
    // Prepare output buffer
    final encodedData =
        Uint8List(pcmBytes.length ~/ (samplesPerFrame * 2) * frameBytes);
    var encodedOffset = 0;
    var pcmOffset = 0;
    while (pcmOffset < pcmBytes.length) {
      // 4. 帧数据处理
      // 4.1 检查剩余采样是否足够组成完整帧
      final remainingSamples = (pcmBytes.length - pcmOffset) ~/ 2;
      if (remainingSamples < samplesPerFrame) {
        log("Lc3Codec::Encode - Incomplete PCM frame (${remainingSamples}samples)");
        break;
      }
      // Load PCM samples to input buffer
      final pcmChunk =
          pcmBytes.buffer.asInt16List(pcmOffset ~/ 2, samplesPerFrame);
      inBuf.asTypedList(samplesPerFrame).setAll(0, pcmChunk);
      // Perform LC3 encoding
      // 5. 执行编码
      // 5.1 调用LC3原生编码接口
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

/// 使用 LC3 FFI 直接解码 LC3 音频数据为 PCM 数据
///
/// 参数:
/// - streamBytes: LC3 编码的音频数据（流式数据）
/// - dtUs: 帧长度，单位为微秒，默认10000（10ms）
/// - srHz: 采样率，默认16000（16kHz）
/// - outputByteCount: 每帧编码后的字节数，默认20
///
/// 返回:
/// - 解码后的 PCM 数据，如果解码失败则返回 null
Future<Uint8List?> decodeLc3({
  required Uint8List streamBytes,
  int dtUs = 10000,
  int srHz = 16000,
  int outputByteCount = 20,
}) async {
  try {
    // 计算解码器大小和每帧采样数
    final decodeSize = _lc3.lc3_decoder_size(dtUs, srHz);
    final sampleOfFrames = _lc3.lc3_frame_samples(dtUs, srHz);
    final bytesOfFrames = sampleOfFrames * 2; // 16位采样，每个采样2字节
    // 分配解码器内存
    final decMem = calloc<Uint8>(decodeSize);
    final lc3Decoder =
        _lc3.lc3_setup_decoder(dtUs, srHz, 0, decMem.cast<Void>());
    // 分配输出缓冲区
    final outBuf = calloc<Uint8>(bytesOfFrames);
    // 计算总字节数和已读取字节数
    final totalBytes = streamBytes.length;
    var bytesRead = 0;
    // 创建输出数据
    final pcmData = Uint8List(totalBytes * bytesOfFrames ~/ outputByteCount);
    var pcmOffset = 0;
    // 逐帧解码
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
      // 解码当前帧
      final result = _lc3.lc3_decode(
        lc3Decoder,
        inBuf.cast<Void>(),
        bytesToRead,
        lc3_pcm_format.LC3_PCM_FORMAT_S16,
        outBuf.cast<Void>(),
        1, // stride
      );
      if (result < 0) {
        log("Lc3Codec::Decode - Error:FFI decoding failed: $result");
        calloc.free(inBuf);
        calloc.free(outBuf);
        calloc.free(decMem);
        return null;
      }
      // 将解码后的数据复制到输出缓冲区
      final decodedFrame = outBuf.asTypedList(bytesOfFrames);
      pcmData.setRange(pcmOffset, pcmOffset + bytesOfFrames, decodedFrame);
      // 释放输入缓冲区
      calloc.free(inBuf);
      // 更新偏移量
      bytesRead += bytesToRead;
      pcmOffset += bytesOfFrames;
    }
    // 释放资源
    calloc.free(outBuf);
    calloc.free(decMem);
    // 返回解码后的 PCM 数据（裁剪到实际大小）
    return pcmData.sublist(0, pcmOffset);
  } catch (e) {
    log("Lc3Codec::Decode - Error: $e");
    return null;
  }
}
