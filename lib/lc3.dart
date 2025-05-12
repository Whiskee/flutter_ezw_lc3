import 'dart:developer';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_ezw_lc3/lc3_codec.dart';
import 'package:flutter_ezw_lc3/lc3_ffi.dart';

class Lc3 {
  static final Lc3 to = Lc3._();

  Lc3._();

  /// Decodes an LC3 encoded audio stream represented by a hex string.
  ///
  /// Parameters:
  ///   [lc3HexStream]: The LC3 encoded data as a hexadecimal string.
  ///   [dtUs]: Frame duration in microseconds (e.g., 10000 for 10ms).
  ///   [srHz]: Sample rate in Hz (e.g., 16000 for 16kHz).
  ///   [encodedBytesPerFrame]: The size of each encoded LC3 frame in bytes.
  ///                           This is crucial for correctly segmenting the stream.
  ///
  /// Returns:
  ///   A [Future] that completes with an [Int16List] containing the decoded
  ///   16-bit PCM samples, or `null` if an error occurs.
  Future<Int16List?> decodeBytes({
    required Uint8List lc3Bytes,
    required int dtUs,
    required int srHz,
    required int encodedBytesPerFrame,
  }) async {
    if (encodedBytesPerFrame <= 0) {
      log('Lc3Decode::Error: encodedBytesPerFrame must be positive.');
      return null;
    }

    Lc3Decoder? decoder;
    Pointer<Int16>? pcmFramePtr; // For S16 output

    try {
      decoder = Lc3Decoder(
        dtUs: dtUs,
        srHz: srHz,
        hrMode:
            false, // Assuming not High-Resolution as per problem description
        srPcmHz: 0, // Use srHz for PCM output sample rate
      );

      final int samplesPerFrame = decoder.frameSamples();
      if (samplesPerFrame <= 0) {
        log('Lc3Decode::Error: Invalid samplesPerFrame calculated: $samplesPerFrame. Check dtUs and srHz.');
        decoder.dispose();
        return null;
      }

      // Allocate memory for one frame of PCM data (Int16 for S16 format)
      pcmFramePtr = malloc.allocate<Int16>(samplesPerFrame);
      final pcmOutVoidPtr = pcmFramePtr.cast<Void>();

      final List<int> allPcmSamples = [];
      int offset = 0;

      log('Lc3Decode::Starting LC3 decoding...');
      log('-- Total bytes from hex string: ${lc3Bytes.length}');
      log('-- Frame duration (dtUs): $dtUs, Sample rate (srHz): $srHz');
      log('-- Expected encoded bytes per frame: $encodedBytesPerFrame');
      log('-- Samples per decoded frame: $samplesPerFrame');

      while (offset + encodedBytesPerFrame <= lc3Bytes.length) {
        final currentEncodedFrame =
            lc3Bytes.sublist(offset, offset + encodedBytesPerFrame);

        final int decodeResult = decoder.decode(
          input: currentEncodedFrame,
          pcmOut: pcmOutVoidPtr,
          // Using LC3_PCM_FORMAT_S16 for 16-bit signed PCM output
          pcmFormat: lc3_pcm_format.LC3_PCM_FORMAT_S16,
        );

        if (decodeResult < 0) {
          log('Lc3Decode::Error - LC3 decoding error for frame at offset $offset. Result: $decodeResult');
          // Optionally, break or continue based on desired error handling
        } else {
          if (decodeResult == 1) {
            // PLC (Packet Loss Concealment) was performed
            log('Lc3Decode::Error - PLC performed for frame at offset $offset.');
          }
          // Copy decoded PCM data
          // Note: pcmFramePtr.asTypedList creates a view, not a copy.
          // If you need to process it asynchronously or store it long-term
          // while the buffer might be reused, copy it.
          final pcmFrameDataView = pcmFramePtr.asTypedList(samplesPerFrame);
          allPcmSamples
              .addAll(List<int>.from(pcmFrameDataView)); // Create a copy
        }
        offset += encodedBytesPerFrame;
      }

      if (offset < lc3Bytes.length) {
        log('Lc3Decode::Warning - Remaining ${lc3Bytes.length - offset} bytes in stream were not decoded as they form an incomplete frame.');
      }

      log('Lc3Decode::LC3 decoding finished. Total PCM samples: ${allPcmSamples.length}');
      return Int16List.fromList(allPcmSamples);
    } catch (e, s) {
      log('Lc3Decode::Error - Exception during LC3 decoding: $e\nStack trace:\n$s');
      return null;
    } finally {
      if (pcmFramePtr != null) {
        malloc.free(pcmFramePtr);
      }
      decoder?.dispose();
    }
  }
}
