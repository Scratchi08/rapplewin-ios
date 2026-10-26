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
#define RETRO_DEVICE_ID_JOYPAD_B 0
#define RETRO_DEVICE_ID_JOYPAD_Y 1
#define RETRO_DEVICE_ID_JOYPAD_SELECT 2
#define RETRO_DEVICE_ID_JOYPAD_START 3
#define RETRO_DEVICE_ID_JOYPAD_UP 4
#define RETRO_DEVICE_ID_JOYPAD_DOWN 5
#define RETRO_DEVICE_ID_JOYPAD_LEFT 6
#define RETRO_DEVICE_ID_JOYPAD_RIGHT 7
#define RETRO_DEVICE_ID_JOYPAD_A 8
#define RETRO_DEVICE_ID_JOYPAD_X 9
#define RETRO_DEVICE_ID_JOYPAD_L 10
#define RETRO_DEVICE_ID_JOYPAD_R 11
#define RETRO_DEVICE_ID_JOYPAD_MASK 256
#define RETRO_MEMORY_SYSTEM_RAM 2
#define RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY 9
#define RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS 11
#define RETRO_ENVIRONMENT_SET_PIXEL_FORMAT 10
#define RETRO_ENVIRONMENT_SET_KEYBOARD_CALLBACK 12
#define RETRO_ENVIRONMENT_SET_CONTROLLER_INFO 35
#define RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE 13
#define RETRO_ENVIRONMENT_GET_VARIABLE 15
#define RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE 17
#define RETRO_ENVIRONMENT_GET_DISK_CONTROL_INTERFACE_VERSION 57
#define RETRO_ENVIRONMENT_SET_DISK_CONTROL_EXT_INTERFACE 58
#define RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY 31
#define RETRO_PIXEL_FORMAT_XRGB8888 1

struct retro_game_info { const char *path; const void *data; size_t size; const char *meta; };
struct retro_game_geometry { unsigned base_width, base_height, max_width, max_height; float aspect_ratio; };
struct retro_system_timing { double fps; double sample_rate; };
struct retro_system_av_info { struct retro_game_geometry geometry; struct retro_system_timing timing; };
struct retro_variable { const char *key; const char *value; };
typedef void (*retro_keyboard_event_t)(bool down, unsigned keycode, uint32_t character, uint16_t key_modifiers);
struct retro_keyboard_callback { retro_keyboard_event_t callback; };
typedef bool (*retro_set_eject_state_t)(bool ejected);
typedef bool (*retro_get_eject_state_t)(void);
typedef unsigned (*retro_get_image_index_t)(void);
typedef bool (*retro_set_image_index_t)(unsigned index);
typedef unsigned (*retro_get_num_images_t)(void);
typedef bool (*retro_replace_image_index_t)(unsigned index, const struct retro_game_info *info);
typedef bool (*retro_add_image_index_t)(void);
/* The EXT interface starts with these same 7 members, so it can be read through this struct. */
struct retro_disk_control_callback {
  retro_set_eject_state_t set_eject_state; retro_get_eject_state_t get_eject_state;
  retro_get_image_index_t get_image_index; retro_set_image_index_t set_image_index;
  retro_get_num_images_t get_num_images; retro_replace_image_index_t replace_image_index;
  retro_add_image_index_t add_image_index;
};
struct retro_controller_description { const char *desc; unsigned id; };
struct retro_controller_info { const struct retro_controller_description *types; unsigned num_types; };

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
void retro_set_controller_port_device(unsigned port, unsigned device);
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
