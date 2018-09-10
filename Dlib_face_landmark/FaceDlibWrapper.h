//
//  FaceDlibWrapper.h
//  Dlib_face_landmark
//
//  Created by LVHAN on 2018/9/7.
//  Copyright © 2018年 Koploop. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface FaceDlibWrapper : NSObject

- (NSArray <NSArray <NSValue *> *>*)detecitonOnSampleBuffer:(CMSampleBufferRef)sampleBuffer inRects:(NSArray<NSValue *> *)rects;

@end
