//
//  FaceDlibWrapper.m
//  Dlib_face_landmark
//
//  Created by LVHAN on 2018/9/7.
//  Copyright © 2018年 Koploop. All rights reserved.
//

#import "FaceDlibWrapper.h"
#import <UIKit/UIKit.h>
#import <dlib/image_processing.h>
#import <dlib/image_io.h>

@implementation FaceDlibWrapper
{
    dlib::shape_predictor sp;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        //初始化 检测器
        NSString *modelFileName = [[NSBundle mainBundle] pathForResource:@"shape_predictor_68_face_landmarks" ofType:@"dat"];
        std::string modelFileNameCString = [modelFileName UTF8String];
        dlib::deserialize(modelFileNameCString) >> sp;
    }
    return self;
}

//之所以 return 的数组 看起来比较啰嗦 但是是为了让你们看清，也可以不这么写
- (NSArray <NSArray <NSValue *> *>*)detecitonOnSampleBuffer:(CMSampleBufferRef)sampleBuffer inRects:(NSArray<NSValue *> *)rects {


    dlib::array2d<dlib::bgr_pixel> img;
    dlib::array2d<dlib::bgr_pixel> img_gray;
    // MARK: magic
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    char *baseBuffer = (char *)CVPixelBufferGetBaseAddress(imageBuffer);

    // set_size expects rows, cols format
    img.set_size(height, width);

    // copy samplebuffer image data into dlib image format
    img.reset();
    long position = 0;
    while (img.move_next()) {
        dlib::bgr_pixel& pixel = img.element();

        // assuming bgra format here
        long bufferLocation = position * 4; //(row * width + column) * 4;
        char b = baseBuffer[bufferLocation];
        char g = baseBuffer[bufferLocation + 1];
        char r = baseBuffer[bufferLocation + 2];
        //        we do not need this
        //        char a = baseBuffer[bufferLocation + 3];

        dlib::bgr_pixel newpixel(b, g, r);
        pixel = newpixel;

        position++;
    }

    // unlock buffer again until we need it again
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

    // convert the face bounds list to dlib format
    std::vector<dlib::rectangle> convertedRectangles = [self convertCGRectValueArray:rects];
    dlib::assign_image(img_gray, img);


    NSMutableArray *facesLandmarks = [NSMutableArray arrayWithCapacity:0];
    for (unsigned long j = 0; j < convertedRectangles.size(); ++j)
    {
        dlib::rectangle oneFaceRect = convertedRectangles[j];

        // detect all landmarks
        dlib::full_object_detection shape = sp(img, oneFaceRect);

        //shape 里面就是我们所需要的68 个点 因为dilb 跟 opencv 冲突 所以我们转换成Foundation 的 Array

        NSMutableArray *landmarks = [NSMutableArray arrayWithCapacity:0];
        for (int i = 0; i < shape.num_parts(); i++) {
            dlib::point p = shape.part(i);
            [landmarks addObject:[NSValue valueWithCGPoint:CGPointMake(p.x(), p.y())]];
        }
        [facesLandmarks addObject:landmarks];
    }

    return facesLandmarks;
}
- (std::vector<dlib::rectangle>)convertCGRectValueArray:(NSArray<NSValue *> *)rects {
    std::vector<dlib::rectangle> myConvertedRects;
    for (NSValue *rectValue in rects) {
        CGRect rect = [rectValue CGRectValue];
        long left = rect.origin.x;
        long top = rect.origin.y;
        long right = left + rect.size.width;
        long bottom = top + rect.size.height;
        dlib::rectangle dlibRect(left, top, right, bottom);

        myConvertedRects.push_back(dlibRect);
    }
    return myConvertedRects;
}

@end
