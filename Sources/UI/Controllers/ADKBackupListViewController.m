#import "ADKBackupListViewController.h"
#import "ADKBackup.h"
#import "ADKBackupManager.h"
#import "ADKRestoreManager.h"
#import "ADKByteFormatter.h"
#import "ADKAppRepository.h"

@interface ADKBackupListViewController ()
@property (nonatomic, strong) ADKApp *app;
@property (nonatomic, copy) NSArray<ADKBackup *> *backups;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation ADKBackupListViewController

- (instancetype)initWithApp:(ADKApp *)app
{
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _app = app;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Backups";

    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    self.dateFormatter.timeStyle = NSDateFormatterShortStyle;

    // Don't registerClass: we need a Value1 style cell, which means manual alloc/init.
    [self _reload];
}

- (void)_reload
{
    self.backups = [[ADKBackupManager sharedManager] backupsForBundleID:self.app.bundleIdentifier];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s
{
    return (NSInteger)self.backups.count;
}

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s
{
    return [NSString stringWithFormat:@"%@ — %lu backup%@",
                                       self.app.displayName,
                                       (unsigned long)self.backups.count,
                                       self.backups.count == 1 ? @"" : @"s"];
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip
{
    UITableViewCell *cell = [t dequeueReusableCellWithIdentifier:@"BackupCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:@"BackupCell"];
    }
    ADKBackup *b = self.backups[(NSUInteger)ip.row];
    cell.textLabel.text = [self.dateFormatter stringFromDate:b.createdAt];
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.detailTextLabel.text = [ADKByteFormatter stringFromBytes:b.fileSize];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [t deselectRowAtIndexPath:ip animated:YES];
    ADKBackup *b = self.backups[(NSUInteger)ip.row];
    [self _confirmRestore:b];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)t trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)ip
{
    ADKBackup *b = self.backups[(NSUInteger)ip.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                       title:@"Delete"
                                                                     handler:^(UIContextualAction *_, __kindof UIView *_, void (^completion)(BOOL)) {
        [[ADKBackupManager sharedManager] removeBackup:b error:NULL];
        [weakSelf _reload];
        completion(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[del]];
}

- (void)_confirmRestore:(ADKBackup *)b
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Restore"
                                                                   message:[NSString stringWithFormat:@"Replace %@'s current data with this backup?", self.app.displayName]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *_) {
        [self _performRestore:b];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)_performRestore:(ADKBackup *)b
{
    UIAlertController *spin = [UIAlertController alertControllerWithTitle:@"Restoring…"
                                                                  message:@"\n\n"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:spin animated:YES completion:^{
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *err = nil;
            BOOL ok = [[ADKRestoreManager sharedManager] restoreBackup:b forApp:self.app error:&err];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[ADKAppRepository sharedRepository] invalidateSizeForApp:self.app];
                [spin dismissViewControllerAnimated:YES completion:^{
                    [self _showResult:ok error:err];
                }];
            });
        });
    }];
}

- (void)_showResult:(BOOL)ok error:(NSError *)err
{
    UIAlertController *a = [UIAlertController
        alertControllerWithTitle:ok ? @"Restored" : @"Restore Failed"
                         message:ok ? @"App data was replaced from the backup."
                                    : (err.localizedDescription ?: @"Unknown error.")
                  preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        if (ok) [self.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
