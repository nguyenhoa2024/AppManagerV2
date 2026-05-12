#import "ADKSettingsViewController.h"
#import "ADKBackupManager.h"
#import "ADKFileSystem.h"
#import "ADKByteFormatter.h"

typedef NS_ENUM(NSInteger, ADKSettingsSection) {
    ADKSettingsSectionBackups = 0,
    ADKSettingsSectionStorage = 1,
    ADKSettingsSectionAbout   = 2,
    ADKSettingsSectionCount
};

@interface ADKSettingsViewController ()
@property (nonatomic, strong) UIStepper *stepper;
@end

@implementation ADKSettingsViewController

- (instancetype)init
{
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Settings";
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                       target:self
                                                       action:@selector(_dismiss)];
    // Cells are constructed manually with the right style per row.
}

- (void)_dismiss { [self dismissViewControllerAnimated:YES completion:nil]; }

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t
{
    return ADKSettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s
{
    switch (s) {
        case ADKSettingsSectionBackups: return 1;
        case ADKSettingsSectionStorage: return 2;
        case ADKSettingsSectionAbout:   return 2;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s
{
    switch (s) {
        case ADKSettingsSectionBackups: return @"Backups";
        case ADKSettingsSectionStorage: return @"Storage";
        case ADKSettingsSectionAbout:   return @"About";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s
{
    if (s == ADKSettingsSectionBackups) {
        return @"Older backups beyond the cap are deleted automatically when a new backup is created. 0 means unlimited.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip
{
    // Each row uses Value1 so the detail text appears on the right.
    NSString *reuseID = @"SettingsValue1";
    UITableViewCell *cell = [t dequeueReusableCellWithIdentifier:reuseID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseID];
    }
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.numberOfLines = 1;
    cell.detailTextLabel.text = nil;

    if (ip.section == ADKSettingsSectionBackups) {
        cell.textLabel.text = [NSString stringWithFormat:@"Max per app: %ld", (long)[ADKBackupManager sharedManager].maxBackupsPerApp];
        if (!self.stepper) {
            self.stepper = [[UIStepper alloc] init];
            self.stepper.minimumValue = 0;
            self.stepper.maximumValue = 50;
            self.stepper.stepValue = 1;
            self.stepper.value = (double)[ADKBackupManager sharedManager].maxBackupsPerApp;
            [self.stepper addTarget:self action:@selector(_stepperChanged:) forControlEvents:UIControlEventValueChanged];
        }
        cell.accessoryView = self.stepper;
        return cell;
    }
    if (ip.section == ADKSettingsSectionStorage) {
        if (ip.row == 0) {
            unsigned long long bytes = [ADKFileSystem recursiveSizeAtURL:[ADKFileSystem backupsDirectory]];
            cell.textLabel.text = @"Backups folder size";
            cell.detailTextLabel.text = [ADKByteFormatter stringFromBytes:bytes];
        } else {
            cell.textLabel.text = @"Reveal Backups Folder Path";
            cell.textLabel.textColor = UIColor.systemBlueColor;
        }
        return cell;
    }
    if (ip.section == ADKSettingsSectionAbout) {
        if (ip.row == 0) {
            cell.textLabel.text = @"Version";
            cell.detailTextLabel.text = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"";
        } else {
            cell.textLabel.text = @"AppDataKit is an open-source TrollStore utility.";
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
            cell.textLabel.textColor = UIColor.secondaryLabelColor;
        }
        return cell;
    }
    return cell;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [t deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == ADKSettingsSectionStorage && ip.row == 1) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Backups Folder"
                                                                   message:[ADKFileSystem backupsDirectory].path
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
}

- (void)_stepperChanged:(UIStepper *)s
{
    [ADKBackupManager sharedManager].maxBackupsPerApp = (NSInteger)s.value;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:ADKSettingsSectionBackups]
                  withRowAnimation:UITableViewRowAnimationNone];
}

@end
