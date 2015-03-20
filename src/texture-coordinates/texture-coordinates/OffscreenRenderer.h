//
//  OffscreenRenderer.h
//  texture-coordinates
//
//  Created by Christoph Halang on 02/03/15.
//  Copyright (c) 2015 Christoph Halang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface OffscreenRenderer : NSObject
@property (readonly) UIImage* image;
@property float width;
@property float height;
- (void)generateTexture;
@end
