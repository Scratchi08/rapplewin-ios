// UNTESTED SCAFFOLD: written without Xcode. rcheevos API names were checked against the
// current rc_client.h (12.x); expect small compile fixes.
#import "RAClient.h"
#include "rc_client.h"
#include <string.h>
#include <algorithm>

// AppleWin core internals (linked statically): 64 KB main RAM and 64 KB auxiliary RAM.
extern uint8_t *MemGetMainPtr(uint16_t offset);
extern uint8_t *MemGetAuxPtr(uint16_t offset);

#ifndef RC_API_SERVER_RESPONSE_RETRYABLE_CLIENT_ERROR
#define RC_API_SERVER_RESPONSE_RETRYABLE_CLIENT_ERROR -2
#endif

static NSString *S(const char *s) { return s ? [NSString stringWithUTF8String:s] ?: @"" : @""; }
static NSString *gUserAgent = @"RAppleWin-iOS/0.1";

// RetroAchievements Apple II memory map: bank 0 = main RAM at 0x00000, bank 1 = aux RAM at 0x10000.
static uint32_t readMemory(uint32_t address, uint8_t *buffer, uint32_t num_bytes, rc_client_t *) {
  const uint8_t *base; uint32_t offset;
  if (address < 0x10000)      { base = MemGetMainPtr(0); offset = address; }
  else if (address < 0x20000) { base = MemGetAuxPtr(0);  offset = address - 0x10000; }
  else return 0;
  if (!base) return 0;
  uint32_t n = std::min<uint32_t>(num_bytes, 0x10000 - offset);
  memcpy(buffer, base + offset, n);
  return n;
}

static void serverCall(const rc_api_request_t *request, rc_client_server_callback_t callback,
                       void *callbackData, rc_client_t *) {
  NSURL *url = [NSURL URLWithString:S(request->url)];
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  req.timeoutInterval = 30;
  [req setValue:gUserAgent forHTTPHeaderField:@"User-Agent"];
  if (request->post_data) {
    req.HTTPMethod = @"POST";
    req.HTTPBody = [NSData dataWithBytes:request->post_data length:strlen(request->post_data)];
    [req setValue:(request->content_type ? S(request->content_type) : @"application/x-www-form-urlencoded")
        forHTTPHeaderField:@"Content-Type"];
  }
  [[NSURLSession.sharedSession dataTaskWithRequest:req
      completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
    dispatch_async(dispatch_get_main_queue(), ^{
      rc_api_server_response_t r; memset(&r, 0, sizeof r);
      NSMutableData *body = [NSMutableData dataWithData:data ?: [NSData data]];
      if (err) {
        NSData *msg = [err.localizedDescription dataUsingEncoding:NSUTF8StringEncoding];
        body = [NSMutableData dataWithData:msg ?: [NSData data]];
        r.http_status_code = RC_API_SERVER_RESPONSE_RETRYABLE_CLIENT_ERROR;
      } else {
        r.http_status_code = (int)((NSHTTPURLResponse *)resp).statusCode;
      }
      r.body_length = body.length;
      [body appendBytes:"\0" length:1];                 // keep the body NUL-terminated
      r.body = (const char *)body.bytes;
      callback(&r, callbackData);
    });
  }] resume];
}

@implementation RAAchievement
@end

@implementation RAClient {
  rc_client_t *_client;
  NSMutableArray<NSString *> *_log;
}

static void logCallback(const char *message, const rc_client_t *client) {
  RAClient *self = (__bridge RAClient *)rc_client_get_userdata(client);
  [self appendLog:S(message)];
}
static void eventHandler(const rc_client_event_t *event, rc_client_t *client) {
  RAClient *self = (__bridge RAClient *)rc_client_get_userdata(client);
  [self handleEvent:event];
}

- (instancetype)init {
  if ((self = [super init])) {
    _log = [NSMutableArray array];
    _client = rc_client_create(readMemory, serverCall);
    rc_client_set_userdata(_client, (__bridge void *)self);
    rc_client_set_event_handler(_client, eventHandler);
    rc_client_enable_logging(_client, RC_CLIENT_LOG_LEVEL_INFO, logCallback);
    rc_client_set_hardcore_enabled(_client, 0);      // softcore: our save states aren't allowed in hardcore
    char clause[64] = {0};
    rc_client_get_user_agent_clause(_client, clause, sizeof clause);
    gUserAgent = [NSString stringWithFormat:@"RAppleWin-iOS/0.1 (iOS) %s", clause];
  }
  return self;
}

- (void)dealloc { if (_client) rc_client_destroy(_client); }

- (void)setHardcore:(BOOL)hardcore {
  rc_client_set_hardcore_enabled(_client, hardcore ? 1 : 0);
  [self changed];
}
- (BOOL)hardcore { return rc_client_get_hardcore_enabled(_client) != 0; }

- (void)appendLog:(NSString *)line {
  NSLog(@"[RA] %@", line);
  [_log addObject:line];
  if (_log.count > 60) [_log removeObjectAtIndex:0];
}
- (NSString *)logText { return [_log componentsJoinedByString:@"\n"]; }

- (void)changed {
  dispatch_async(dispatch_get_main_queue(), ^{ if (self.onChange) self.onChange(); });
}
- (void)toast:(NSString *)title message:(NSString *)message badge:(NSURL *)badge unlock:(BOOL)unlock {
  if (self.onToast) self.onToast(title, message, badge, unlock);
}

- (NSURL *)badgeFor:(const rc_client_achievement_t *)a state:(int)state {
  char url[256] = {0};
  if (rc_client_achievement_get_image_url(a, state, url, sizeof url) != RC_OK) return nil;
  return [NSURL URLWithString:S(url)];
}

- (void)handleEvent:(const rc_client_event_t *)e {
  switch (e->type) {
    case RC_CLIENT_EVENT_ACHIEVEMENT_TRIGGERED: {
      const rc_client_achievement_t *a = e->achievement;
      [self toast:[NSString stringWithFormat:@"Achievement unlocked: %@", S(a->title)]
          message:[NSString stringWithFormat:@"%@ (%u pts)", S(a->description), a->points]
            badge:[self badgeFor:a state:RC_CLIENT_ACHIEVEMENT_STATE_UNLOCKED] unlock:YES];
      break;
    }
    case RC_CLIENT_EVENT_RESET:
      // Hardcore was switched on with a game running: the emulator must restart, then call reset().
      [self toast:@"Hardcore mode on" message:@"Restarting the game." badge:nil unlock:NO];
      dispatch_async(dispatch_get_main_queue(), ^{ if (self.onResetRequested) self.onResetRequested(); });
      break;
    case RC_CLIENT_EVENT_GAME_COMPLETED:
      [self toast:@"Game completed!" message:@"You earned every achievement in this set." badge:nil unlock:YES];
      break;
    case RC_CLIENT_EVENT_LEADERBOARD_STARTED:
      [self toast:@"Leaderboard attempt started" message:S(e->leaderboard->title) badge:nil unlock:NO];
      break;
    case RC_CLIENT_EVENT_LEADERBOARD_SUBMITTED:
      [self toast:@"Leaderboard score submitted" message:S(e->leaderboard->title) badge:nil unlock:NO];
      break;
    case RC_CLIENT_EVENT_SERVER_ERROR:
      [self toast:@"RetroAchievements server error"
          message:[NSString stringWithFormat:@"%@: %@", S(e->server_error->api), S(e->server_error->error_message)]
            badge:nil unlock:NO];
      break;
    case RC_CLIENT_EVENT_DISCONNECTED:
      [self toast:@"RetroAchievements offline" message:@"Unlocks are queued and will be sent when back online." badge:nil unlock:NO];
      break;
    case RC_CLIENT_EVENT_RECONNECTED:
      [self toast:@"RetroAchievements back online" message:@"Pending unlocks were sent." badge:nil unlock:NO];
      break;
    default: break;
  }
  [self changed];
}

// MARK: Login

static void loginCallback(int result, const char *error, rc_client_t *client, void *ud) {
  RALoginResult block = (__bridge_transfer RALoginResult)ud;
  RAClient *self = (__bridge RAClient *)rc_client_get_userdata(client);
  if (result != RC_OK) {
    NSString *msg = S(error);
    if (block) block(msg.length ? msg : @"Login failed", nil, nil);
  } else {
    const rc_client_user_t *u = rc_client_get_user_info(client);
    if (block) block(nil, u ? S(u->username) : @"", u ? S(u->token) : @"");
  }
  [self changed];
}

- (void)loginWithUsername:(NSString *)username password:(NSString *)password completion:(RALoginResult)completion {
  RALoginResult copy = [completion copy];
  rc_client_begin_login_with_password(_client, username.UTF8String, password.UTF8String,
                                      loginCallback, (__bridge_retained void *)copy);
}
- (void)loginWithUsername:(NSString *)username token:(NSString *)token completion:(RALoginResult)completion {
  RALoginResult copy = [completion copy];
  rc_client_begin_login_with_token(_client, username.UTF8String, token.UTF8String,
                                   loginCallback, (__bridge_retained void *)copy);
}
- (void)logout { rc_client_logout(_client); [self changed]; }

// MARK: Game

static void loadCallback(int result, const char *error, rc_client_t *client, void *ud) {
  RALoadResult block = (__bridge_transfer RALoadResult)ud;
  RAClient *self = (__bridge RAClient *)rc_client_get_userdata(client);
  if (block) {
    if (result != RC_OK) { NSString *m = S(error); block(m.length ? m : @"Game not recognised"); }
    else block(nil);
  }
  [self changed];
}

- (void)loadGameWithHash:(NSString *)hash completion:(RALoadResult)completion {
  RALoadResult copy = [completion copy];
  rc_client_begin_load_game(_client, hash.UTF8String, loadCallback, (__bridge_retained void *)copy);
}
- (void)unloadGame { rc_client_unload_game(_client); [self changed]; }
- (void)doFrame { if (rc_client_is_game_loaded(_client)) rc_client_do_frame(_client); }
- (void)reset { if (rc_client_is_game_loaded(_client)) rc_client_reset(_client); }

// MARK: State

- (NSString *)displayName {
  const rc_client_user_t *u = rc_client_get_user_info(_client);
  return u ? S(u->display_name) : nil;
}
- (uint32_t)score {
  const rc_client_user_t *u = rc_client_get_user_info(_client);
  return u ? (rc_client_get_hardcore_enabled(_client) ? u->score : u->score_softcore) : 0;
}
- (BOOL)gameLoaded { return rc_client_is_game_loaded(_client) != 0; }
- (NSString *)gameTitle {
  if (!rc_client_is_game_loaded(_client)) return nil;
  const rc_client_game_t *g = rc_client_get_game_info(_client);
  return g ? S(g->title) : nil;
}
- (rc_client_user_game_summary_t)summary {
  rc_client_user_game_summary_t s; memset(&s, 0, sizeof s);
  if (rc_client_is_game_loaded(_client)) rc_client_get_user_game_summary(_client, &s);
  return s;
}
- (uint32_t)coreCount { return [self summary].num_core_achievements; }
- (uint32_t)unlockedCount { return [self summary].num_unlocked_achievements; }
- (uint32_t)pointsTotal { return [self summary].points_core; }
- (uint32_t)pointsUnlocked { return [self summary].points_unlocked; }

- (NSArray<RAAchievement *> *)achievements {
  NSMutableArray *out = [NSMutableArray array];
  if (!rc_client_is_game_loaded(_client)) return out;
  rc_client_achievement_list_t *list = rc_client_create_achievement_list(
      _client, RC_CLIENT_ACHIEVEMENT_CATEGORY_CORE, RC_CLIENT_ACHIEVEMENT_LIST_GROUPING_LOCK_STATE);
  if (!list) return out;
  for (uint32_t b = 0; b < list->num_buckets; b++) {
    const rc_client_achievement_bucket_t &bucket = list->buckets[b];
    for (uint32_t i = 0; i < bucket.num_achievements; i++) {
      const rc_client_achievement_t *a = bucket.achievements[i];
      RAAchievement *r = [RAAchievement new];
      r.identifier = a->id;
      r.title = S(a->title);
      r.detail = S(a->description);
      r.points = a->points;
      r.unlocked = (a->state == RC_CLIENT_ACHIEVEMENT_STATE_UNLOCKED);
      r.progress = a->measured_progress[0] ? S(a->measured_progress) : nil;
      r.badgeURL = [self badgeFor:a state:(r.unlocked ? RC_CLIENT_ACHIEVEMENT_STATE_UNLOCKED
                                                       : RC_CLIENT_ACHIEVEMENT_STATE_ACTIVE)];
      [out addObject:r];
    }
  }
  rc_client_destroy_achievement_list(list);
  return out;
}

- (NSData *)serializeProgress {
  if (!rc_client_is_game_loaded(_client)) return nil;
  size_t n = rc_client_progress_size(_client);
  if (!n) return nil;
  NSMutableData *d = [NSMutableData dataWithLength:n];
  return rc_client_serialize_progress_sized(_client, (uint8_t *)d.mutableBytes, n) == RC_OK ? d : nil;
}
- (BOOL)deserializeProgress:(NSData *)data {
  return rc_client_deserialize_progress_sized(_client, (const uint8_t *)data.bytes, data.length) == RC_OK;
}
@end
