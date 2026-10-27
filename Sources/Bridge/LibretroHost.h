#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

/// Hosts a statically-linked libretro core (AppleWin) and exposes it to Swift.
@interface LibretroHost : NSObject
@property (nonatomic, copy, nullable) void (^onFrame)(UIImage *frame);
@property (nonatomic, copy, nullable) void (^onTick)(void);   // after every emulated frame
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
/// Whether the core exposed libretro's disk-control interface.
@property (nonatomic, readonly) BOOL diskControlAvailable;
/// Sets a core option (e.g. "applewin_video_mode" = "Monochrome (Green)").
- (void)setOption:(NSString *)key value:(NSString *)value;
/// Inserts a disk image into drive 1 or 2 while running.
- (BOOL)insertDiskAtPath:(NSString *)path drive:(int)drive;
/// Opens the tray / removes the disk in drive 1 or 2.
- (BOOL)ejectDriveNumber:(int)drive;
- (BOOL)saveStateToPath:(NSString *)path;
- (BOOL)loadStateFromPath:(NSString *)path;
/// Short text describing controller setup and input polling (for the on-screen debug readout).
- (NSString *)debugInfo;
/// Main RAM view for RetroAchievements (rcheevos) memory reads.
- (const uint8_t * _Nullable)systemRAM:(size_t *)size;
@end
NS_ASSUME_NONNULL_END
