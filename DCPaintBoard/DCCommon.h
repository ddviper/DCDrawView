//
//  DCCommon.h
//  DCPaintBoard
//
//  Created by Wade on 16/4/26.
//  Copyright © 2016年 Wade. All rights reserved.
//

#ifndef DCCommon_h
#define DCCommon_h

typedef enum{
    DCPaintColorRed = 1,
    DCPaintColorGreen = 2,
    DCPaintColorBlue = 3,
    DCPaintColorBlack = 4
} DCPaintColor;


typedef enum{
    DCPaintBoardTypeBezi = 1,
    DCPaintBoardTypeBeziUndo = 2,
    DCPaintBoardTypeOpenGL = 3
} DCPaintBoardType;

static NSInteger const kLineWidth = 5;
static NSInteger const kEraseLineWidth = 20;
#endif /* DCCommon_h */
