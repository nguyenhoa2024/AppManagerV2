#import <Foundation/Foundation.h>
#import "ADKApp.h"

NS_ASSUME_NONNULL_BEGIN

/// Wraps the private `LSApplicationWorkspace` enumeration into a typed list of
/// ADKApp models. All access goes through NSClassFromString + performSelector
/// to avoid a hard link against private symbols (improves App Store-style
/// scanner survivability and lets the binary load even on iOS versions where
/// some properties are missing).
@interface ADKLSWorkspace : NSObject

+ (NSArray<ADKApp *> *)allInstalledAppsIncludingSystem:(BOOL)includeSystem;

@end

NS_ASSUME_NONNULL_END
