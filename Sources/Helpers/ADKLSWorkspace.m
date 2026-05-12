#import "ADKLSWorkspace.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation ADKLSWorkspace

static id _adk_safe_perform(id target, SEL sel)
{
    if (!target || !sel || ![target respondsToSelector:sel]) return nil;
    IMP imp = [target methodForSelector:sel];
    id (*fn)(id, SEL) = (id (*)(id, SEL))imp;
    return fn(target, sel);
}

static ADKAppType _adk_translate_type(NSString *type)
{
    if (!type) return ADKAppTypeUser;
    if ([type isEqualToString:@"User"])     return ADKAppTypeUser;
    if ([type isEqualToString:@"System"])   return ADKAppTypeSystem;
    if ([type isEqualToString:@"Internal"]) return ADKAppTypeInternal;
    return ADKAppTypeUser;
}

static NSString *_adk_first_icon_name(NSDictionary *infoPlist)
{
    if (![infoPlist isKindOfClass:NSDictionary.class]) return nil;

    NSDictionary *icons = infoPlist[@"CFBundleIcons"] ?: infoPlist[@"CFBundleIcons~ipad"];
    NSDictionary *primary = icons[@"CFBundlePrimaryIcon"];
    NSArray *files = primary[@"CFBundleIconFiles"];
    if ([files isKindOfClass:NSArray.class] && files.count) {
        // Last one is usually the largest variant.
        return [files lastObject];
    }
    NSString *single = infoPlist[@"CFBundleIconFile"];
    if ([single isKindOfClass:NSString.class]) return single;
    return nil;
}

+ (NSArray<ADKApp *> *)allInstalledAppsIncludingSystem:(BOOL)includeSystem
{
    Class wsClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!wsClass) return @[];

    id workspace = _adk_safe_perform(wsClass, @selector(defaultWorkspace));
    if (!workspace) return @[];

    NSArray *proxies = _adk_safe_perform(workspace, @selector(allApplications));
    if (![proxies isKindOfClass:NSArray.class]) return @[];

    NSMutableArray<ADKApp *> *out = [NSMutableArray arrayWithCapacity:proxies.count];

    for (id proxy in proxies) {
        @autoreleasepool {
            NSString *bundleID  = _adk_safe_perform(proxy, @selector(bundleIdentifier));
            if (![bundleID isKindOfClass:NSString.class] || bundleID.length == 0) continue;

            NSString *appTypeStr = _adk_safe_perform(proxy, @selector(applicationType));
            ADKAppType type = _adk_translate_type(appTypeStr);
            if (!includeSystem && type != ADKAppTypeUser) continue;

            // Skip our own app — operating on our container would corrupt the running process.
            if ([bundleID isEqualToString:NSBundle.mainBundle.bundleIdentifier]) continue;

            NSString *displayName = _adk_safe_perform(proxy, @selector(localizedName));
            if (![displayName isKindOfClass:NSString.class] || displayName.length == 0) {
                displayName = _adk_safe_perform(proxy, @selector(itemName));
            }
            if (![displayName isKindOfClass:NSString.class] || displayName.length == 0) {
                displayName = bundleID;
            }

            NSString *shortVersion  = _adk_safe_perform(proxy, @selector(shortVersionString));
            NSString *bundleVersion = _adk_safe_perform(proxy, @selector(bundleVersion));

            NSURL *bundleURL    = _adk_safe_perform(proxy, @selector(bundleURL));
            NSURL *dataURL      = _adk_safe_perform(proxy, @selector(dataContainerURL));
            if (![bundleURL isKindOfClass:NSURL.class]) continue;
            if (dataURL && ![dataURL isKindOfClass:NSURL.class]) dataURL = nil;

            NSString *iconName = nil;
            NSURL *infoURL = [bundleURL URLByAppendingPathComponent:@"Info.plist"];
            NSDictionary *info = [NSDictionary dictionaryWithContentsOfURL:infoURL];
            iconName = _adk_first_icon_name(info);

            ADKApp *app = [[ADKApp alloc] initWithBundleIdentifier:bundleID
                                                       displayName:displayName
                                                      shortVersion:shortVersion
                                                     bundleVersion:bundleVersion
                                                         bundleURL:bundleURL
                                                  dataContainerURL:dataURL
                                               primaryIconFileName:iconName
                                                           appType:type];
            [out addObject:app];
        }
    }

    [out sortUsingComparator:^NSComparisonResult(ADKApp *a, ADKApp *b) {
        return [a.displayName localizedCaseInsensitiveCompare:b.displayName];
    }];
    return out;
}

@end
