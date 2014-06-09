//
//  LVKMessageItemProtocole.h
//  VKMessengerViews
//
//  Created by Eliah Nikans on 6/4/14.
//  Copyright (c) 2014 Levelab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LVKMessagePartProtocol.h"

@protocol LVKMessageItemProtocol <NSObject>

//@property (nonatomic) int maxWidth;

//- (int)contentWidth;
//- (CGSize)calculateContentSize;
@required
+ (CGSize)calculateContentSizeWithData:(id<LVKMessagePartProtocol>)_data maxWidth:(CGFloat)_maxWidth;

@optional
- (void)layoutIfNeededForCalculatedWidth:(CGFloat)_width;

@end
