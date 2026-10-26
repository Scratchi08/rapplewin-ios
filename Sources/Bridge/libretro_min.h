// Minimal subset of libretro.h (MIT). Replace with the official header from
// https://github.com/libretro/libretro-common once the real core is in place.
#pragma once
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
#define RETRO_DEVICE_JOYPAD 1
#define RETRO_MEMORY_SYSTEM_RAM 2
#define RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY 9
#define RETRO_ENVIRONMENT_SET_PIXEL_FORMAT 10
#define RETRO_ENVIRONMENT_SET_KEYBOARD_CALLBACK 12
#define RETRO_ENVIRONMENT_GET_VARIABLE 15
#define RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY 31
#define RETRO_PIXEL_FORMAT_XRGB8888 1

struct retro_game_info { const char *path; const void *data; size_t size; const char *meta; };
struct retro_game_geometry { unsigned base_width, base_height, max_width, max_height; float aspect_ratio; };
struct retro_system_timing { double fps; double sample_rate; };
struct retro_system_av_info { struct retro_game_geometry geometry; struct retro_system_timing timing; };
struct retro_variable { const char *key; const char *value; };
typedef void (*retro_keyboard_event_t)(bool down, unsigned keycode, uint32_t character, uint16_t key_modifiers);
struct retro_keyboard_callback { retro_keyboard_event_t callback; };

typedef bool (*retro_environment_t)(unsigned cmd, void *data);
typedef void (*retro_video_refresh_t)(const void *data, unsigned width, unsigned height, size_t pitch);
typedef void (*retro_audio_sample_t)(int16_t left, int16_t right);
typedef size_t (*retro_audio_sample_batch_t)(const int16_t *data, size_t frames);
typedef void (*retro_input_poll_t)(void);
typedef int16_t (*retro_input_state_t)(unsigned port, unsigned device, unsigned index, unsigned id);

void retro_set_environment(retro_environment_t);
void retro_set_video_refresh(retro_video_refresh_t);
void retro_set_audio_sample(retro_audio_sample_t);
void retro_set_audio_sample_batch(retro_audio_sample_batch_t);
void retro_set_input_poll(retro_input_poll_t);
void retro_set_input_state(retro_input_state_t);
void retro_init(void);
void retro_deinit(void);
bool retro_load_game(const struct retro_game_info *);
void retro_unload_game(void);
void retro_get_system_av_info(struct retro_system_av_info *);
void retro_run(void);
void retro_reset(void);
size_t retro_serialize_size(void);
bool retro_serialize(void *, size_t);
bool retro_unserialize(const void *, size_t);
void *retro_get_memory_data(unsigned id);
size_t retro_get_memory_size(unsigned id);
#ifdef __cplusplus
}
#endif
