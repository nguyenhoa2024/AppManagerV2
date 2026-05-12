#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const ADKSelectionStateDidChangeNotification;

/// Persists the set of selected bundle identifiers across launches via NSUserDefaults.
@interface ADKSelectionState : NSObject

+ (instancetype)sharedState;

@property (nonatomic, copy, readonly) NSSet<NSString *> *selectedBundleIDs;

- (BOOL)isSelected:(NSString *)bundleID;
- (void)select:(NSString *)bundleID;
- (void)deselect:(NSString *)bundleID;
- (void)toggle:(NSString *)bundleID;
- (void)selectAll:(NSArray<NSString *> *)bundleIDs;
- (void)deselectAll;

@end

NS_ASSUME_NONNULL_END
