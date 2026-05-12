#import <UIKit/UIKit.h>
#import "ADKApp.h"

NS_ASSUME_NONNULL_BEGIN

/// In-memory NSCache of decoded UIImages keyed by bundle identifier.
/// Loads happen on a background queue. Hit on the main queue returns immediately
/// when the icon is already decoded; otherwise the completion fires on the main
/// queue once the icon has been read & downsampled.
///
/// Memory pressure: NSCache evicts on UIApplicationDidReceiveMemoryWarning.
@interface ADKIconCache : NSObject

+ (instancetype)sharedCache;

/// Returns the cached icon for `app` immediately, or nil if not yet loaded.
- (nullable UIImage *)cachedIconForApp:(ADKApp *)app;

/// Loads the icon asynchronously. Completion is always invoked on main.
/// Multiple concurrent requests for the same bundle ID coalesce into one read.
- (void)iconForApp:(ADKApp *)app completion:(void (^)(UIImage *_Nullable icon))completion;

- (void)removeAllObjects;

@end

NS_ASSUME_NONNULL_END
