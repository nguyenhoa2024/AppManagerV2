#import "ADKAppDelegate.h"
#import "ADKAppListViewController.h"
#import "ADKAppRepository.h"
#import <sys/stat.h>

@implementation ADKAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[ADKAppRepository sharedRepository] loadAppsWithCompletion:nil];

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];

    // Sanity-check zip/unzip — .adbk is a ZIP under the hood and we shell out
    // to /usr/bin/zip + /usr/bin/unzip via posix_spawn.
    struct stat st;
    BOOL hasZip   = (stat("/usr/bin/zip",   &st) == 0);
    BOOL hasUnzip = (stat("/usr/bin/unzip", &st) == 0);
    if (!(hasZip && hasUnzip)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *missing = (!hasZip && !hasUnzip) ? @"/usr/bin/zip and /usr/bin/unzip"
                              : (!hasZip ? @"/usr/bin/zip" : @"/usr/bin/unzip");
            UIAlertController *a = [UIAlertController
                alertControllerWithTitle:@"Backup unavailable"
                                 message:[NSString stringWithFormat:@"%@ is missing on this device. Backup/restore will not work.", missing]
                          preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self.window.rootViewController presentViewController:a animated:YES completion:nil];
        });
    }

    ADKAppListViewController *root = [[ADKAppListViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];

    UINavigationBarAppearance *app = [[UINavigationBarAppearance alloc] init];
    [app configureWithDefaultBackground];
    nav.navigationBar.standardAppearance   = app;
    nav.navigationBar.scrollEdgeAppearance = app;

    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
