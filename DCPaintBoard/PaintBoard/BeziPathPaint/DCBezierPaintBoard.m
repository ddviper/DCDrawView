//
//  DCBezierPaintBoard.m
//  DCPaintBoard
//
//  Created by Wade on 16/4/25.
//  Copyright © 2016年 Wade. All rights reserved.
//

#import "DCBezierPaintBoard.h"
#import "DCCommon.h"
#import "DCBeizierPath.h"


@interface DCBezierPaintBoard()
@property (nonatomic, strong) NSMutableArray *beziPathArrM;

@property (nonatomic, strong)  DCBeizierPath *beziPath;
@end

@implementation DCBezierPaintBoard

- (NSMutableArray *)beziPathArrM{
    if (!_beziPathArrM) {
        _beziPathArrM  = [NSMutableArray array];
    }
    return _beziPathArrM;
}

- (void)setIsErase:(BOOL)isErase{
    _isErase  = isErase;
    NSLog(@"setIsErase--%d",isErase);
}


#pragma mark - touch方法
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch *touch = [touches anyObject];
    
    CGPoint currentPoint = [touch locationInView:self];
//    NSLog(@"touchesBegan--%@",NSStringFromCGPoint(currentPoint));
      self.beziPath = [[DCBeizierPath alloc] init];
    self.beziPath.lineColor = self.lineColor;
    self.beziPath.isErase = self.isErase;
    [self.beziPath moveToPoint:currentPoint];
    
     [self.beziPathArrM addObject:self.beziPath];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    UITouch *touch = [touches anyObject];
    
    CGPoint currentPoint = [touch locationInView:self];
    CGPoint previousPoint = [touch previousLocationInView:self];
//       NSLog(@"touchesMoved--%@",NSStringFromCGPoint(currentPoint));
    
    CGPoint midP = midPoint(previousPoint,currentPoint);
    
    [self.beziPath addQuadCurveToPoint:currentPoint controlPoint:midP];

   [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    UITouch *touch = [touches anyObject];
    
    CGPoint currentPoint = [touch locationInView:self];
    CGPoint previousPoint = [touch previousLocationInView:self];
    
//       NSLog(@"touchesEnded--%@",NSStringFromCGPoint(currentPoint));
    
    CGPoint midP = midPoint(previousPoint,currentPoint);
    
    [self.beziPath addQuadCurveToPoint:currentPoint controlPoint:midP];
   
    [self setNeedsDisplay];

}


// 计算中间点
CGPoint midPoint(CGPoint p1, CGPoint p2)
{
    return CGPointMake((p1.x + p2.x) * 0.5, (p1.y + p2.y) * 0.5);
}

#pragma mark - 绘画方法
- (void)drawRect:(CGRect)rect
{
    //获取上下文
    if(self.beziPathArrM.count){
        for (DCBeizierPath *path  in self.beziPathArrM) {
            if (path.isErase) {
                [[UIColor clearColor] setStroke];
            }else{
                [path.lineColor setStroke];
            }
            
            path.lineJoinStyle = kCGLineJoinRound;
            path.lineCapStyle = kCGLineCapRound;
            if (path.isErase) {
                path.lineWidth = kEraseLineWidth;
                [path strokeWithBlendMode:kCGBlendModeCopy alpha:1.0];
            } else {
                path.lineWidth = kLineWidth;
                [path strokeWithBlendMode:kCGBlendModeNormal alpha:1.0];
            }
            [path stroke];
        }
    }
    
    [super drawRect:rect];
}

- (void)clear{

}

@end
