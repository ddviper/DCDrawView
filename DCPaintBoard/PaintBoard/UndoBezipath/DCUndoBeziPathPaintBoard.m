//
//  DCUndoBeziPathPaintBoard.m
//  DCPaintBoard
//
//  Created by Wade on 16/4/26.
//  Copyright © 2016年 Wade. All rights reserved.
//

#import "DCUndoBeziPathPaintBoard.h"
#import "DCCommon.h"

@interface DCUndoBeziPathPaintBoard()
// 存储正在画的点
@property (strong, nonatomic) NSMutableArray *pointsArrM;
//正在画的所有的点集合
@property (strong, nonatomic) NSMutableArray *linesArrM;
// 存储所有路径
@property (strong, nonatomic) NSMutableDictionary *pathsDictM;




@property (nonatomic, strong) NSUndoManager *undoManager;
@property (nonatomic, assign)  CGPoint currentPoint;
@property (nonatomic, assign) CGPoint previousPoint1;
@property (nonatomic, assign) CGPoint previousPoint2;
@property (nonatomic, strong) UIImage *curImage;
@property (nonatomic, assign) CGContextRef context;
@property (nonatomic, assign) BOOL isSeachPoints;

@property (nonatomic, assign) CGFloat lineWidth;

-(void)undo;
- (UIImage *)imageRepresentation;


@end


@implementation DCUndoBeziPathPaintBoard
@synthesize undoManager;
- (NSMutableArray *)linesArrM
{
    if (!_linesArrM) {
        _linesArrM = [NSMutableArray array];
    }
    return _linesArrM;
}


- (NSMutableArray *)pointsArrM
{
    if (!_pointsArrM) {
        _pointsArrM = [NSMutableArray array];
    }
    return _pointsArrM;
}

- (NSMutableDictionary *)pathsDictM
{
    if (!_pathsDictM) {
        _pathsDictM = [NSMutableDictionary dictionary];
    }
    return _pathsDictM;
}

- (void)setIsErase:(BOOL)isErase
{
    _isErase = isErase;
    self.lineWidth = isErase?kEraseLineWidth:kLineWidth;
}

- (void)awakeFromNib{
    [self setup];
}

// 画笔的初始化设置
-(void)setup
{
    self.multipleTouchEnabled = YES;
    self.lineWidth = 5;

    self.lineColor =[UIColor blackColor];
    
    NSUndoManager *tempUndoManager = [[NSUndoManager alloc] init];
    [tempUndoManager setLevelsOfUndo:10];
    [self setUndoManager:tempUndoManager];
}

- (UIImage *)imageRepresentation
{
    UIGraphicsBeginImageContext(self.bounds.size);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image= UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// 重写了undo方法
-(void)undo
{
    if ([self.undoManager canUndo])
    {
        [self.undoManager undo];
        NSData *data;
        if (UIImagePNGRepresentation(self.curImage) == nil)
            data = UIImageJPEGRepresentation(self.curImage, 1);
        else
            data = UIImagePNGRepresentation(self.curImage);
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);//程序文件夹主目录
        NSString *documentsDirectory = [paths objectAtIndex:0];//Document目录
        static int i =1;
        [fileManager createFileAtPath:[documentsDirectory stringByAppendingString:[NSString stringWithFormat:@"/image%d.png",i++]] contents:data attributes:nil];
        self.previousPoint1=CGPointMake(0, 0);
        self.previousPoint2=CGPointMake(0, 0);
        self.currentPoint = CGPointMake(0, 0);
        [self setNeedsDisplay];
    }
}

// 清楚画面和存储的数据
-(void)clear
{
    //    [self setImage:nil];
    self.previousPoint1=CGPointMake(0, 0);
    self.previousPoint2=CGPointMake(0, 0);
    self.currentPoint = CGPointMake(0, 0);
    [self setNeedsDisplay];
}


// 计算中间点
CGPoint midPoint1(CGPoint p1, CGPoint p2)
{
    return CGPointMake((p1.x + p2.x) * 0.5, (p1.y + p2.y) * 0.5);
}

#pragma mark -touchesBegan方法
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    //    [[self.undoManager prepareWithInvocationTarget:self] setImage:[self imageRepresentation]];
    
    UITouch *touch = [touches anyObject];
    
    CGPoint currentPoint = [touch locationInView:self];
    
    self.previousPoint1 = [touch locationInView:self];
    self.previousPoint2 = [touch locationInView:self];
    self.currentPoint = [touch locationInView:self];
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, self.previousPoint1.x, self.previousPoint1.y);
    
  
    [self.pointsArrM removeAllObjects];
    // 添加点集合
    NSDictionary *dict = @{@"x":@(currentPoint.x),@"y":@(currentPoint.y)};
    [self.pointsArrM addObject:dict];
}

#pragma mark -touchesMoved方法
-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch  = [touches anyObject];
    
    CGPoint currentPoint    = [touch locationInView:self];
    self.previousPoint2  = self.previousPoint1;
    self.previousPoint1  = [touch previousLocationInView:self];
    self.currentPoint    = [touch locationInView:self];
    
    CGPoint mid1    = midPoint1(self.previousPoint1, self.previousPoint2);
    CGPoint mid2    = midPoint1(self.currentPoint, self.previousPoint1);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, mid1.x, mid1.y);
    CGPathAddQuadCurveToPoint(path, NULL, self.previousPoint1.x, self.previousPoint1.y, mid2.x, mid2.y);
    
    CGRect bounds = CGPathGetBoundingBox(path);
    CGPathRelease(path);
    CGRect drawBox = bounds;
    
    //Pad our values so the bounding box respects our line width
    drawBox.origin.x        -= self.lineWidth * 2;
    drawBox.origin.y        -= self.lineWidth * 2;
    drawBox.size.width      += self.lineWidth * 4;
    drawBox.size.height     += self.lineWidth * 4;
    
    UIGraphicsBeginImageContext(drawBox.size);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    self.curImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [self setNeedsDisplayInRect:drawBox];
    //
    NSDictionary *dict = @{@"x":@(currentPoint.x),@"y":@(currentPoint.y)};
    
    [self.pointsArrM addObject:dict];
}


#pragma mark -touchesEnded方法
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    //     if([touches count] >= 2)return;
    UITouch *touch  = [touches anyObject];
    CGPoint currentPoint    = [touch locationInView:self];
    NSDictionary *dict = @{@"x":@(currentPoint.x),@"y":@(currentPoint.y)};
    self.previousPoint2  = self.previousPoint1;
    self.previousPoint1  = [touch previousLocationInView:self];
    self.currentPoint    = [touch locationInView:self];
    
    CGPoint mid1    = midPoint1(self.previousPoint1, self.previousPoint2);
    CGPoint mid2    = midPoint1(self.currentPoint, self.previousPoint1);
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, mid1.x, mid1.y);
    CGPathAddQuadCurveToPoint(path, NULL, self.previousPoint1.x, self.previousPoint1.y, mid2.x, mid2.y);
    
    //绘画
    CGRect bounds = CGPathGetBoundingBox(path);
    CGPathRelease(path);
    CGRect drawBox = bounds;
    
    //Pad our values so the bounding box respects our line width
    drawBox.origin.x        -= self.lineWidth * 2;
    drawBox.origin.y        -= self.lineWidth * 2;
    drawBox.size.width      += self.lineWidth * 4;
    drawBox.size.height     += self.lineWidth * 4;
    
    UIGraphicsBeginImageContext(drawBox.size);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    self.curImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [self setNeedsDisplayInRect:drawBox];
    
    [self.pointsArrM addObject:dict];

    
}

#pragma mark - 绘画方法
- (void)drawRect:(CGRect)rect
{
    //获取上下文
    [self.curImage drawAtPoint:CGPointMake(0, 0)];
    CGPoint mid1 = midPoint1(self.previousPoint1, self.previousPoint2);
    CGPoint mid2 = midPoint1(self.currentPoint, self.previousPoint1);
    
    //
    self.context = UIGraphicsGetCurrentContext();
    
    [self.layer renderInContext:self.context];
    
    CGContextMoveToPoint(self.context, mid1.x, mid1.y);
    
    // CGPathAddQuadCurveToPoint
    CGContextAddQuadCurveToPoint(self.context, self.previousPoint1.x, self.previousPoint1.y, mid2.x, mid2.y);
    
    CGContextSetLineCap(self.context, kCGLineCapRound);
    
    CGContextSetLineWidth(self.context, self.isErase? kEraseLineWidth:kLineWidth);
    
    CGContextSetStrokeColorWithColor(self.context, self.isErase?[UIColor clearColor].CGColor:self.lineColor.CGColor);
    
    CGContextSetLineJoin(self.context, kCGLineJoinRound);
    
    CGContextSetBlendMode(self.context, self.isErase ? kCGBlendModeDestinationIn:kCGBlendModeNormal);
    
    CGContextStrokePath(self.context);
    
    [super drawRect:rect];
}


@end
