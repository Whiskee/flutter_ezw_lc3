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

// -------------------- LC3 Decoder Wrapper --------------------

/// 使用 LC3 FFI 直接解码 LC3 音频数据为 PCM 数据
///
/// 参数:
/// - lc3Bytes: LC3 编码的音频数据
/// - dtUs: 帧长度，单位为微秒，默认10000（10ms）
/// - srHz: 采样率，默认16000（16kHz）
/// - outputByteCount: 每帧编码后的字节数，默认20
///
/// 返回:
/// - 解码后的 PCM 数据，如果解码失败则返回 null
Future<Uint8List?> decodeLc3({
  required Uint8List lc3Bytes,
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
    final totalBytes = lc3Bytes.length;
    var bytesRead = 0;
    // 创建输出数据
    final pcmData = Uint8List(totalBytes * bytesOfFrames ~/ outputByteCount);
    var pcmOffset = 0;
    // 逐帧解码
    while (bytesRead < totalBytes) {
      // 计算当前帧要读取的字节数
      final bytesToRead = math.min(outputByteCount, totalBytes - bytesRead);
      // 获取当前帧数据
      final frameData = lc3Bytes.sublist(bytesRead, bytesRead + bytesToRead);
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
