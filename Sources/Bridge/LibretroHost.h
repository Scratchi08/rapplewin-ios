#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

/// Hosts a statically-linked libretro core (AppleWin) and exposes it to Swift.
@interface LibretroHost : NSObject
@property (nonatomic, copy, nullable) void (^onFrame)(UIImage *frame);
@property (nonatomic, readonly) BOOL isRunning;

- (instancetype)initWithSystemDirectory:(NSString *)sysDir saveDirectory:(NSString *)saveDir;
- (BOOL)loadDiskAtPath:(NSString *)path;
- (void)start;
- (void)pause;
- (void)reset;
/// Key input. `character` is ASCII (control codes for Ctrl combos), `keycode` a libretro RETROK_* value
/// (0 if unknown), `modifiers` libretro RETROKMOD_* flags (1=Shift, 2=Ctrl, 4=Alt).
- (void)sendKey:(uint32_t)character keycode:(unsigned)keycode modifiers:(unsigned)modifiers down:(BOOL)down;
/// Joypad button state for port 0. `button` is a libretro RETRO_DEVICE_ID_JOYPAD_* id (0-11).
- (void)setJoypadButton:(unsigned)button pressed:(BOOL)pressed;
/// Main RAM view for RetroAchievements (rcheevos) memory reads.
- (const uint8_t * _Nullable)systemRAM:(size_t *)size;
@end
NS_ASSUME_NONNULL_END
