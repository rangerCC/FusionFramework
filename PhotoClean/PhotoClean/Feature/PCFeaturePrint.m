//
//  PCFeaturePrint.m
//  PhotoClean
//

#import "PCFeaturePrint.h"
#import <Vision/Vision.h>
#import <Accelerate/Accelerate.h>

NSString *const PCFeaturePrintErrorDomain = @"PCFeaturePrintErrorDomain";

#pragma mark - PCFeatureVector

@implementation PCFeatureVector

- (instancetype)initWithRevision:(NSUInteger)revision dimension:(NSUInteger)dimension float16Data:(NSData *)data {
    NSParameterAssert(data.length == dimension * sizeof(uint16_t));
    self = [super init];
    if (self) {
        _revision = revision;
        _dimension = dimension;
        _float16Data = [data copy];
    }
    return self;
}

+ (instancetype)vectorWithRevision:(NSUInteger)revision floats:(const float *)values count:(NSUInteger)count {
    if (values == NULL || count == 0) return nil;
    NSMutableData *half = [NSMutableData dataWithLength:count * sizeof(uint16_t)];
    vImage_Buffer src = { (void *)values, 1, count, count * sizeof(float) };
    vImage_Buffer dst = { half.mutableBytes, 1, count, count * sizeof(uint16_t) };
    if (vImageConvert_PlanarFtoPlanar16F(&src, &dst, kvImageNoFlags) != kvImageNoError) return nil;
    return [[self alloc] initWithRevision:revision dimension:count float16Data:half];
}

- (void)getFloats:(float *)buffer {
    vImage_Buffer src = { (void *)_float16Data.bytes, 1, _dimension, _dimension * sizeof(uint16_t) };
    vImage_Buffer dst = { buffer, 1, _dimension, _dimension * sizeof(float) };
    vImageConvert_Planar16FtoPlanarF(&src, &dst, kvImageNoFlags);
}

- (float)distanceTo:(PCFeatureVector *)other {
    if (other == nil || other.revision != _revision || other.dimension != _dimension) return NAN;
    NSUInteger n = _dimension;
    float *a = malloc(n * sizeof(float)), *b = malloc(n * sizeof(float));
    if (a == NULL || b == NULL) { free(a); free(b); return NAN; }
    [self getFloats:a];
    [other getFloats:b];
    float sq = 0;
    vDSP_distancesq(a, 1, b, 1, &sq, n);
    free(a); free(b);
    return sqrtf(sq);
}

@end

#pragma mark - PCFeaturePrint

@implementation PCFeaturePrint

+ (NSUInteger)preferredRevision {
    if (@available(iOS 17.0, *)) return VNGenerateImageFeaturePrintRequestRevision2;
    return VNGenerateImageFeaturePrintRequestRevision1;
}

+ (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message {
    return [NSError errorWithDomain:PCFeaturePrintErrorDomain code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

+ (id)observationForImage:(CGImageRef)image
              orientation:(CGImagePropertyOrientation)orientation
                 revision:(NSUInteger)revision
                    error:(NSError **)error {
    if (image == NULL) {
        if (error) *error = [self errorWithCode:1 message:@"image is NULL"];
        return nil;
    }
    if (![VNGenerateImageFeaturePrintRequest.supportedRevisions containsIndex:revision]) {
        if (error) *error = [self errorWithCode:2 message:[NSString stringWithFormat:@"revision %lu unsupported", (unsigned long)revision]];
        return nil;
    }
    VNGenerateImageFeaturePrintRequest *request = [VNGenerateImageFeaturePrintRequest new];
    request.revision = revision;
    request.imageCropAndScaleOption = VNImageCropAndScaleOptionScaleFill;

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:image
                                                                        orientation:orientation
                                                                            options:@{}];
    if (![handler performRequests:@[request] error:error]) return nil;
    VNFeaturePrintObservation *obs = (VNFeaturePrintObservation *)request.results.firstObject;
    if (![obs isKindOfClass:[VNFeaturePrintObservation class]]) {
        if (error) *error = [self errorWithCode:3 message:@"no feature print produced"];
        return nil;
    }
    return obs;
}

+ (PCFeatureVector *)vectorFromObservation:(id)observation revision:(NSUInteger)revision {
    VNFeaturePrintObservation *obs = observation;
    if (![obs isKindOfClass:[VNFeaturePrintObservation class]]) return nil;
    NSUInteger n = obs.elementCount;
    NSData *raw = obs.data;
    if (n == 0) return nil;
    switch (obs.elementType) {
        case VNElementTypeFloat:
            if (raw.length < n * sizeof(float)) return nil;
            return [PCFeatureVector vectorWithRevision:revision floats:raw.bytes count:n];
        case VNElementTypeDouble: {
            if (raw.length < n * sizeof(double)) return nil;
            float *f = malloc(n * sizeof(float));
            if (f == NULL) return nil;
            vDSP_vdpsp(raw.bytes, 1, f, 1, n);
            PCFeatureVector *v = [PCFeatureVector vectorWithRevision:revision floats:f count:n];
            free(f);
            return v;
        }
        default:
            return nil;
    }
}

+ (PCFeatureVector *)featureForImage:(CGImageRef)image
                         orientation:(CGImagePropertyOrientation)orientation
                            revision:(NSUInteger)revision
                               error:(NSError **)error {
    id obs = [self observationForImage:image orientation:orientation revision:revision error:error];
    if (obs == nil) return nil;
    PCFeatureVector *v = [self vectorFromObservation:obs revision:revision];
    if (v == nil && error) *error = [self errorWithCode:4 message:@"unsupported feature element type"];
    return v;
}

+ (PCFeatureVector *)featureForImage:(CGImageRef)image
                         orientation:(CGImagePropertyOrientation)orientation
                               error:(NSError **)error {
    return [self featureForImage:image orientation:orientation revision:[self preferredRevision] error:error];
}

@end
