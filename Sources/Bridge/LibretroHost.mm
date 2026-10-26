// UNTESTED SCAFFOLD: written without access to Xcode. Expect small compile fixes.
#import "LibretroHost.h"
#import <AVFoundation/AVFoundation.h>
#include "libretro_min.h"
#include <vector>
#include <mutex>
#include <atomic>
#include <string.h>

static __weak LibretroHost *gHost;               // libretro callbacks are C; one core per process
static std::mutex gAudioLock;
static std::vector<int16_t> gRing;               // interleaved stereo
static retro_keyboard_event_t gKeyCb = nullptr;
static std::atomic<uint16_t> gPad{0};            // bit n = RETRO_DEVICE_ID_JOYPAD id n held
static NSString *gSysDir, *gSaveDir;
static NSString *gControllerInfo = @"(no controller info from core)";
static unsigned gStdPadId = 0;                    // device id the core calls "Standard..." on port 0
static unsigned gDevice = 0;                      // device we selected for port 0
static std::atomic<uint32_t> gInputPolls{0};
static std::atomic<unsigned> gLastDevice{0};

static bool envCb(unsigned cmd, void *data) {
  switch (cmd) {
    case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
      return *(int *)data == RETRO_PIXEL_FORMAT_XRGB8888;
    case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
      *(const char **)data = gSysDir.UTF8String; return true;
    case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
      *(const char **)data = gSaveDir.UTF8String; return true;
    case RETRO_ENVIRONMENT_SET_KEYBOARD_CALLBACK:
      gKeyCb = ((retro_keyboard_callback *)data)->callback; return true;
    case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
      return true;
    case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO: {
      const retro_controller_info *info = (const retro_controller_info *)data;
      NSMutableString *s = [NSMutableString string];
      for (unsigned port = 0; info && info->types; info++, port++) {
        [s appendFormat:@"p%u:", port];
        for (unsigned i = 0; i < info->num_types; i++) {
          const retro_controller_description &d = info->types[i];
          [s appendFormat:@" %s=%u", d.desc ? d.desc : "?", d.id];
          if (port == 0 && d.desc && strstr(d.desc, "Standard") && !gStdPadId) gStdPadId = d.id;
        }
        [s appendString:@"; "];
      }
      gControllerInfo = s;
      return true;
    }
    case RETRO_ENVIRONMENT_GET_VARIABLE:
      return false;   // use core defaults
    default: return false;
  }
}

static void videoCb(const void *data, unsigned w, unsigned h, size_t pitch) {
  if (!data) return;
  CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
  CGContextRef ctx = CGBitmapContextCreate((void *)data, w, h, 8, pitch, cs,
      kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
  CGImageRef img = CGBitmapContextCreateImage(ctx);   // copies pixels
  UIImage *ui = [UIImage imageWithCGImage:img];
  CGImageRelease(img); CGContextRelease(ctx); CGColorSpaceRelease(cs);
  LibretroHost *host = gHost;
  dispatch_async(dispatch_get_main_queue(), ^{ if (host.onFrame) host.onFrame(ui); });
}

static size_t audioBatchCb(const int16_t *d, size_t frames) {
  std::lock_guard<std::mutex> g(gAudioLock);
  gRing.insert(gRing.end(), d, d + frames * 2);
  if (gRing.size() > 48000 * 2) gRing.erase(gRing.begin(), gRing.end() - 24000 * 2); // cap latency
  return frames;
}
static void audioSampleCb(int16_t l, int16_t r) { int16_t s[2] = {l, r}; audioBatchCb(s, 1); }
static void pollCb(void) {}
static int16_t inputCb(unsigned port, unsigned device, unsigned, unsigned id) {
  gInputPolls++; gLastDevice = device;
  if (port != 0 || (device & 0xFF) != RETRO_DEVICE_JOYPAD) return 0;   // low byte = base device (subclasses allowed)
  uint16_t m = gPad.load();
  if (id == RETRO_DEVICE_ID_JOYPAD_MASK) return (int16_t)m;
  return id < 16 ? (int16_t)((m >> id) & 1) : 0;
}

@implementation LibretroHost {
  CADisplayLink *_link;
  AVAudioEngine *_engine;
  double _fps; BOOL _loaded;
}

- (instancetype)initWithSystemDirectory:(NSString *)sysDir saveDirectory:(NSString *)saveDir {
  if ((self = [super init])) {
    gHost = self; gSysDir = sysDir; gSaveDir = saveDir;
    retro_set_environment(envCb);
    retro_init();
    retro_set_video_refresh(videoCb);
    retro_set_audio_sample(audioSampleCb);
    retro_set_audio_sample_batch(audioBatchCb);
    retro_set_input_poll(pollCb);
    retro_set_input_state(inputCb);
  }
  return self;
}

- (BOOL)loadDiskAtPath:(NSString *)path {
  retro_game_info info = { path.UTF8String, nullptr, 0, nullptr };
  if (!retro_load_game(&info)) return NO;
  retro_system_av_info av; retro_get_system_av_info(&av);
  _fps = av.timing.fps > 0 ? av.timing.fps : 60.0;
  // Tell the core which controller is on port 0 (many cores ignore input until told)
  gDevice = gStdPadId ? gStdPadId : RETRO_DEVICE_JOYPAD;
  retro_set_controller_port_device(0, gDevice);
  [self setupAudio:av.timing.sample_rate];
  _loaded = YES; return YES;
}

- (void)setupAudio:(double)rate {
  [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
  [[AVAudioSession sharedInstance] setActive:YES error:nil];
  _engine = [AVAudioEngine new];
  AVAudioFormat *fmt = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                         sampleRate:rate channels:2 interleaved:NO];
  AVAudioSourceNode *src = [[AVAudioSourceNode alloc] initWithFormat:fmt
    renderBlock:^OSStatus(BOOL *, const AudioTimeStamp *, AVAudioFrameCount n, AudioBufferList *abl) {
      float *L = (float *)abl->mBuffers[0].mData, *R = (float *)abl->mBuffers[1].mData;
      std::lock_guard<std::mutex> g(gAudioLock);
      for (AVAudioFrameCount i = 0; i < n; i++) {
        if (gRing.size() >= 2) { L[i] = gRing[0] / 32768.f; R[i] = gRing[1] / 32768.f; gRing.erase(gRing.begin(), gRing.begin() + 2); }
        else { L[i] = R[i] = 0; }
      }
      return noErr; }];
  [_engine attachNode:src]; [_engine connect:src to:_engine.mainMixerNode format:fmt];
  [_engine startAndReturnError:nil];
}

- (BOOL)isRunning { return _link && !_link.paused; }

- (void)start {
  if (!_loaded) return;
  if (!_link) {
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
    _link.preferredFramesPerSecond = (NSInteger)_fps;
    [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
  }
  _link.paused = NO;
}
- (void)pause { _link.paused = YES; }
- (void)reset { if (_loaded) retro_reset(); }
- (void)tick { retro_run(); /* TODO: rc_client_do_frame() for achievements */ }

- (void)sendKey:(uint32_t)ch keycode:(unsigned)kc modifiers:(unsigned)mods down:(BOOL)down {
  if (gKeyCb) gKeyCb(down, kc, ch, (uint16_t)mods);
}
- (void)setJoypadButton:(unsigned)button pressed:(BOOL)pressed {
  if (button > 15) return;
  if (pressed) gPad.fetch_or((uint16_t)(1u << button));
  else gPad.fetch_and((uint16_t)~(1u << button));
}
- (NSString *)debugInfo {
  return [NSString stringWithFormat:@"%@ | set dev=%u | polls=%u lastdev=%u",
          gControllerInfo, gDevice, gInputPolls.load(), gLastDevice.load()];
}
- (const uint8_t *)systemRAM:(size_t *)size {
  *size = retro_get_memory_size(RETRO_MEMORY_SYSTEM_RAM);
  return (const uint8_t *)retro_get_memory_data(RETRO_MEMORY_SYSTEM_RAM);
}
@end
