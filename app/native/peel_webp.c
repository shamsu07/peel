// Small C layer over libwebp so Dart FFI only passes plain numbers and
// pointers, never libwebp structs whose layout could change between versions.
//
// Memory returned through `out` must be released with peel_free().

#include <stddef.h>
#include <stdint.h>

#include "src/webp/encode.h"
#include "src/webp/mux.h"

#if defined(_WIN32)
#define PEEL_EXPORT __declspec(dllexport)
#else
#define PEEL_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

enum {
  PEEL_OK = 0,
  PEEL_ERR_CONFIG = -1,
  PEEL_ERR_PICTURE = -2,
  PEEL_ERR_IMPORT = -3,
  PEEL_ERR_ENCODE = -4,
  PEEL_ERR_ARGS = -5,
};

PEEL_EXPORT int peel_webp_version(void) { return WebPGetEncoderVersion(); }

PEEL_EXPORT void peel_free(void* ptr) { WebPFree(ptr); }

static int peel_config(WebPConfig* config, float quality, int method,
                       int lossless) {
  if (!WebPConfigInit(config)) return 0;
  config->quality = quality;
  config->method = method;
  config->lossless = lossless;
  // Keep sticker edges clean: alpha is compressed losslessly-ish.
  config->alpha_quality = 100;
  config->thread_level = 1;
  return WebPValidateConfig(config);
}

static int peel_import(WebPPicture* pic, const uint8_t* rgba, int width,
                       int height, int stride, int lossless) {
  if (!WebPPictureInit(pic)) return 0;
  pic->use_argb = lossless ? 1 : 0;
  pic->width = width;
  pic->height = height;
  return WebPPictureImportRGBA(pic, rgba, stride);
}

// Encodes one RGBA image as a still WebP.
PEEL_EXPORT int peel_encode_static(const uint8_t* rgba, int width, int height,
                                   int stride, float quality, int method,
                                   int lossless, uint8_t** out,
                                   size_t* out_size) {
  if (rgba == NULL || out == NULL || out_size == NULL) return PEEL_ERR_ARGS;

  WebPConfig config;
  if (!peel_config(&config, quality, method, lossless)) return PEEL_ERR_CONFIG;

  WebPPicture pic;
  if (!peel_import(&pic, rgba, width, height, stride, lossless)) {
    WebPPictureFree(&pic);
    return PEEL_ERR_IMPORT;
  }

  WebPMemoryWriter writer;
  WebPMemoryWriterInit(&writer);
  pic.writer = WebPMemoryWrite;
  pic.custom_ptr = &writer;

  const int ok = WebPEncode(&config, &pic);
  WebPPictureFree(&pic);
  if (!ok) {
    WebPMemoryWriterClear(&writer);
    return PEEL_ERR_ENCODE;
  }
  *out = writer.mem;
  *out_size = writer.size;
  return PEEL_OK;
}

// Animated encoding: new -> add (per frame) -> assemble -> delete.
PEEL_EXPORT void* peel_anim_new(int width, int height, int kmin, int kmax,
                                int allow_mixed) {
  WebPAnimEncoderOptions options;
  if (!WebPAnimEncoderOptionsInit(&options)) return NULL;
  options.anim_params.loop_count = 0;  // Loop forever.
  options.anim_params.bgcolor = 0x00000000;  // Transparent.
  options.minimize_size = 0;
  options.kmin = kmin;
  options.kmax = kmax;
  options.allow_mixed = allow_mixed;
  return WebPAnimEncoderNew(width, height, &options);
}

PEEL_EXPORT int peel_anim_add(void* encoder, const uint8_t* rgba, int width,
                              int height, int stride, int timestamp_ms,
                              float quality, int method, int lossless) {
  if (encoder == NULL || rgba == NULL) return PEEL_ERR_ARGS;

  WebPConfig config;
  if (!peel_config(&config, quality, method, lossless)) return PEEL_ERR_CONFIG;

  WebPPicture pic;
  if (!peel_import(&pic, rgba, width, height, stride, lossless)) {
    WebPPictureFree(&pic);
    return PEEL_ERR_IMPORT;
  }
  const int ok = WebPAnimEncoderAdd((WebPAnimEncoder*)encoder, &pic,
                                    timestamp_ms, &config);
  WebPPictureFree(&pic);
  return ok ? PEEL_OK : PEEL_ERR_ENCODE;
}

// Closes the animation at end_timestamp_ms and returns the file bytes.
PEEL_EXPORT int peel_anim_assemble(void* encoder, int end_timestamp_ms,
                                   uint8_t** out, size_t* out_size) {
  if (encoder == NULL || out == NULL || out_size == NULL) return PEEL_ERR_ARGS;
  WebPAnimEncoder* enc = (WebPAnimEncoder*)encoder;

  if (!WebPAnimEncoderAdd(enc, NULL, end_timestamp_ms, NULL)) {
    return PEEL_ERR_ENCODE;
  }
  WebPData data;
  WebPDataInit(&data);
  if (!WebPAnimEncoderAssemble(enc, &data)) {
    WebPDataClear(&data);
    return PEEL_ERR_ENCODE;
  }
  *out = (uint8_t*)data.bytes;
  *out_size = data.size;
  return PEEL_OK;
}

PEEL_EXPORT void peel_anim_delete(void* encoder) {
  if (encoder != NULL) WebPAnimEncoderDelete((WebPAnimEncoder*)encoder);
}
