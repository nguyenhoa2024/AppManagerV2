#import "ADKSelectionState.h"

NSNotificationName const ADKSelectionStateDidChangeNotification = @"ADKSelectionStateDidChangeNotification";

static NSString *const ADKSelectionDefaultsKey = @"ADKSelectedBundleIDs";

@interface ADKSelectionState ()
@property (nonatomic, strong) NSMutableSet<NSString *> *backing;
@end

@implementation ADKSelectionState

+ (instancetype)sharedState
{
    static ADKSelectionState *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init
{
    if ((self = [super init])) {
        NSArray *stored = [NSUserDefaults.standardUserDefaults arrayForKey:ADKSelectionDefaultsKey];
        _backing = [NSMutableSet setWithArray:stored ?: @[]];
    }
    return self;
}

- (NSSet<NSString *> *)selectedBundleIDs { return [self.backing copy]; }

- (BOOL)isSelected:(NSString *)bundleID
{
    return bundleID && [self.backing containsObject:bundleID];
}

- (void)_persistAndNotify
{
    [NSUserDefaults.standardUserDefaults setObject:self.backing.allObjects forKey:ADKSelectionDefaultsKey];
    [NSNotificationCenter.defaultCenter postNotificationName:ADKSelectionStateDidChangeNotification object:self];
}

- (void)select:(NSString *)bundleID
{
    if (!bundleID) return;
    if ([self.backing containsObject:bundleID]) return;
    [self.backing addObject:bundleID];
    [self _persistAndNotify];
}

- (void)deselect:(NSString *)bundleID
{
    if (!bundleID) return;
    if (![self.backing containsObject:bundleID]) return;
    [self.backing removeObject:bundleID];
    [self _persistAndNotify];
}

- (void)toggle:(NSString *)bundleID
{
    if (!bundleID) return;
    if ([self.backing containsObject:bundleID]) [self.backing removeObject:bundleID];
    else                                        [self.backing addObject:bundleID];
    [self _persistAndNotify];
}

- (void)selectAll:(NSArray<NSString *> *)bundleIDs
{
    if (!bundleIDs.count) return;
    [self.backing addObjectsFromArray:bundleIDs];
    [self _persistAndNotify];
}

- (void)deselectAll
{
    if (!self.backing.count) return;
    [self.backing removeAllObjects];
    [self _persistAndNotify];
}

@end
