//
//  UIView+Frame.h
//  DCPaintBoard
//
//  Created by Wade on 16/4/28.
//  Copyright © 2016年 Wade. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (Frame)
@property (nonatomic, assign) CGFloat x;
@property (nonatomic, assign) CGFloat y;
@property (nonatomic, assign) CGFloat centerX;
@property (nonatomic, assign) CGFloat centerY;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGSize size;
@property (nonatomic, assign) CGFloat maxX;
@property (nonatomic, assign) CGFloat MaxY;

@end
