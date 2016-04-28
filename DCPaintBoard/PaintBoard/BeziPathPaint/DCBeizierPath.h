//
//  DCBeizierPath.h
//  DCPaintBoard
//
//  Created by Wade on 16/4/26.
//  Copyright © 2016年 Wade. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DCBeizierPath : UIBezierPath
@property (nonatomic,copy) UIColor *lineColor;
@property (nonatomic,assign) BOOL isErase;

@end
