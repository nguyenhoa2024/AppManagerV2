#import <Foundation/Foundation.h>
#import "ADKApp.h"

NS_ASSUME_NONNULL_BEGIN

@interface ADKWipeManager : NSObject

+ (instancetype)sharedManager;

/// Synchronous; call from a background queue.
/// Deletes the contents of the app's data container, leaving the container itself intact
/// so the OS doesn't get confused about the install state.
- (BOOL)wipeApp:(ADKApp *)app error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
