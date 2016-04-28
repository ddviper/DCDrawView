//
//  DCOpenGLDrawView.m
//  DCPaintBoard
//
//  Created by Wade on 16/4/27.
//  Copyright © 2016年 Wade. All rights reserved.
//

#import "DCOpenGLDrawView.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#import <GLKit/GLKit.h>

#import "shaderUtil.h"
#import "fileUtil.h"
#import "debug.h"
#import "DCCommon.h"
#import "UIView+Frame.h"

#define kBrushOpacity		(1.0 / 3.0)
#define kBrushPixelStep		3
#define kBrushScale			2
// Shaders
enum {
    PROGRAM_POINT,
    NUM_PROGRAMS
};

enum {
    UNIFORM_MVP,
    UNIFORM_POINT_SIZE,
    UNIFORM_VERTEX_COLOR,
    UNIFORM_TEXTURE,
    NUM_UNIFORMS
};

enum {
    ATTRIB_VERTEX,
    NUM_ATTRIBS
};

typedef struct {
    char *vert, *frag;
    GLint uniform[NUM_UNIFORMS];
    GLuint id;
} programInfo_t;


programInfo_t program[NUM_PROGRAMS] = {
    { "point.vsh",   "point.fsh" },     // PROGRAM_POINT
};

// Texture
typedef struct {
    GLuint id;
    GLsizei width, height;
} textureInfo_t;

@interface DCOpenGLDrawView()
{
    // The pixel dimensions of the backbuffer
    // 画布的大小
    GLint backingWidth;
    GLint backingHeight;
    
    EAGLContext *context;
    
    // OpenGL names for the renderbuffer and framebuffers used to render to this view
    GLuint viewRenderbuffer, viewFramebuffer;
    
    // OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
    GLuint depthRenderbuffer;
    
    textureInfo_t brushTexture;     // brush texture
    GLfloat brushColor[4];          // brush color
    
    Boolean	firstTouch;
    Boolean needsErase;
    
    // Shader objects
    GLuint vertexShader;
    GLuint fragmentShader;
    GLuint shaderProgram;
    
    // Buffer Objects
    GLuint vboId;
    
    BOOL initialized;
}

/**
 *  保存当前画的一笔的所有点  画完保存后既删除
 */
@property (nonatomic, strong) NSMutableArray *pointsArrM;

/**
 *  保存所有画的点和  不清空
 */
@property (nonatomic, strong) NSMutableDictionary *pathsDictM;

// 当前点
@property(nonatomic, readwrite) CGPoint location;

// 上一个点
@property(nonatomic, readwrite) CGPoint previousLocation;


@end

@implementation DCOpenGLDrawView

- (void)setLineColor:(UIColor *)lineColor{
    _lineColor = lineColor;
    if (lineColor == [UIColor blackColor]) {
         [self setBrushColorWithRed:0 green:0 blue:0 alpha:1];
    }
   else if (lineColor == [UIColor redColor]) {
        [self setBrushColorWithRed:1 green:0 blue:0 alpha:1];
    }
   else if (lineColor == [UIColor greenColor]) {
        [self setBrushColorWithRed:0 green:1 blue:0 alpha:1];
    }
   else if (lineColor == [UIColor greenColor])
   {
       [self setBrushColorWithRed:0 green:0 blue:1 alpha:1];
   }else  {
        [self setBrushColorWithRed:0 green:0 blue:0 alpha:1];
    }
}

- (NSMutableDictionary *)pathsDictM{
    if (!_pathsDictM) {
        _pathsDictM = [NSMutableDictionary dictionary];
    }
    return _pathsDictM;
}


// 保存当前一笔的所有点
- (NSMutableArray *)pointsArrM{
    if (!_pointsArrM) {
        _pointsArrM = [NSMutableArray array];
    }
    return _pointsArrM;
}

/**
 *  设置是否是橡皮擦
 *
 *  @param isErase
 */
- (void)setIsErase:(BOOL)isErase
{
    _isErase = isErase;
    if (isErase) {
        
        [self setBrushColorWithRed:0 green:0 blue:0 alpha:0];
        //
        glBlendFunc(GL_ONE, GL_ZERO);
        
    }else{
       [self setBrushColorWithRed:1 green:0 blue:0 alpha:1];
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    }
    //    [self setupShaders];
}


+ (Class)layerClass
{
    return [CAEAGLLayer class];
}


// The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
// GL视图存储在nib文件。当它从未归档-initWithCoder发送:
- (id)initWithCoder:(NSCoder*)coder {
    
    if ((self = [super initWithCoder:coder])) {
        
        // 2、在init的方法中，从基类获取layer属性，并将其转型至CAEAGLLayer
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)super.layer;
        
        eaglLayer.opaque = YES;//无需Quartz处理透明度
        // In this application, we want to retain the EAGLDrawable contents after a call to presentRenderbuffer.
        
        
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        /*
         后面的参数有两个选择
         kEAGLRenderingAPIOpenGLES1=1  表示用渲染库的API版本是1.1
         kEAGLRenderingAPIOpenGLES2=2  表示用渲染库的API版本是2.0
         */
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        
        // //设定当期上下文对象
        if (!context || ![EAGLContext setCurrentContext:context]) {
            return nil;
        }
        
        // Set the view's scale factor as you wish
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
        
        // Make sure to start with a cleared buffer
        needsErase = YES;
    }
    
    return self;
}

//如果我们的视图的大小,我们将要求布局子视图。
//这是一个完美的机会来更新framebuffer这样
//同样大小的显示区域。
-(void)layoutSubviews
{
    [EAGLContext setCurrentContext:context];
    
    if (!initialized) {
        initialized = [self initGL];
    }
    else {
        [self resizeFromLayer:(CAEAGLLayer*)self.layer];
    }
    
    // Clear the framebuffer the first time it is allocated
    if (needsErase) {
        [self clearDrawImageView];
        needsErase = NO;
    }
    
}


// 创建一个纹理的图像
- (textureInfo_t)textureFromName:(NSString *)name
{
    CGImageRef		brushImage;
    CGContextRef	brushContext;
    GLubyte			*brushData;
    size_t			width, height;
    GLuint          texId;
    textureInfo_t   texture;
    
    // First create a UIImage object from the data in a image file, and then extract the Core Graphics image
    brushImage = [UIImage imageNamed:name].CGImage;
    
    // Get the width and height of the image
    width = CGImageGetWidth(brushImage);
    height = CGImageGetHeight(brushImage);
    
    // Make sure the image exists
    if(brushImage) {
        // Allocate  memory needed for the bitmap context
        brushData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
        // Use  the bitmatp creation function provided by the Core Graphics framework.
        brushContext = CGBitmapContextCreate(brushData, width, height, 8, width * 4, CGImageGetColorSpace(brushImage), kCGImageAlphaPremultipliedLast);
        // After you create the context, you can draw the  image to the context.
        CGContextDrawImage(brushContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), brushImage);
        // You don't need the context at this point, so you need to release it to avoid memory leaks.
        CGContextRelease(brushContext);
        // Use OpenGL ES to generate a name for the texture.
        // //创建渲染缓冲管线
        glGenTextures(1, &texId);
        // Bind the texture name.
        //绑定渲染缓冲管线
        glBindTexture(GL_TEXTURE_2D, texId);
        // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        // Specify a 2D texture image, providing the a pointer to the image data in memory
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)width, (int)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, brushData);
        // Release  the image data; it's no longer needed
        free(brushData);
        
        texture.id = texId;
        texture.width = (int)width;
        texture.height = (int)height;
    }
    
    return texture;
}

// 初始化GL
- (BOOL)initGL
{
    // Generate IDs for a framebuffer object and a color renderbuffer
    ////创建帧缓冲管线
    glGenFramebuffers(1, &viewFramebuffer);
    //绑定渲染缓冲管线
    glGenRenderbuffers(1, &viewRenderbuffer);
    
    //绑定帧缓冲管线
    glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    
    
    //将渲染缓冲区附加到帧缓冲区上
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    // This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
    // allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(id<EAGLDrawable>)self.layer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, viewRenderbuffer);
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    // For this sample, we do not need a depth buffer. If you do, this is how you can create one and attach it to the framebuffer:
    //    glGenRenderbuffers(1, &depthRenderbuffer);
    //    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
    //    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
    //    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
    
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    
    //创建显示区域
    glViewport(0, 0, backingWidth, backingHeight);
    
    // Create a Vertex Buffer Object to hold our data
    glGenBuffers(1, &vboId);
    
    // Load the brush texture
    // 设置笔头
    brushTexture = [self textureFromName:@"Particle"];
    
    // Load shaders
    [self setupShaders];
    
    // Enable blending and set a blending function appropriate for premultiplied alpha pixel data
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    return YES;
}


- (BOOL)resizeFromLayer:(CAEAGLLayer *)layer
{
    // Allocate color buffer backing based on the current layer size
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    // For this sample, we do not need a depth buffer. If you do, this is how you can allocate depth buffer backing:
    //    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
    //    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
    //    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"Failed to make complete framebuffer objectz %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    
    // Update projection matrix
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth, 0, backingHeight, -1, 1);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity; // this sample uses a constant identity modelView matrix
    GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    glUseProgram(program[PROGRAM_POINT].id);
    glUniformMatrix4fv(program[PROGRAM_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE, MVPMatrix.m);
    
    // Update viewport
    glViewport(0, 0, backingWidth, backingHeight);
    
    return YES;
}

- (void)setupShaders
{
    for (int i = 0; i < NUM_PROGRAMS; i++)
    {
        char *vsrc = readFile(pathForResource(program[i].vert));
        char *fsrc = readFile(pathForResource(program[i].frag));
        GLsizei attribCt = 0;
        GLchar *attribUsed[NUM_ATTRIBS];
        GLint attrib[NUM_ATTRIBS];
        GLchar *attribName[NUM_ATTRIBS] = {
            "inVertex",
        };
        const GLchar *uniformName[NUM_UNIFORMS] = {
            "MVP", "pointSize", "vertexColor", "texture",
        };
        
        // auto-assign known attribs
        for (int j = 0; j < NUM_ATTRIBS; j++)
        {
            if (strstr(vsrc, attribName[j]))
            {
                attrib[attribCt] = j;
                attribUsed[attribCt++] = attribName[j];
            }
        }
        
        glueCreateProgram(vsrc, fsrc,
                          attribCt, (const GLchar **)&attribUsed[0], attrib,
                          NUM_UNIFORMS, &uniformName[0], program[i].uniform,
                          &program[i].id);
        free(vsrc);
        free(fsrc);
        
        // Set constant/initalize uniforms
        if (i == PROGRAM_POINT)
        {
            glUseProgram(program[PROGRAM_POINT].id);
            
            // the brush texture will be bound to texture unit 0
            glUniform1i(program[PROGRAM_POINT].uniform[UNIFORM_TEXTURE], 0);
            
            // viewing matrices
            GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth, 0, backingHeight, -1, 1);
            GLKMatrix4 modelViewMatrix = GLKMatrix4Identity; // this sample uses a constant identity modelView matrix
            GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
            
            glUniformMatrix4fv(program[PROGRAM_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE, MVPMatrix.m);
            
            // point size
            glUniform1f(program[PROGRAM_POINT].uniform[UNIFORM_POINT_SIZE], brushTexture.width / kBrushScale);
            
            // initialize brush color
            glUniform4fv(program[PROGRAM_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, brushColor);
        }
    }
    
    glError();
}



// 根据两点画线的方法
- (void)renderLineFromPoint:(CGPoint)start toPoint:(CGPoint)end
{
    //     NSLog(@"drawLineWithPoints--%@--%@",NSStringFromCGPoint(start),NSStringFromCGPoint(end));
    static GLfloat*		vertexBuffer = NULL;
    static NSUInteger	vertexMax = 64;
    NSUInteger			vertexCount = 0,
    count,
    i;
    
    [EAGLContext setCurrentContext:context];
    glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    
    // Convert locations from Points to Pixels
    CGFloat scale = self.contentScaleFactor;
    
    start.x *= scale;
    start.y *= scale;
    end.x *= scale;
    end.y *= scale;
    
    // Allocate vertex array buffer
    if(vertexBuffer == NULL)
        vertexBuffer = malloc(vertexMax * 2 * sizeof(GLfloat));
    
    // Add points to the buffer so there are drawing points every X pixels
    count = MAX(ceilf(sqrtf((end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y)) / kBrushPixelStep), 1);
    for(i = 0; i < count; ++i) {
        if(vertexCount == vertexMax) {
            vertexMax = 2 * vertexMax;
            vertexBuffer = realloc(vertexBuffer, vertexMax * 2 * sizeof(GLfloat));
        }
        
        vertexBuffer[2 * vertexCount + 0] = start.x + (end.x - start.x) * ((GLfloat)i / (GLfloat)count);
        vertexBuffer[2 * vertexCount + 1] = start.y + (end.y - start.y) * ((GLfloat)i / (GLfloat)count);
        vertexCount += 1;
    }
    
    // Load data to the Vertex Buffer Object
    glBindBuffer(GL_ARRAY_BUFFER, vboId);
    glBufferData(GL_ARRAY_BUFFER, vertexCount*2*sizeof(GLfloat), vertexBuffer, GL_STATIC_DRAW);
    
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 0, 0);
    
    // Draw
    glUseProgram(program[PROGRAM_POINT].id);
    
    // 画线
    glDrawArrays(GL_POINTS, 0, (int)vertexCount);
    
    // Display the buffer
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER];
}


// 清楚
- (void)clearDrawImageView
{
    [EAGLContext setCurrentContext:context];
    
    // Clear the buffer
    glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // Display the buffer
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)setBrushColorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
    // Update the brush color
    brushColor[0] = red ;
    brushColor[1] = green ;
    brushColor[2] = blue ;
    brushColor[3] = alpha;
    
    if (initialized) {
        glUseProgram(program[PROGRAM_POINT].id);
        // 设置画笔颜色
        glUniform4fv(program[PROGRAM_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, brushColor);
    }
}



// Releases resources when they are not longer needed.
- (void)dealloc
{
    // Destroy framebuffers and renderbuffers
    if (viewFramebuffer) {
        glDeleteFramebuffers(1, &viewFramebuffer);
        viewFramebuffer = 0;
    }
    if (viewRenderbuffer) {
        glDeleteRenderbuffers(1, &viewRenderbuffer);
        viewRenderbuffer = 0;
    }
    if (depthRenderbuffer)
    {
        glDeleteRenderbuffers(1, &depthRenderbuffer);
        depthRenderbuffer = 0;
    }
    // texture
    if (brushTexture.id) {
        glDeleteTextures(1, &brushTexture.id);
        brushTexture.id = 0;
    }
    // vbo
    if (vboId) {
        glDeleteBuffers(1, &vboId);
        vboId = 0;
    }
    
    // tear down context
    if ([EAGLContext currentContext] == context)
        [EAGLContext setCurrentContext:nil];
}


#pragma mark ------Touch方法
/**
 *  touch 方法
 */

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    //    CGRect	bounds = [self bounds];
    UITouch*  touch = [[event touchesForView:self] anyObject];
    
    //    firstTouch = YES;
    
    // 转换触点从UIView引用到OpenGL 1(倒翻转)
    // Convert touch point from UIView referential to OpenGL one (upside-down flip)
    _previousLocation = [touch locationInView:self];
    _previousLocation.y = self.height - _previousLocation.y;
    
    CGPoint currentPoint = [touch locationInView:self];
    NSDictionary *dict = @{@"x":@(currentPoint.x),@"y":@(currentPoint.y)};
    
    [self.pointsArrM addObject:dict];
    
    //    NSLog(@"touchesBegan--%@",dict);
}


- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    //    CGRect	bounds = [self bounds];
    UITouch* touch = [[event touchesForView:self] anyObject];
    
    _location = [touch locationInView:self];
    _location.y = self.height - _location.y;
    _previousLocation = [touch previousLocationInView:self];
    _previousLocation.y = self.height - _previousLocation.y;
    
    [self renderLineFromPoint:_previousLocation toPoint:_location];
    
    CGPoint currentPoint = [touch locationInView:self];
    NSDictionary *dict = @{@"x":@(currentPoint.x),@"y":@(currentPoint.y)};
    [self.pointsArrM addObject:dict];
    //    NSLog(@"touchesMoved--%@",dict);
    
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    
    UITouch*  touch = [[event touchesForView:self] anyObject];
    _location = [touch locationInView:self];
    _location.y = self.height - _location.y;
    
    _previousLocation = [touch previousLocationInView:self];
    _previousLocation.y = self.height - _previousLocation.y;
    
    [self renderLineFromPoint:_previousLocation toPoint:_location];
    
    _location = CGPointMake(0, 0);
    _previousLocation = CGPointMake(0, 0);
    
    CGPoint currentPoint = [touch locationInView:self];
    NSDictionary *dict = @{@"x":@(currentPoint.x),@"y":@(currentPoint.y)};
    [self.pointsArrM addObject:dict];

    
    //    NSLog(@"touchesEnded--%@",dict);
}



- (void)clear{
    [self clearDrawImageView];
}
@end
