//
//  ViewController.m
//  Pixel Color Changing
//
//  Created by Hamish Knight on 12/04/2016.
//  Copyright © 2016 Redonkulous Apps. All rights reserved.
//

#import "ViewController.h"

@interface UIImageView (PointConversionCatagory)

@property (nonatomic, readonly) CGAffineTransform viewToImageTransform;
@property (nonatomic, readonly) CGAffineTransform imageToViewTransform;

@end

@implementation UIImageView (PointConversionCatagory)

-(CGAffineTransform) viewToImageTransform {
    
    // failure conditions. If any of these are met – return the identity transform
    UIViewContentMode contentMode = self.contentMode;
    
    if (!self.image || self.frame.size.width == 0 || self.frame.size.height == 0 ||
        (contentMode != UIViewContentModeScaleToFill && contentMode != UIViewContentModeScaleAspectFill && contentMode != UIViewContentModeScaleAspectFit)) {
        return CGAffineTransformIdentity;
    }
    
    // the width and height ratios
    CGFloat rWidth = self.image.size.width/self.frame.size.width;
    CGFloat rHeight = self.image.size.height/self.frame.size.height;
    
    // whether the image will be scaled according to width
    BOOL imageWiderThanView = rWidth > rHeight;
    
    if (contentMode == UIViewContentModeScaleAspectFit || contentMode == UIViewContentModeScaleAspectFill) {
        
        // The ratio to scale both the x and y axis by
        CGFloat ratio = ((imageWiderThanView && contentMode == UIViewContentModeScaleAspectFit) || (!imageWiderThanView && contentMode == UIViewContentModeScaleAspectFill)) ? rWidth:rHeight;
        
        // The x-offset of the inner rect as it gets centered
        CGFloat xOffset = (self.image.size.width-(self.frame.size.width*ratio))*0.5;
        
        // The y-offset of the inner rect as it gets centered
        CGFloat yOffset = (self.image.size.height-(self.frame.size.height*ratio))*0.5;
        
        return CGAffineTransformConcat(CGAffineTransformMakeScale(ratio, ratio), CGAffineTransformMakeTranslation(xOffset, yOffset));
    } else {
        return CGAffineTransformMakeScale(rWidth, rHeight);
    }
}

-(CGAffineTransform) imageToViewTransform {
    return CGAffineTransformInvert(self.viewToImageTransform);
}

@end

struct PixelPosition {
    NSInteger x;
    NSInteger y;
};

typedef struct PixelPosition PixelPosition;

@interface UIImage (UIImagePixelManipulationCatagory)

@end

@implementation UIImage (UIImagePixelManipulationCatagory)

-(UIImage*) imageWithPixel:(PixelPosition)pixelPosition replacedByColor:(UIColor*)color {
    
    // components of replacement color
    const CGFloat* colorComponents = CGColorGetComponents(color.CGColor);
    UInt8* color255Components = calloc(sizeof(UInt8), 4);
    for (int i = 0; i < 4; i++) color255Components[i] = (UInt8)round(colorComponents[i]*255.0);
    
    // raw image reference
    CGImageRef rawImage = self.CGImage;
    
    // image attributes
    size_t width = CGImageGetWidth(rawImage);
    size_t height = CGImageGetHeight(rawImage);
    CGRect rect = {CGPointZero, {width, height}};
    
    // image format
    size_t bitsPerComponent = CGImageGetBitsPerComponent(rawImage);
    size_t bitsPerPixel = bitsPerComponent*4;
    size_t bytesPerRow = bitsPerPixel*width/8;
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(rawImage);
    
    if (alphaInfo == kCGImageAlphaNone) { // unsupported format, change to closest supported.
        alphaInfo = kCGImageAlphaNoneSkipLast;
    }
    
    if (alphaInfo == kCGImageAlphaLast) { // unsupported format, change to closest supported.
        alphaInfo = kCGImageAlphaPremultipliedLast;
    }
    
    // the bitmap info
    CGBitmapInfo bitmapInfo = alphaInfo | kCGBitmapByteOrderDefault;
    
    // data pointer
    UInt8* data = calloc(bytesPerRow, height);
    
    // get new RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // create bitmap context
    CGContextRef ctx = CGBitmapContextCreate(data, width, height, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo);
    CGContextDrawImage(ctx, rect, rawImage);
    
    // get the index of the pixel (4 components times the x position plus the y position times the row width)
    NSInteger pixelIndex = 4*(pixelPosition.x+(pixelPosition.y*width));
    
    // set the pixel components to the color components
    data[pixelIndex] = color255Components[0];
    data[pixelIndex+1] = color255Components[1];
    data[pixelIndex+2] = color255Components[2];
    data[pixelIndex+3] = color255Components[3];
    
    // get image from context
    CGImageRef img = CGBitmapContextCreateImage(ctx);
    
    // clean up
    free(color255Components);
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    free(data);
    
    UIImage* returnImage = [UIImage imageWithCGImage:img];
    CGImageRelease(img);
    
    return returnImage;
}

@end


@implementation ViewController {
    UIImageView* imageView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    imageView.image = [UIImage imageNamed:@"img.png"];
    imageView.userInteractionEnabled = YES;
    imageView.layer.magnificationFilter = kCAFilterNearest;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:imageView];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageViewWasTapped:)];
    tapGesture.numberOfTapsRequired = 1;
    [imageView addGestureRecognizer:tapGesture];
}

-(void) imageViewWasTapped:(UIGestureRecognizer*)tapGesture {
    
    if (!imageView.image) {
        return;
    }
    
    // get the pixel position
    CGPoint pt = CGPointApplyAffineTransform([tapGesture locationInView:imageView], imageView.viewToImageTransform);
    PixelPosition pixelPos = {(NSInteger)floor(pt.x), (NSInteger)floor(pt.y)};

    // replace image with new image, with the pixel replaced
    imageView.image = [imageView.image imageWithPixel:pixelPos replacedByColor:[UIColor colorWithRed:0 green:1 blue:1 alpha:1.0]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
