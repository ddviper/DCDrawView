//
//  ViewController.m
//  DCPaintBoard
//
//  Created by Wade on 16/4/25.
//  Copyright © 2016年 Wade. All rights reserved.
//

#import "ViewController.h"
#import "DCCommon.h"
#import "DCBezierPaintBoard.h"
#import "DCUndoBeziPathPaintBoard.h"
#import "DCOpenGLDrawView.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet DCOpenGLDrawView *openGlDrawView;

@property (weak, nonatomic) IBOutlet DCUndoBeziPathPaintBoard *undoDrawView;

@property (weak, nonatomic) IBOutlet DCBezierPaintBoard *beziPathDrawView;

@property (weak, nonatomic) IBOutlet UIButton *selectColorBtn;
@property (weak, nonatomic) IBOutlet UIButton *beziPathBtn;
@property (weak, nonatomic) IBOutlet UIButton *undoBeziPath;
@property (weak, nonatomic) IBOutlet UIButton *openGLBtn;
@property (weak, nonatomic) IBOutlet UIView *colorView;
@property (weak, nonatomic) IBOutlet UIButton *eraseBtn;

@property (nonatomic, assign)DCPaintColor  selectPaintColor;
@property (nonatomic, assign) BOOL isErase;
@property (nonatomic, assign) DCPaintBoardType paintBoardType;


@property (nonatomic, strong) UIColor *paintColor;

@end

@implementation ViewController
/**
 *  画笔颜色set方法
 *
 *  @param selectPaintColor <#selectPaintColor description#>
 */
- (void)setSelectPaintColor:(DCPaintColor)selectPaintColor
{
    _selectPaintColor = selectPaintColor;
    switch (selectPaintColor) {
        case DCPaintColorRed:
            self.paintColor = [UIColor redColor];
            break;
        case DCPaintColorBlue:
            self.paintColor = [UIColor blueColor];
            break;
        case DCPaintColorGreen:
            self.paintColor = [UIColor greenColor];
            break;
        case DCPaintColorBlack:
            self.paintColor = [UIColor blackColor];
            break;
        default:
            self.paintColor = [UIColor blackColor];
            break;
    }
    
    self.beziPathDrawView.lineColor = self.paintColor;
    self.undoDrawView.lineColor = self.paintColor;
    self.openGlDrawView.lineColor = self.paintColor;
}

- (void)setPaintBoardType:(DCPaintBoardType)paintBoardType
{
    _paintBoardType = paintBoardType;
    switch (paintBoardType) {
        case DCPaintBoardTypeBezi:{
            self.beziPathDrawView.hidden = NO;
            self.undoDrawView.hidden = YES;
            self.openGlDrawView.hidden = YES;
            break;
        }
        case DCPaintBoardTypeBeziUndo:{
            self.beziPathDrawView.hidden = YES;
            self.undoDrawView.hidden = NO;
            self.openGlDrawView.hidden = YES;
            break;
        }
        case DCPaintBoardTypeOpenGL:{
            self.beziPathDrawView.hidden = YES;
            self.undoDrawView.hidden = YES;
            self.openGlDrawView.hidden = NO;
            break;
        }
            
        default:
        {
            self.beziPathDrawView.hidden = NO;
            self.undoDrawView.hidden = YES;
            self.openGlDrawView.hidden = YES;
            break;
        }
    }
}

- (void)setIsErase:(BOOL)isErase{
    _isErase = isErase;
    self.beziPathDrawView.isErase = isErase;
    self.undoDrawView.isErase = isErase;
    self.openGlDrawView.isErase = isErase;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UILongPressGestureRecognizer *longpress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longpresseraseBtn:)];
    longpress.minimumPressDuration = 0.5; //定义按的时间
    [self.eraseBtn addGestureRecognizer:longpress];
}

- (void)longpresseraseBtn:(UILongPressGestureRecognizer *)gest{
    [self.undoDrawView clear];
      [self.openGlDrawView clear];
      [self.beziPathDrawView clear];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self selectPaintBoardBtnClcik:self.beziPathBtn];
    [self selectColorBtnClick:_selectColorBtn];
    self.selectPaintColor = DCPaintColorBlack;
    
    self.openGlDrawView.backgroundColor = [UIColor clearColor];
}


/**
 *  画笔颜色按钮
 *
 *  @param sender 画笔按钮
 */
- (IBAction)selectColorBtnClick:(UIButton *)sender {
    sender.selected = !sender.selected;
    self.colorView.hidden = sender.selected;
}

/**
 *  颜色选择按钮
 *
 *  @param sender 颜色按钮
 */
- (IBAction)colorBtnSelect:(UIButton *)sender {
    if (sender.tag == 105) {
        
    }else{
        self.selectPaintColor = (DCPaintColor)sender.tag - 100;
    }
    switch (self.selectPaintColor) {
        case DCPaintColorRed:
        {
            [self.selectColorBtn setImage:[UIImage imageNamed:@"btn_mark_red"] forState:UIControlStateSelected];
            break;
        }
        case DCPaintColorBlue:
        {
            [self.selectColorBtn setImage:[UIImage imageNamed:@"btn_mark_blue"] forState:UIControlStateSelected];
            break;
        }
        case DCPaintColorGreen:
        {
            [self.selectColorBtn setImage:[UIImage imageNamed:@"btn_mark_green"] forState:UIControlStateSelected];
            break;
        }
            
        default:
        case DCPaintColorBlack:
        {
            [self.selectColorBtn setImage:[UIImage imageNamed:@"btn_mark_black"] forState:UIControlStateSelected];
            break;
        }
    }
    self.colorView.hidden = YES;
    self.selectColorBtn.selected = YES;
}


/**
 *  点击橡皮擦按钮
 *
 *  @param sender 橡皮擦按钮
 */
- (IBAction)eraseBtnClick:(UIButton *)sender {
    sender.selected = !sender.selected;
    self.isErase = sender.selected;
}


/**
 *  点击选中的是那一种画板
 *
 *  @param sender 画板种类按钮
 */
- (IBAction)selectPaintBoardBtnClcik:(UIButton *)sender {
    if (!sender.selected) {
        self.paintBoardType = (DCPaintBoardType)sender.tag;
        switch (sender.tag) {
            case DCPaintBoardTypeBezi:
            {
                self.beziPathBtn.selected = YES;
                self.undoBeziPath.selected = NO;
                self.openGLBtn.selected = NO;
                break;
            }
            case DCPaintBoardTypeBeziUndo:
            {
                self.beziPathBtn.selected = NO;
                self.undoBeziPath.selected = YES;
                self.openGLBtn.selected = NO;
                break;
            }
            case DCPaintBoardTypeOpenGL:
            {
                self.beziPathBtn.selected = NO;
                self.undoBeziPath.selected = NO;
                self.openGLBtn.selected = YES;
                break;
            }
                
            default:
            {
                self.beziPathBtn.selected = YES;
                self.undoBeziPath.selected = NO;
                self.openGLBtn.selected = NO;
                break;
            }
        }
    }
   
}

@end
