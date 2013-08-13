//
//  UCContactListViewController.h
//  UserContacts
//
//  Created by Bradley Griffith on 5/31/13.
//  Copyright (c) 2013 Bradley Griffith. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UCContactListViewController : UIViewController <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong)NSMutableArray *contactList;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@interface NSArray (sortDiacriticalAlphabetical)
- (NSArray *)sortedDiacriticalAlphabetical;
@end
