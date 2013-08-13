//
//  UCContactListViewController.m
//  UserContacts
//
//  Created by Bradley Griffith on 5/31/13.
//  Copyright (c) 2013 Bradley Griffith. All rights reserved.
//

#import "UCContactListViewController.h"
#import "UCContactListTableViewContactCell.h"

#import <QuartzCore/QuartzCore.h>
#import <AddressBook/AddressBook.h>

@interface UCContactListViewController (){
    BOOL retina;
    BOOL isFiltered;
    NSString *searchString;
    NSDictionary *sortedContacts;
    NSArray *nameIndex;
    NSMutableArray *selectedContacts;
}
@property (nonatomic, strong)NSMutableDictionary *imageCache;
@end

@implementation UCContactListViewController
@synthesize tableView = _tableview;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    retina = NO;
    if([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
        retina = [[UIScreen mainScreen] scale] == 2.0 ? YES : NO;
    
    selectedContacts = [[NSMutableArray alloc] init];
    
    [self sortcontacts:_contactList];
}


- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self dismissKeyboard];
}

- (NSMutableDictionary *)imageCache {
    if (!_imageCache) {
        _imageCache = [NSMutableDictionary dictionary];
    }
    return _imageCache;
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)scrollToTop {
    //[self.tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                          atScrollPosition:UITableViewScrollPositionTop animated:YES];
}

#pragma mark - Table view data source


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [nameIndex count];
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSString *key = [nameIndex objectAtIndex:section];
    NSArray *contactsForKey = [sortedContacts objectForKey:key];
    return [contactsForKey count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    return [[nameIndex objectAtIndex:section] uppercaseString];
    
}

/*
 // Uncomment this to make the table view display the index on the right side of the screen.
 - (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
 return nameIndex;
 }
 */

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ContactCell";
    UCContactListTableViewContactCell *cell = (UCContactListTableViewContactCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSString *key = [nameIndex objectAtIndex:indexPath.section];
    NSArray *contactsForKey = [sortedContacts objectForKey:key];
    NSDictionary *contact = [contactsForKey objectAtIndex:indexPath.row];
    
    UIImage *defaultPhoto = [UIImage imageNamed:@"facebook_avatar.png"];
    UIImage *contactImage = [_imageCache valueForKey:contact[@"id"]];
    cell.contactImageView.contentMode = UIViewContentModeCenter;
    cell.contactImageView.layer.masksToBounds = YES;
    cell.contactImageView.layer.cornerRadius = 3.0;
    if (contactImage) {
        cell.contactImageView.image = contactImage;  // this is the best scenario: cached image
    } else {
        // Use default image and asynchronously load and cache the actual image.
        [self asynchSetImageForUser:contact atIndex:indexPath];
        cell.contactImageView.image = defaultPhoto;
    }
    
    NSMutableAttributedString *styledName = [self highlightSubstring:searchString inString:contact[@"name"]];
    cell.contactName.attributedText = styledName;
    
    cell.selectionCheckMark.hidden = [selectedContacts containsObject:contact[@"id"]] ? NO : YES;

    return cell;
}

- (void)asynchSetImageForUser:(NSDictionary *)contact atIndex:(NSIndexPath *)indexPath {
    
    dispatch_queue_t queue = dispatch_queue_create("yakamoto.UserContacts", NULL);
    dispatch_queue_t main = dispatch_get_main_queue();
    
    dispatch_async(queue, ^{
        
        ABAddressBookRef addressBookRef = ABAddressBookCreateWithOptions(NULL, NULL);
        ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBookRef, [contact[@"id"] intValue]);
        
        NSData *imgData = (__bridge_transfer NSData *)ABPersonCopyImageDataWithFormat(person, kABPersonImageFormatThumbnail);
        
        UIImage *image = [UIImage imageWithData:imgData];
        
        if (retina) {
            // Scale for retina.
            image = [UIImage imageWithCGImage:[image CGImage] scale:2.0 orientation:UIImageOrientationUp];
        }
        
        if (image) {
            [self.imageCache setValue:image forKey:contact[@"id"]];
        }
        
        dispatch_sync(main, ^{
            NSArray *visiblePaths = [self.tableView indexPathsForVisibleRows];
            if ([visiblePaths containsObject:indexPath]) {
                NSArray *indexPaths = [NSArray arrayWithObject:indexPath];
                
                [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];
                // because we cached the image, cellForRow... will see it and run fast
            }
        });
        CFRelease(addressBookRef);
    });
}

- (void)sortcontacts:(NSArray *)contacts {
    // Sorts users into a dictionary of alphabetical sections.
    NSArray *extractedNames = [contacts valueForKey:@"name"];
    contacts = extractedNames.copy;
    
    if (!isFiltered)
        contacts = [extractedNames sortedDiacriticalAlphabetical];
    
    NSMutableDictionary *sectioned = [NSMutableDictionary dictionary];
    NSString *firstChar = nil;
    NSMutableArray *keys = [NSMutableArray array];
    
    for(NSString *contactName in contacts) {
        if(![contactName length])continue;
        
        NSMutableArray *names = nil;
        firstChar = [[[contactName decomposedStringWithCanonicalMapping] substringToIndex:1] uppercaseString];
        
        if (!(names = [sectioned objectForKey:firstChar])) {
            names = [NSMutableArray array];
            [sectioned setObject:names forKey:firstChar];
            [keys addObject:firstChar];
        }
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name = %@", contactName];
        NSArray *matchedDicts = [_contactList filteredArrayUsingPredicate:predicate];
        
        // TODO: This might be bad... make sure this isnt dropping people that share names or anything.
        [names addObject:matchedDicts[0]];
    }
    
    sortedContacts = sectioned.copy;
    if (isFiltered) {
        // Keep keys in order of names returned by search function.
        nameIndex = keys;
    }
    else {
        // Arrange keys alphabetically.
        nameIndex = [keys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    }
    
}

- (NSMutableAttributedString *)highlightSubstring:(NSString *)subString inString:(NSString *)containerString {
    NSMutableAttributedString *styledString = [[NSMutableAttributedString alloc] initWithString:containerString];
    
    if (subString && containerString) {
        
        CGFloat fontSize = 17;
        UIFont *boldFont = [UIFont boldSystemFontOfSize:fontSize];
        
        NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                               boldFont, NSFontAttributeName, nil];
        NSRange range = [containerString rangeOfString:subString
                                               options:(NSCaseInsensitiveSearch+NSDiacriticInsensitiveSearch)];
        
        
        [styledString addAttributes:attrs range:range];
    }
    
    return styledString;
}

#pragma mark - SearchBar Delegate

-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    searchString = searchText.copy;
    
    NSArray *searchedUsers;
    if (searchString.length > 0) {
        NSArray *extractedNames = [_contactList valueForKey:@"name"];
        
        isFiltered = YES;
        NSArray *sorted = [extractedNames sortedDiacriticalAlphabetical];
        
        // Find and build array of all users whos names contain the search string, giving priority to names
        // that begin with the search text.
        NSMutableArray *foundInFirstname = [[NSMutableArray alloc] init];
        NSMutableArray *foundInName = [[NSMutableArray alloc] init];
        for (NSString *name in sorted) {
            NSRange range = [name rangeOfString:searchText
                                        options:(NSCaseInsensitiveSearch+NSDiacriticInsensitiveSearch+NSAnchoredSearch)];
            if (range.length > 0) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name = %@", name];
                NSArray *matchedDicts = [_contactList filteredArrayUsingPredicate:predicate];
                
                // TODO: This might be bad... make sure this isnt dropping people that share names or anything.
                [foundInFirstname addObject:matchedDicts[0]];
            }
            else {
                range = [name rangeOfString:searchText
                                    options:NSCaseInsensitiveSearch+NSDiacriticInsensitiveSearch];
                if (range.length > 0) {
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name = %@", name];
                    NSArray *matchedDicts = [_contactList filteredArrayUsingPredicate:predicate];
                    
                    // TODO: This might be bad... make sure this isnt dropping people that share names or anything.
                    [foundInName addObject:matchedDicts[0]];
                }
            }
        }
        searchedUsers = [foundInFirstname arrayByAddingObjectsFromArray:foundInName];
    }
    else {
        isFiltered = NO;
        searchedUsers = _contactList;
    }
    [self sortcontacts:searchedUsers];
    
    [self.tableView reloadData];
    //[self scrollToTop];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self dismissKeyboard];
    
    NSString *key = [nameIndex objectAtIndex:indexPath.section];
    NSArray *contactsForKey = [sortedContacts objectForKey:key];
    NSDictionary *contact = [contactsForKey objectAtIndex:indexPath.row];
    
    UCContactListTableViewContactCell *cell = (UCContactListTableViewContactCell *)[tableView cellForRowAtIndexPath:indexPath];
    
    if ([selectedContacts containsObject:contact[@"id"]]) {
        [selectedContacts removeObject:contact[@"id"]];
        cell.selectionCheckMark.hidden = YES;
    }
    else {
        [selectedContacts addObject:contact[@"id"]];
        cell.selectionCheckMark.hidden = NO;
    }
    NSLog(@"%@",contact[@"id"]);
}

@end

@implementation NSArray (sortDiacriticalAlphabetical)

- (NSArray *)sortedDiacriticalAlphabetical {
    NSArray *sorted = [self sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [(NSString*)obj1 compare:obj2 options:NSDiacriticInsensitiveSearch+NSCaseInsensitiveSearch];
    }];
    return sorted;
}

@end