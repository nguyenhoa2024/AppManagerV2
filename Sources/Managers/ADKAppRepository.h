#import <Foundation/Foundation.h>
#import "ADKApp.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const ADKAppRepositoryDidLoadNotification;

/// Single-shot enumeration of installed apps with on-demand size measurement.
/// `loadAppsWithCompletion:` is safe to call repeatedly — only the first call
/// touches LSApplicationWorkspace; subsequent calls return the cached array.
/// `refreshAppsWithCompletion:` forces a re-scan (pull-to-refresh).
@interface ADKAppRepository : NSObject

+ (instancetype)sharedRepository;

@property (nonatomic, readonly, nullable) NSArray<ADKApp *> *cachedApps;
@property (nonatomic, readonly) BOOL hasLoaded;

- (void)loadAppsWithCompletion:(void (^_Nullable)(NSArray<ADKApp *> *apps))completion;
- (void)refreshAppsWithCompletion:(void (^_Nullable)(NSArray<ADKApp *> *apps))completion;

/// Lazy, cached recursive size measurement of an app's data container.
/// Fires `completion` on main once measured. Returns the cached value
/// immediately for subsequent calls.
- (void)measureSizeForApp:(ADKApp *)app
               completion:(void (^)(unsigned long long bytes))completion;

/// Drops a cached size value (e.g. after wipe/restore).
- (void)invalidateSizeForApp:(ADKApp *)app;

@end

NS_ASSUME_NONNULL_END
