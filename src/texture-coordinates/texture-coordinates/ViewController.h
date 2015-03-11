//
//  ViewController.h
//  texture-coordinates
//
//  Created by Christoph Halang on 28/02/15.
//  Copyright (c) 2015 Christoph Halang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OffscreenRenderer.h"

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet OffscreenRenderer *offscreenRenderer;
@end

