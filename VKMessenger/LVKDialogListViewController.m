//
//  LVKMasterViewController.m
//  VKMessenger
//
//  Created by Leonid Repin on 03.06.14.
//  Copyright (c) 2014 Levelab. All rights reserved.
//

#import "LVKDialogListViewController.h"
#import "LVKDialogViewController.h"
#import "LVKUserPickerViewController.h"
#import "LVKDialogDeleteAlertDelegate.h"
#import "UIScrollView+BottomRefreshControl.h"
#import <VKSdk.h>
#import <CCBottomRefreshControl/UIScrollView+BottomRefreshControl.h>
#import <UIImageView+WebCache.h>
#import "UIViewController+NetworkNotifications.h"
#import "LVKDialogsCollection.h"
#import "LVKUsersCollection.h"
#import <AudioToolbox/AudioToolbox.h>
#import "LVKLongPoll.h"
#import "LVKDefaultDialogTableViewCell.h"
#import "LVKDefaultUserTableViewCell.h"
#import "LVKAppDelegate.h"
#import "UIImage+JTImageDecode.h"

@interface LVKDialogListViewController () {
    NSMutableArray *_objects, *_filteredObjects;
    NSString *searchString;
    BOOL isLoading;
    BOOL hasDataToLoad;
    UIRefreshControl *topRefreshControl;
    UIRefreshControl *bottomRefreshControl;
    LVKDialogDeleteAlertDelegate *dialogDeleteAlertDelegate;
}
@end



@implementation LVKDialogListViewController

@synthesize tableView, searchBar;



#pragma mark - Lifecycle callbacks

- (void)awakeFromNib
{
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
//        self.clearsSelectionOnViewWillAppear = NO;
//        self.preferredContentSize = CGSizeMake(320.0, 600.0);
//    }
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    
    [self synchronizeListViewSettings];
    
    hasDataToLoad = YES;
    self.isSearching = NO;
    self.avatarsCache = [NSMutableDictionary dictionary];
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.contentOffset = CGPointMake(0, self.searchBar.frame.size.height);

    bottomRefreshControl = [[UIRefreshControl alloc]init];
    [bottomRefreshControl addTarget:self action:@selector(onBottomRefreshControl) forControlEvents:UIControlEventValueChanged];
    [self.tableView setBottomRefreshControl:bottomRefreshControl];
    
    topRefreshControl = [[UIRefreshControl alloc]init];
    [self.tableView addSubview:topRefreshControl];
    [topRefreshControl addTarget:self action:@selector(onTopRefreshControl) forControlEvents:UIControlEventValueChanged];

//    self.detailViewController = (LVKDetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    
    [self registerObservers];
    [self loadData:0];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    [self.avatarsCache removeAllObjects];
    // Dispose of any resources that can be recreated.
}

- (void)appBecomeActive
{
    [self synchronizeListViewSettings];
    [self loadData:0 reload:YES];
}

#pragma mark - Settings
- (void)synchronizeListViewSettings
{
    if([[[NSUserDefaults standardUserDefaults] objectForKey:@"dialog_list_is_compact_preference"] intValue] == 1)
        self.isCompactView = YES;
    else
        self.isCompactView = NO;
}


#pragma mark - Table View Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self getObjects].count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isSearching)
        return 50;
    if (self.isCompactView)
        return 54;
    return 70;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    LVKDialog *dialog = [self getObjects][indexPath.row];
    
    // Searching
    if (self.isSearching) {
        LVKDefaultUserTableViewCell *cell = nil;
        
        cell = [tableView dequeueReusableCellWithIdentifier:@"DefaultUserCell" forIndexPath:indexPath];
        cell.name.text = dialog.title;
        [cell.avatar setImageWithURL:(NSString *)[dialog getChatPicture]];
        
        return cell;
    }
    
    // Displaying
    LVKDefaultDialogTableViewCell *cell = nil;
    
    if (dialog.type == Room || dialog.lastMessage.user == [(LVKAppDelegate *)[[UIApplication sharedApplication] delegate] currentUser])
        if (self.isCompactView)
            cell = [tableView dequeueReusableCellWithIdentifier:@"DefaultCompactDialogCellWithMessageDetails" forIndexPath:indexPath];
        else
            cell = [tableView dequeueReusableCellWithIdentifier:@"DefaultDialogCellWithMessageDetails" forIndexPath:indexPath];

    else if (dialog.type == Dialog)
        if (self.isCompactView)
            cell = [tableView dequeueReusableCellWithIdentifier:@"DefaultCompactDialogCell" forIndexPath:indexPath];
        else
            cell = [tableView dequeueReusableCellWithIdentifier:@"DefaultDialogCell" forIndexPath:indexPath];
    
    cell.title.text = dialog.title;
    if ([dialog.lastMessage.body length])
        cell.message.text = dialog.lastMessage.body;

    cell.isRoom = dialog.type == Room ? YES : NO;

    cell.date.text = [NSDateFormatter localizedStringFromDate:dialog.lastMessage.date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle];

//    [cell.messageAvatar setImage:[UIImage imageNamed:@"camera"]];
    [cell.messageAvatar setImageWithURL:[dialog.lastMessage.user getPhoto:20]];
    [cell ajustLayoutForReadState:dialog.getReadState];
    
    NSString *identifier = [NSString stringWithFormat:@"%@", dialog.chatId];
    cell.identifier = identifier;
    if (self.avatarsCache[identifier] == nil)
        [cell setAvatars:[dialog getChatPictureOfSize:100]];
    else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            UIImage *cachedAvatar = [UIImage decodedImageWithImage:self.avatarsCache[identifier]];

            dispatch_async(dispatch_get_main_queue(), ^{
                cell.avatarsImageView.image = cachedAvatar;
            });
        });
    }
    
//        [cell ajustLayoutUserIsOnline:dialog.user.]
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        LVKDialog *dialog = [[self getObjects] objectAtIndex:indexPath.row];
        VKRequest *deleteDialogRequest = [VKApi requestWithMethod:@"messages.deleteDialog" andParameters:[NSDictionary dictionaryWithObjectsAndKeys:[dialog chatId], [dialog chatIdKey], nil] andHttpMethod:@"GET"];
        
        dialogDeleteAlertDelegate = [[LVKDialogDeleteAlertDelegate alloc] initWithRequest:deleteDialogRequest resultBlock:^(VKResponse *response) {
            [[self getObjects] removeObjectAtIndex:indexPath.row];
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        } errorBlock:^(NSError *error) {
            
        }];
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Удалить диалог %@", [dialog title]]
                                                          message:@"Все сообщения в диалоге будут удалены!"
                                                         delegate:dialogDeleteAlertDelegate
                                                cancelButtonTitle:@"Отмена"
                                                otherButtonTitles:@"Удалить", nil];
        
        [message show];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
//        LVKDialog *object = _objects[indexPath.row];
//        self.detailViewController.dialog = object;
//    }
}



#pragma mark - DialogListVC Delegate

- (void)setImage:(UIImage *)image forIdentifier:(NSString *)identifier {
    self.avatarsCache[identifier] = image;
}



#pragma mark - SearchBar Delegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    searchString = searchText;
    [self loadSearchData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self loadSearchData];
    [searchBar resignFirstResponder];
}



#pragma mark - Scroll view delegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [[self searchBar] endEditing:YES];
}



#pragma mark - Refresh callbacks

- (void)onBottomRefreshControl
{
    if(!isLoading)
        [self loadData:_objects.count];
}

- (void)onTopRefreshControl
{
    if(!isLoading) {
        [self.avatarsCache removeAllObjects];
        [self loadData:0 reload:YES];
    }
}



#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    [searchBar resignFirstResponder];
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        LVKDialog *object = nil;
    
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        object = [self getObjects][indexPath.row];
        
        [[segue destinationViewController] setDialog:object];
    }
    else if ([[segue identifier] isEqualToString:@"pickUsers"]) {
        [(LVKUserPickerViewController *)[[segue destinationViewController] topViewController] setCallerViewController:self];
    }
}



#pragma mark - Networking


- (void)resetMessageFlags:(NSNotification *)notification
{
    LVKLongPollResetMessageFlags *resetMessageFlagsUpdate = [notification object];
    
    NSArray *result = [_objects filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(LVKDialog *dialog, NSDictionary *bindings) {
        return [[dialog lastMessage] _id] == [resetMessageFlagsUpdate messageId];
    }]];
    
    if(result.count == 1)
    {
        LVKDialog *dialog = [result firstObject];
        if([resetMessageFlagsUpdate isUnread])
        {
            [[dialog lastMessage] setIsUnread:NO];
            [tableView reloadData];
        }
    }
}



- (NSArray *)dialogUsersForDialog:(LVKDialog *)dialog
{
    NSMutableArray *userArray = [[NSMutableArray alloc] init];
    
    if([dialog type] == Room)
    {
        [userArray addObjectsFromArray:[dialog users]];
    }
    else if([dialog type] == Dialog)
    {
        [userArray addObject:[dialog user]];
    }
    
    LVKUser *currentUser = [(LVKAppDelegate *)[[UIApplication sharedApplication] delegate] currentUser];
    
    if(currentUser != nil)
    {
        [userArray addObject:currentUser];
    }
    
    return [NSArray arrayWithArray:userArray];
}

- (void)loadUserDataForIdsInArray:(NSArray *)_userIds excludingUsersFromArray:(NSArray *)_userArray withResultBlock:(void (^)(NSArray *))completeBlock
                       errorBlock:(void (^)(NSError *))errorBlock
{
    NSMutableArray *userArray = [NSMutableArray arrayWithArray:_userArray];
    NSMutableArray *userIds = [NSMutableArray arrayWithArray:_userIds];
    
    for (LVKUser *userObject in userArray) {
        if([userObject isCurrent])
        {
            [userIds removeObject:[NSNumber numberWithInt:0]];
        }
        else if([userIds indexOfObject:[userObject _id]] != NSNotFound)
        {
            [userIds removeObject:[userObject _id]];
        }
    }
    
    NSString *userIdsCSV = [userIds componentsJoinedByString:@","];
    
    if([userIdsCSV length] > 0)
    {
        VKRequest *users = [[VKApi users] get:[NSDictionary dictionaryWithObjectsAndKeys:userIdsCSV, @"user_ids", @"photo_50,photo_100,photo_200,photo_400_orig", @"fields", nil]];
        
        users.attempts = 3;
        users.requestTimeout = 3;
        [users executeWithResultBlock:^(VKResponse *response) {
            LVKUsersCollection *usersCollection = [[LVKUsersCollection alloc] initWithArray:response.json];
            
            [userArray addObjectsFromArray:[usersCollection users]];
            
            completeBlock([NSArray arrayWithArray:userArray]);
        } errorBlock:errorBlock];
    }
    else
    {
        completeBlock([NSArray arrayWithArray:userArray]);
    }
}

- (void)receiveNewMessage:(NSNotification *)notification
{
    [self synchronizeListViewSettings];
    
    LVKLongPollNewMessage *newMessageUpdate = [notification object];
    
    NSArray *result = [_objects filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(LVKDialog *dialog, NSDictionary *bindings) {
        return [dialog isEqual:[newMessageUpdate dialog]];
    }]];
    
    if(result.count == 0)
    {
        if([newMessageUpdate dialog].type == Dialog)
        {
            isLoading = YES;
            [self loadUserDataForIdsInArray:[NSArray arrayWithObject:[[newMessageUpdate dialog] chatId]] excludingUsersFromArray:[[NSArray alloc] init] withResultBlock:^(NSArray *userArray) {
                [[newMessageUpdate dialog] adoptUser:[userArray firstObject]];
                
                [_objects insertObject:[newMessageUpdate dialog] atIndex:0];
                
                [self networkRestored];
                [tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
                isLoading = NO;
            } errorBlock:^(NSError *error) {
                if (error.code != VK_API_ERROR)
                {
                    [self networkFailedRequest:error.vkError.request];
                }
                else
                {
                    NSLog(@"%@", error);
                }
                isLoading = NO;
            }];
        }
        else
        {
            [_objects insertObject:[newMessageUpdate dialog] atIndex:0];
            [tableView reloadData];
        }
    }
    else
    {
        [_objects removeObject:[result firstObject]];
        [_objects insertObject:[result firstObject] atIndex:0];
        [[result firstObject] setLastMessage:[newMessageUpdate message]];
        [tableView reloadData];
    }
}

-(NSMutableArray *)getObjects
{
    if ([searchString length] > 0) {
        self.isSearching = YES;
        return _filteredObjects;
    }
    self.isSearching = NO;
    return _objects;
}

- (void)registerObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveNewMessage:)
                                                 name:@"newMessage"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resetMessageFlags:)
                                                 name:@"resetMessageFlags"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appBecomeActive)
                                                 name:@"appBecomeActive"
                                               object:nil];
}

- (void)loadSearchData
{
    [self synchronizeListViewSettings];
    
    NSString *currentSearchString = [NSString stringWithString:searchString];
    
    if(currentSearchString.length > 0)
    {
        if([VKSdk isLoggedIn] && !isLoading)
        {
            isLoading = YES;
            VKRequest *dialogs = [VKApi
                                  requestWithMethod:@"messages.searchDialogs"
                                  andParameters:[NSDictionary dictionaryWithObjectsAndKeys:currentSearchString, @"q", nil]
                                  andHttpMethod:@"GET"];
            dialogs.attempts = 2;
            dialogs.requestTimeout = 5;
            [dialogs executeWithResultBlock:^(VKResponse *response) {
                LVKDialogsCollection *dialogsCollection = [[LVKDialogsCollection alloc] initWithArray:response.json];
                
                [self loadUserDataForIdsInArray:[dialogsCollection getUserIds] excludingUsersFromArray:[[NSArray alloc] init] withResultBlock:^(NSArray *userArray) {
                    
                    [dialogsCollection adoptUserCollection:[[LVKUsersCollection alloc] initWithUserArray:userArray]];
                    
                    _filteredObjects = [NSMutableArray arrayWithArray:[dialogsCollection dialogs]];
                    
                    if(![searchString isEqual:currentSearchString])
                    {
                        [self performSelector:@selector(loadSearchData) withObject:0 afterDelay:1];
                    }
                    
                    [self networkRestored];
                    [tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
                    isLoading = NO;
                } errorBlock:^(NSError *error) {
                    if (error.code != VK_API_ERROR)
                    {
                        [self networkFailedRequest:error.vkError.request];
                    }
                    else
                    {
                        NSLog(@"%@", error);
                    }
                    [self performSelector:@selector(loadSearchData) withObject:0 afterDelay:2];
                    isLoading = NO;
                }];
                
                
            } errorBlock:^(NSError *error) {
                if (error.code != VK_API_ERROR)
                {
                    [self networkFailedRequest:error.vkError.request];
                }
                else
                {
                    NSLog(@"%@", error);
                }
                [self performSelector:@selector(loadSearchData) withObject:0 afterDelay:2];
                isLoading = NO;
            }];
        }
    }
    else
    {
        [tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
    }
}

- (void)loadData:(NSUInteger)offset
{
    [self loadData:offset reload:NO];
}

- (void)loadData:(NSUInteger)offset reload:(BOOL)reload
{
    [self synchronizeListViewSettings];
    
    if(!hasDataToLoad && !reload)
    {
        [bottomRefreshControl endRefreshing];
        return;
    }
    if([VKSdk isLoggedIn])
    {
        isLoading = YES;
        VKRequest *dialogs = [VKApi
                              requestWithMethod:@"messages.getDialogs"
                              andParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"30", @"count", [NSNumber numberWithUnsignedInteger:offset], @"offset", nil]
                              andHttpMethod:@"GET"];
        dialogs.attempts = 3;
        dialogs.requestTimeout = 3;
        [dialogs executeWithResultBlock:^(VKResponse *response) {
            LVKDialogsCollection *dialogsCollection = [[LVKDialogsCollection alloc] initWithDictionary:response.json];
            
            [self loadUserDataForIdsInArray:[dialogsCollection getUserIds] excludingUsersFromArray:[[NSArray alloc] init] withResultBlock:^(NSArray *userArray) {
                
                [dialogsCollection adoptUserCollection:[[LVKUsersCollection alloc] initWithUserArray:userArray]];
                
                if(_objects.count == 0 || reload)
                {
                    _objects = [NSMutableArray arrayWithArray:[dialogsCollection dialogs]];
                }
                else if(offset == _objects.count)
                {
                    [_objects addObjectsFromArray:[dialogsCollection dialogs]];
                }
                
                [self networkRestored];
                [tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
                isLoading = NO;
                [bottomRefreshControl performSelectorOnMainThread:@selector(endRefreshing) withObject:nil waitUntilDone:NO];
                [topRefreshControl performSelectorOnMainThread:@selector(endRefreshing) withObject:nil waitUntilDone:NO];
                
                if(_objects.count >= [[dialogsCollection count] intValue])
                {
                    hasDataToLoad = NO;
                    [bottomRefreshControl performSelectorOnMainThread:@selector(removeFromSuperview) withObject:nil waitUntilDone:NO];
                }
            } errorBlock:^(NSError *error) {
                if (error.code != VK_API_ERROR)
                {
                    [self networkFailedRequest:error.vkError.request];
                }
                else
                {
                    NSLog(@"%@", error);
                }
                isLoading = NO;
                [bottomRefreshControl performSelectorOnMainThread:@selector(endRefreshing) withObject:nil waitUntilDone:NO];
                [topRefreshControl performSelectorOnMainThread:@selector(endRefreshing) withObject:nil waitUntilDone:NO];
            }];
        } errorBlock:^(NSError *error) {
            if (error.code != VK_API_ERROR)
            {
                [self networkFailedRequest:error.vkError.request];
            }
            else
            {
                NSLog(@"%@", error);
            }
            isLoading = NO;
            [bottomRefreshControl performSelectorOnMainThread:@selector(endRefreshing) withObject:nil waitUntilDone:YES];
            [topRefreshControl performSelectorOnMainThread:@selector(endRefreshing) withObject:nil waitUntilDone:YES];
        }];
    }
}

@end
