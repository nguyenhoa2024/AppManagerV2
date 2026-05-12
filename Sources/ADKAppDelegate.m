#import "ADKAppDelegate.h"
#import "ADKAppListViewController.h"
#import "ADKAppRepository.h"

@implementation ADKAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Kick the scan immediately so it's likely warm by the time the user sees the table.
    [[ADKAppRepository sharedRepository] loadAppsWithCompletion:nil];

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];

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
