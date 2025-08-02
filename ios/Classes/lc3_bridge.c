//
//  lc3_bridge.c
//  flutter_ezw_lc3
//
//  Created for ensuring LC3 static library symbols are available
//

#include "lc3_bridge.h"

// This function ensures that LC3 symbols are referenced and not stripped during linking
void flutter_ezw_lc3_ensure_symbols_linked(void) {
    // Create dummy function pointers to ensure symbols are linked
    // These will never be called, but ensure the symbols are not stripped
    
    volatile void* dummy_refs[] = {
        (void*)lc3_encoder_size,
        (void*)lc3_decoder_size,
        (void*)lc3_frame_samples,
        (void*)lc3_hr_frame_samples,
        (void*)lc3_hr_frame_bytes,
        (void*)lc3_setup_encoder,
        (void*)lc3_setup_decoder,
        (void*)lc3_encode,
        (void*)lc3_decode
    };
    
    // Prevent compiler from optimizing away the references
    (void)dummy_refs;
}