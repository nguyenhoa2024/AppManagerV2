#import <Foundation/Foundation.h>
#import "ADKApp.h"
#import "ADKBackup.h"

NS_ASSUME_NONNULL_BEGIN

@interface ADKRestoreManager : NSObject

+ (instancetype)sharedManager;

/// Synchronous; call from a background queue.
/// Wipes the existing data container, then extracts the backup over it.
- (BOOL)restoreBackup:(ADKBackup *)backup
              forApp:(ADKApp *)app
               error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
