//
//  UCContactListTableViewContactCell.h
//  UserContacts
//
//  Created by Bradley Griffith on 5/31/13.
//  Copyright (c) 2013 Bradley Griffith. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UCContactListTableViewContactCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *contactName;
@property (weak, nonatomic) IBOutlet UIImageView *contactImageView;
@property (weak, nonatomic) IBOutlet UILabel *selectionCheckMark;

@end
