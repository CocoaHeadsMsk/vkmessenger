//
//  LVKDefaultMessagePhotoItem.m
//  VKMessenger
//
//  Created by Eliah Nikans on 6/9/14.
//  Copyright (c) 2014 Levelab. All rights reserved.
//

#import "LVKDefaultMessagePhotoItem.h"
#import "LVKPhotoAttachment.h"
#import <SDWebImage/UIImageView+WebCache.h>

@implementation LVKDefaultMessagePhotoItem

- (id)initWithFrame:(CGRect)frame
{
    self = [[[NSBundle mainBundle] loadNibNamed:@"LVKDefaultMessagePhotoItem" owner:self options:nil] firstObject];
    if (self) {
        self.frame = frame;
    }
    return self;
}

- (void)awakeFromNib {
    self.layer.cornerRadius = 10;
    self.layer.masksToBounds = YES;
    self.imageWidthConstraint.constant = self.frame.size.width;
}

+ (CGSize)calculateContentSizeWithData:(LVKPhotoAttachment *)_data maxWidth:(CGFloat)_maxWidth minWidth:(CGFloat)_minWidth {
    CGFloat scaleFactor = [_data.width floatValue] / [_data.height floatValue];
    CGFloat _maxHeight = 150.0f;
    CGFloat maxScaleFactor = (CGFloat)_maxWidth / _maxHeight;
    
    // TODO don't stretch
    if (scaleFactor > maxScaleFactor)
        return CGSizeMake(_maxWidth > _minWidth ? _maxWidth : _minWidth, [_data.height floatValue] * (_maxWidth / [_data.width floatValue]));
    CGFloat width = [_data.width floatValue] * (_maxHeight / [_data.height floatValue]);
    return CGSizeMake(width > _minWidth ? width : _minWidth, _maxHeight);
}

- (void)layoutData:(LVKPhotoAttachment *)data {
    [self.image setImageWithURL:[data photo_604]];
}

- (void)dealloc {
    self.image = nil;
}


//- (void)layoutIfNeededForCalculatedWidth:(CGFloat)_width alignRight:(BOOL)_alignRight {
//    CGRect frame = self.frame;
//    frame.size.width = _width;
//    if (_alignRight) {
//        frame.origin.x = 0;
//        NSLog(@"%f %f %f %f", self.frame.origin.x, self.frame.origin.y, self.frame.size.width, self.frame.size.height);
//    }
//    self.frame = frame;
//    NSLog(@"%f %f %f %f", self.frame.origin.x, self.frame.origin.y, self.frame.size.width, self.frame.size.height);
//}

@end
