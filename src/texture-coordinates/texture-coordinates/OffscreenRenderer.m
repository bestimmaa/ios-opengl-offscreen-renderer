//
//  OffscreenRenderer.m
//  texture-coordinates
//
//  Created by Christoph Halang on 02/03/15.
//  Copyright (c) 2015 Christoph Halang. All rights reserved.
//

#import "OffscreenRenderer.h"
#import <OpenGLES/ES2/glext.h>
#import <GLKit/GLKit.h>
#import "Geometry.h"
@interface OffscreenRenderer ()
@property GLKMatrix4 modelMatrix; // transformations of the model
@property GLKMatrix4 viewMatrix; // camera position and orientation
@property GLKMatrix4 projectionMatrix; // view frustum (near plane, far plane)
@property GLKTextureInfo* textureInfo;
@property float rotation;
@end

@implementation OffscreenRenderer{
    EAGLContext* _context;
    GLKBaseEffect* _effect;
    GLuint _vertexBuffer;
    GLuint _indexBuffer;
    GLuint _vertexArray;
    BOOL _initialized;
    //Offscreen rendering
    GLuint _multisamplingFrameBuffer;
    GLuint _multisamplingColorRenderbuffer;
    GLuint _multisamplingDepthRenderbuffer;
    GLuint _resolveFrameBuffer;
    GLuint _resolveColorRenderbuffer;
}


- (id)init{
    self = [super init];
    
    if (self){
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        if (!_context) {
            NSLog(@"Failed to create ES context");
        }
        
        
        self.viewMatrix = GLKMatrix4MakeLookAt(0.0, 0.0, 26.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0);
        self.projectionMatrix  = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), 4.0/3.0, 1, 51);
        self.width = 500.0f;
        self.height = 500.0f;
        [self initEffect];
        [self setupGL];
        _initialized = YES;

    }
    
    return self;
}

- (void)initEffect {
    _effect = [[GLKBaseEffect alloc] init];
    [self configureDefaultLight];
}


#pragma mark - Setup The Shader

- (void)prepareEffectWithModelMatrix:(GLKMatrix4)modelMatrix viewMatrix:(GLKMatrix4)viewMatrix projectionMatrix:(GLKMatrix4)projectionMatrix{
    _effect.transform.modelviewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
    _effect.transform.projectionMatrix = projectionMatrix;
    [_effect prepareToDraw];
}

- (void)configureDefaultLight{
    //Lightning
    _effect.light0.enabled = GL_TRUE;
    _effect.light0.ambientColor = GLKVector4Make(1, 1, 1, 1.0);
    _effect.light0.diffuseColor = GLKVector4Make(1, 1, 1, 1.0);
    _effect.light0.position = GLKVector4Make(0, 0,-10,1.0);
}

- (void)configureDefaultMaterial {
    
    _effect.texture2d0.enabled = NO;
    
    
    _effect.material.ambientColor = GLKVector4Make(0.3,0.3,0.3,1.0);
    _effect.material.diffuseColor = GLKVector4Make(0.3,0.3,0.3,1.0);
    _effect.material.emissiveColor = GLKVector4Make(0.0,0.0,0.0,1.0);
    _effect.material.specularColor = GLKVector4Make(0.0,0.0,0.0,1.0);
    
    _effect.material.shininess = 0;
}

- (void)configureDefaultTexture{
    _effect.texture2d0.enabled = YES;
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"texture_numbers" ofType:@"png"];
    
    NSError *error;
    NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                        forKey:GLKTextureLoaderOriginBottomLeft];
    
    
    self.textureInfo = [GLKTextureLoader textureWithContentsOfFile:path
                                                           options:options error:&error];
    if (self.textureInfo == nil)
        NSLog(@"Error loading texture: %@", [error localizedDescription]);
    
    
    GLKEffectPropertyTexture *tex = [[GLKEffectPropertyTexture alloc] init];
    tex.enabled = YES;
    tex.envMode = GLKTextureEnvModeDecal;
    tex.name = self.textureInfo.name;
    
    _effect.texture2d0.name = tex.name;
    
}

#pragma mark - OpenGL Setup

- (void)setupGL {
    
    [EAGLContext setCurrentContext:_context];
    
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    
    // Enable Transparency
    glEnable (GL_BLEND);
    glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    
    // Create Vertex Array Buffer For Vertex Array Objects
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    
    // All of the following configuration for per vertex data is stored into the VAO
    
    // setup vertex buffer - what are my vertices?
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(VerticesCube), VerticesCube, GL_STATIC_DRAW);
    
    // setup index buffer - which vertices form a triangle?
    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(IndicesTrianglesCube), IndicesTrianglesCube, GL_STATIC_DRAW);
    
    //Setup Vertex Atrributs
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    //SYNTAX -,number of elements per vertex, datatype, FALSE, size of element, offset in datastructure
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Position));
    
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Color));
    
    //Textures
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, TexCoord));
    
    //Normals
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Normal));
    
    
    glActiveTexture(GL_TEXTURE0);
    [self configureDefaultTexture];
    
    
    // were done so unbind the VAO
    glBindVertexArrayOES(0);
    
    // Create Framebuffer for multisampling
    
    glGenFramebuffers(1, &_multisamplingFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _multisamplingFrameBuffer);
    
    glGenRenderbuffers(1, &_multisamplingColorRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _multisamplingColorRenderbuffer);
    glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, 4, GL_RGBA8_OES, _width, _height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _multisamplingColorRenderbuffer);
    
    glGenRenderbuffers(1, &_multisamplingDepthRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _multisamplingDepthRenderbuffer);
    glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, 4, GL_DEPTH_COMPONENT16, _width, _height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _multisamplingDepthRenderbuffer);
    
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER) ;
    if(status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete multisampling framebuffer object %x", status);
    }
    
    // Create framebuffer for resolving the image
    glGenFramebuffers(1, &_resolveFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _resolveFrameBuffer);
    
    glGenRenderbuffers(1, &_resolveColorRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _resolveColorRenderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGB8_OES, _width, _height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _resolveColorRenderbuffer);
    
    status = glCheckFramebufferStatus(GL_FRAMEBUFFER) ;
    if(status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete resolve framebuffer object %x", status);
    }
 

}

- (void)tearDownGL {
    
    [EAGLContext setCurrentContext:_context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteBuffers(1, &_indexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
    _effect = nil;
    
}

- (UIImage *)image
{
    if (!_initialized) {
        return nil;
    }
    
    [self update];
    
    [self draw];
    
    NSInteger x = 0, y = 0;
    NSInteger dataLength = _width * _height * 4;
    GLubyte *data = (GLubyte*)malloc(dataLength * sizeof(GLubyte));
    
    glBindFramebuffer(GL_FRAMEBUFFER, _resolveFrameBuffer);
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(x, y, _width, _height, GL_RGBA, GL_UNSIGNED_BYTE, data);
    
    CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGImageRef iref = CGImageCreate(_width, _height, 8, 32, _width * 4, colorspace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
                                    ref, NULL, true, kCGRenderingIntentDefault);
    
    UIGraphicsBeginImageContext(CGSizeMake(_width, _height));
    CGContextRef cgcontext = UIGraphicsGetCurrentContext();
    CGContextSetBlendMode(cgcontext, kCGBlendModeCopy);
    CGContextDrawImage(cgcontext, CGRectMake(0.0, 0.0, _width, _height), iref);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    free(data);
    CFRelease(ref);
    CFRelease(colorspace);
    CGImageRelease(iref);
    
    return image;
    
}

#pragma mark - OpenGL Drawing

- (void)update{
    float aspect = fabsf(self.width / self.height);
    self.projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    self.rotation = arc4random() * 1.0f;
}

- (void)draw{
    glBindFramebuffer(GL_FRAMEBUFFER, _multisamplingFrameBuffer);
    glViewport(0, 0, self.width, self.height);
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    GLKMatrix4 scaleMatrix = GLKMatrix4MakeScale(3.0, 3.0, 3.0);
    GLKMatrix4 translateMatrix = GLKMatrix4MakeTranslation(0, 0, 0);
    GLKMatrix4 rotationMatrix = GLKMatrix4MakeRotation(self.rotation, 1.0, 1.0, 1.0);
    
    GLKMatrixStackRef matrixStack = GLKMatrixStackCreate(CFAllocatorGetDefault());
    
    GLKMatrixStackMultiplyMatrix4(matrixStack, translateMatrix);
    GLKMatrixStackMultiplyMatrix4(matrixStack, rotationMatrix);
    GLKMatrixStackMultiplyMatrix4(matrixStack, scaleMatrix);
    
    GLKMatrixStackPush(matrixStack);
    self.modelMatrix = GLKMatrixStackGetMatrix4(matrixStack);
    glBindVertexArrayOES(_vertexArray);
    [self prepareEffectWithModelMatrix:self.modelMatrix viewMatrix:self.viewMatrix projectionMatrix:self.projectionMatrix];
    glDrawElements(GL_TRIANGLES, sizeof(IndicesTrianglesCube) / sizeof(IndicesTrianglesCube[0]), GL_UNSIGNED_BYTE, 0);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER_APPLE, _resolveFrameBuffer);
    glBindFramebuffer(GL_READ_FRAMEBUFFER_APPLE, _multisamplingFrameBuffer);
    glResolveMultisampleFramebufferAPPLE();
    
    const GLenum discards[]  = {GL_COLOR_ATTACHMENT0,GL_DEPTH_ATTACHMENT};
    glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE,2,discards);
    
    glBindVertexArrayOES(0);
    CFRelease(matrixStack);
    
}

@end
