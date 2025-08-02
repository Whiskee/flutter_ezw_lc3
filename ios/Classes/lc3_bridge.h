//
//  lc3_bridge.h
//  flutter_ezw_lc3
//
//  Created for ensuring LC3 static library symbols are available
//

#ifndef lc3_bridge_h
#define lc3_bridge_h

#ifdef __cplusplus
extern "C" {
#endif

// LC3 function declarations to ensure symbols are linked
unsigned lc3_encoder_size(int dt_us, int sr_hz);
unsigned lc3_decoder_size(int dt_us, int sr_hz);
int lc3_frame_samples(int dt_us, int sr_hz);
int lc3_hr_frame_samples(int hrmode, int dt_us, int sr_hz);
int lc3_hr_frame_bytes(int hrmode, int dt_us, int sr_hz, int bitrate);

// Forward declarations for setup functions
struct lc3_encoder;
struct lc3_decoder;
typedef struct lc3_encoder *lc3_encoder_t;
typedef struct lc3_decoder *lc3_decoder_t;

lc3_encoder_t lc3_setup_encoder(int dt_us, int sr_hz, int sr_pcm_hz, void *mem);
lc3_decoder_t lc3_setup_decoder(int dt_us, int sr_hz, int sr_pcm_hz, void *mem);

// PCM format enum
enum lc3_pcm_format {
    LC3_PCM_FORMAT_S16 = 0,
    LC3_PCM_FORMAT_S24,
    LC3_PCM_FORMAT_S24_3LE,
    LC3_PCM_FORMAT_FLOAT
};

int lc3_encode(lc3_encoder_t encoder, enum lc3_pcm_format fmt,
               const void *pcm, int stride, int frame_size, void *out);

int lc3_decode(lc3_decoder_t decoder, const void *in, int nbytes,
               enum lc3_pcm_format fmt, void *pcm, int stride);

// Function to ensure symbols are linked
void flutter_ezw_lc3_ensure_symbols_linked(void);

#ifdef __cplusplus
}
#endif

#endif /* lc3_bridge_h */