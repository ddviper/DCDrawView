//
//  DCUndoBeziPathPaintBoard.h
//  DCPaintBoard
//
//  Created by Wade on 16/4/26.
//  Copyright © 2016年 Wade. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DCUndoBeziPathPaintBoard : UIView
/**
 *  画线的颜色
 */
@property (nonatomic, strong) UIColor *lineColor;
/**
 *  是否是橡皮擦状态
 */
@property (nonatomic, assign) BOOL isErase;
/**
 *  清楚画笔
 */
- (void)clear;
@end
