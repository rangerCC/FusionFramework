//
//  PCFeaturePrint.h
//  PhotoClean
//
//  Stage 2 semantic feature (tech plan §4.5, §17.3).
//
//  - The Vision revision is always set explicitly: features from different
//    revisions are not comparable, and the system default may change with an
//    OS update. iOS 17+: Revision2 (768-d); iOS 15/16: Revision1 (2048-d).
//  - Vectors are stored as float16 to halve storage. Distances are Euclidean
//    (L2), matching -[VNFeaturePrintObservation computeDistance:...].
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const PCFeaturePrintErrorDomain;

/// A feature vector in float16, tagged with the Vision revision that made it.
@interface PCFeatureVector : NSObject

@property (nonatomic, readonly) NSUInteger revision;
@property (nonatomic, readonly) NSUInteger dimension;
/// dimension * 2 bytes of IEEE half floats; this is what goes into the DB.
@property (nonatomic, copy, readonly) NSData *float16Data;

- (instancetype)initWithRevision:(NSUInteger)revision
                       dimension:(NSUInteger)dimension
                     float16Data:(NSData *)data NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Builds a vector from float32 values.
+ (nullable instancetype)vectorWithRevision:(NSUInteger)revision
                                    floats:(const float *)values
                                     count:(NSUInteger)count;

/// Decodes to float32. `buffer` must hold `dimension` floats.
- (void)getFloats:(float *)buffer;

/// L2 distance, or NAN if the revision or dimension differs.
- (float)distanceTo:(PCFeatureVector *)other;

@end

@interface PCFeaturePrint : NSObject

/// Revision used on this OS (Revision2 on iOS 17+, otherwise Revision1).
+ (NSUInteger)preferredRevision;

/// Extracts a feature vector. Runs synchronously; call off the main thread.
+ (nullable PCFeatureVector *)featureForImage:(CGImageRef)image
                                  orientation:(CGImagePropertyOrientation)orientation
                                        error:(NSError **)error;

/// Same, with an explicit revision (used by tests and re-extraction).
+ (nullable PCFeatureVector *)featureForImage:(CGImageRef)image
                                  orientation:(CGImagePropertyOrientation)orientation
                                     revision:(NSUInteger)revision
                                        error:(NSError **)error;

/// Returns the Vision observation as well, so callers can compare our
/// float16 distance with Vision's own computeDistance (acceptance check).
+ (nullable id)observationForImage:(CGImageRef)image
                       orientation:(CGImagePropertyOrientation)orientation
                          revision:(NSUInteger)revision
                             error:(NSError **)error;

/// Converts a VNFeaturePrintObservation into a PCFeatureVector.
+ (nullable PCFeatureVector *)vectorFromObservation:(id)observation
                                           revision:(NSUInteger)revision;

@end

NS_ASSUME_NONNULL_END
