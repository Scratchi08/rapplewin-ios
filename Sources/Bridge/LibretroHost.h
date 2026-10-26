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
/// Apple II key input. `character` is ASCII; `down` for press/release.
- (void)sendKey:(uint32_t)character keycode:(unsigned)keycode down:(BOOL)down;
/// Main RAM view for RetroAchievements (rcheevos) memory reads.
- (const uint8_t * _Nullable)systemRAM:(size_t *)size;
@end
NS_ASSUME_NONNULL_END
