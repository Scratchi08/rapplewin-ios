#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface RAAchievement : NSObject
@property (nonatomic) uint32_t identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic) uint32_t points;
@property (nonatomic) BOOL unlocked;
@property (nonatomic, copy, nullable) NSString *progress;
@property (nonatomic, strong, nullable) NSURL *badgeURL;
@end

typedef void (^RALoginResult)(NSString *_Nullable error, NSString *_Nullable username, NSString *_Nullable token);
typedef void (^RALoadResult)(NSString *_Nullable error);

/// Objective-C wrapper around rcheevos' rc_client (RetroAchievements runtime), softcore only.
@interface RAClient : NSObject
@property (nonatomic, copy, nullable) void (^onToast)(NSString *title, NSString *message, NSURL *_Nullable badge, BOOL unlock);
@property (nonatomic, copy, nullable) void (^onChange)(void);
/// Raised when the emulated system must restart (rcheevos asks for this when hardcore is switched on mid-game).
@property (nonatomic, copy, nullable) void (^onResetRequested)(void);
/// Hardcore mode. Off by default. Turning it on with a game loaded raises onResetRequested.
@property (nonatomic) BOOL hardcore;

@property (nonatomic, readonly, nullable) NSString *displayName;   // nil when logged out
@property (nonatomic, readonly) uint32_t score;
@property (nonatomic, readonly, nullable) NSString *gameTitle;
@property (nonatomic, readonly) BOOL gameLoaded;
@property (nonatomic, readonly) uint32_t coreCount;
@property (nonatomic, readonly) uint32_t unlockedCount;
@property (nonatomic, readonly) uint32_t pointsTotal;
@property (nonatomic, readonly) uint32_t pointsUnlocked;
@property (nonatomic, readonly, copy) NSString *logText;

- (void)loginWithUsername:(NSString *)username password:(NSString *)password completion:(RALoginResult)completion;
- (void)loginWithUsername:(NSString *)username token:(NSString *)token completion:(RALoginResult)completion;
- (void)logout;
/// `hash` is the lowercase hex MD5 of the whole disk image (RetroAchievements' Apple II hash).
- (void)loadGameWithHash:(NSString *)hash completion:(RALoadResult)completion;
- (void)unloadGame;
/// Call once per emulated frame, after the core has run.
- (void)doFrame;
- (void)reset;
- (NSArray<RAAchievement *> *)achievements;
- (nullable NSData *)serializeProgress;
- (BOOL)deserializeProgress:(NSData *)data;
@end
NS_ASSUME_NONNULL_END
