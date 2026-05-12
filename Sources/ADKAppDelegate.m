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

    // Sanity-check tar before the user hits Backup. Most backup failures we
    // can imagine come from /usr/bin/tar missing or not executable.
    struct stat st;
    if (stat("/usr/bin/tar", &st) != 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *a = [UIAlertController
                alertControllerWithTitle:@"Backup unavailable"
                                 message:@"/usr/bin/tar is missing on this device. Backup/restore will not work."
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
