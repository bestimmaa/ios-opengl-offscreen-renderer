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
#import "GLProgram.h"

@interface OffscreenRenderer ()
@property GLKMatrix4 modelMatrix; // transformations of the model
@property GLKMatrix4 viewMatrix; // camera position and orientation
@property GLKMatrix4 projectionMatrix; // view frustum (near plane, far plane)
@property GLKTextureInfo *textureInfo;
@property float rotation;
@property(nonatomic, strong) GLProgram *program;
@end

@implementation OffscreenRenderer {
    EAGLContext *_context;
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

- (id)init {
    self = [super init];

    if (self) {
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

        if (!_context) {
            NSLog(@"Failed to create ES context");
        }


        self.viewMatrix = GLKMatrix4MakeLookAt(0.0, 0.0, 26.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0);
        self.projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), 4.0 / 3.0, 1, 51);
        self.width = 500.0f;
        self.height = 500.0f;
        [self setupGL];
        _initialized = YES;

    }

    return self;
}


#pragma mark - Setup The Shader


- (void)configureDefaultTexture {
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

}

#pragma mark - OpenGL Setup

- (void)setupGL {

    [EAGLContext setCurrentContext:_context];

    self.program = [[GLProgram alloc] initWithVertexShaderFilename:@"vertex_shader"
                                            fragmentShaderFilename:@"fragment_shader"];

    [self.program addAttribute:@"position"];
    [self.program addAttribute:@"color"];
    [self.program addAttribute:@"texCoord"];
    [self.program addAttribute:@"normal"];

    if (![self.program link]) {
        NSLog(@"Link failed");
        NSString *progLog = [self.program programLog];
        NSLog(@"Program Log: %@", progLog);
        NSString *fragLog = [self.program fragmentShaderLog];
        NSLog(@"Frag Log: %@", fragLog);
        NSString *vertLog = [self.program vertexShaderLog];
        NSLog(@"Vert Log: %@", vertLog);
        self.program = nil;
    }

    GLuint positionAttribute = [self.program attributeIndex:@"position"];
    GLuint colorAttribute = [self.program attributeIndex:@"color"];
    GLuint texCoord = [self.program attributeIndex:@"texCoord"];
    GLuint normalAttribute = [self.program attributeIndex:@"normal"];

    // Enable Depth Testing
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);

    // Enable Transparency
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);


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

    //Setup Vertex Atrributes
    glEnableVertexAttribArray(positionAttribute);
    //SYNTAX -,number of elements per vertex, datatype, FALSE, size of element, offset in datastructure
    glVertexAttribPointer(positionAttribute, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Position));

    glEnableVertexAttribArray(colorAttribute);
    glVertexAttribPointer(colorAttribute, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Color));

    //Textures
    glEnableVertexAttribArray(texCoord);
    glVertexAttribPointer(texCoord, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, TexCoord));

    //Normals
    glEnableVertexAttribArray(normalAttribute);
    glVertexAttribPointer(normalAttribute, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Normal));


    glActiveTexture(GL_TEXTURE0);
    [self configureDefaultTexture];


    // were done so unbind the VAO
    glBindVertexArrayOES(0);

    // Create Framebuffer for multisampling
    glGenFramebuffers(1, &_multisamplingFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _multisamplingFrameBuffer);

    // create a render buffer for color
    glGenRenderbuffers(1, &_multisamplingColorRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _multisamplingColorRenderbuffer);
    glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, 4, GL_RGBA8_OES, _width, _height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _multisamplingColorRenderbuffer);

    // create a render buffer for the depth-buffer. this is needed for the framebuffer to depth test when rendering
    glGenRenderbuffers(1, &_multisamplingDepthRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _multisamplingDepthRenderbuffer);
    glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, 4, GL_DEPTH_COMPONENT16, _width, _height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _multisamplingDepthRenderbuffer);


    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete multisampling framebuffer object %x", status);
    }

    // Create framebuffer for resolving the image
    glGenFramebuffers(1, &_resolveFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _resolveFrameBuffer);

    // Create a renderbuffer object. A renderbuffer is optimized to store images.
    // https://www.opengl.org/wiki/Renderbuffer_Object
    glGenRenderbuffers(1, &_resolveColorRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _resolveColorRenderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGB8_OES, _width, _height);
    //  attach the renderbuffer object to the framebuffer object
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _resolveColorRenderbuffer);

    // check for errors
    status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete resolve framebuffer object %x", status);
    }


}

- (void)tearDownGL {

    [EAGLContext setCurrentContext:_context];

    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteBuffers(1, &_indexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
}

- (UIImage *)image {
    if (!_initialized) {
        return nil;
    }
    // update rotation of the rendered cube at random and setup the projection matrix
    [self update];

    // opengl drawing code
    [self draw];

    // get the image from the framebuffer and store it to an UIImage
    NSInteger x = 0, y = 0;
    NSInteger dataLength = self.width * self.height * 4;
    GLubyte *data = (GLubyte *) malloc(dataLength * sizeof(GLubyte));

    glBindFramebuffer(GL_FRAMEBUFFER, _resolveFrameBuffer);
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(x, y, self.width, self.height, GL_RGBA, GL_UNSIGNED_BYTE, data);

    CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGImageRef iref = CGImageCreate(self.width, self.height, 8, 32, self.height * 4, colorspace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
            ref, NULL, true, kCGRenderingIntentDefault);

    UIGraphicsBeginImageContext(CGSizeMake(_width, _height));
    CGContextRef cgcontext = UIGraphicsGetCurrentContext();
    CGContextSetBlendMode(cgcontext, kCGBlendModeCopy);
    CGContextDrawImage(cgcontext, CGRectMake(0.0, 0.0, self.width, self.height), iref);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    free(data);
    CFRelease(ref);
    CFRelease(colorspace);
    CGImageRelease(iref);

    return image;

}

#pragma mark - OpenGL Drawing

- (void)update {
    float aspect = fabsf(self.width / self.height);
    self.projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    self.rotation = arc4random() * 1.0f;
}

- (void)draw {
    GLuint modelViewUniform = [self.program uniformIndex:@"modelView"];
    GLuint projectionUniform = [self.program uniformIndex:@"projection"];

    [self.program use];

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

    // create modelview and projection matrix
    self.modelMatrix = GLKMatrixStackGetMatrix4(matrixStack);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(self.viewMatrix, self.modelMatrix);
    GLKMatrix4 projection = self.projectionMatrix;


    glBindVertexArrayOES(_vertexArray);
    // send the modelview and projection matrix to the vertex shader at GL land
    glUniformMatrix4fv(modelViewUniform, 1, GL_FALSE, (const GLfloat *) &modelViewMatrix);
    glUniformMatrix4fv(projectionUniform, 1, GL_FALSE, (const GLfloat *) &projection);
    // send the geometry for drawing
    glDrawElements(GL_TRIANGLES, sizeof(IndicesTrianglesCube) / sizeof(IndicesTrianglesCube[0]), GL_UNSIGNED_BYTE, 0);

    // Multisampling
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER_APPLE, _resolveFrameBuffer);
    glBindFramebuffer(GL_READ_FRAMEBUFFER_APPLE, _multisamplingFrameBuffer);
    glResolveMultisampleFramebufferAPPLE();

    // discard the frame buffer and its attached render buffers
    const GLenum discards[] = {GL_COLOR_ATTACHMENT0, GL_DEPTH_ATTACHMENT};
    glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, 2, discards);

    glBindVertexArrayOES(0);
    CFRelease(matrixStack);

}

@end
