//
//  PCFeaturePrintTests.m
//  PhotoCleanerTests
//
//  Task M0-10 acceptance tests. Uses synthetic images; the real-photo check
//  against the labelled set happens in M0-12.
//

#import <XCTest/XCTest.h>
#import <Vision/Vision.h>
#import <Accelerate/Accelerate.h>
#import <PhotoClean/PhotoClean.h>

@interface PCFeaturePrintTests : XCTestCase
@end

@implementation PCFeaturePrintTests

/// Scene with random blobs; `jitter` shifts every blob slightly so the same
/// seed with jitter > 0 behaves like a second shot of the same scene.
static CGImageRef PCCreateScene(size_t size, unsigned seed, CGFloat jitter) CF_RETURNS_RETAINED {
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, size, size, 8, 0, rgb,
                                             (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(rgb);
    CGFloat s = (CGFloat)size;
    srand(seed);
    CGContextSetRGBFillColor(ctx, (rand() % 100) / 100.0, (rand() % 100) / 100.0, (rand() % 100) / 100.0, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, s, s));
    for (int i = 0; i < 14; i++) {
        CGFloat r = (rand() % 100) / 100.0, g = (rand() % 100) / 100.0, b = (rand() % 100) / 100.0;
        CGFloat x = (rand() % 100) / 100.0 * s + jitter * s, y = (rand() % 100) / 100.0 * s - jitter * s;
        CGFloat w = (0.1 + (rand() % 40) / 100.0) * s;
        CGContextSetRGBFillColor(ctx, r, g, b, 1);
        if (i % 2) CGContextFillEllipseInRect(ctx, CGRectMake(x - w / 2, y - w / 2, w, w * 0.7));
        else CGContextFillRect(ctx, CGRectMake(x - w / 2, y - w / 2, w * 0.8, w));
    }
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    return image;
}

- (void)testPreferredRevisionMatchesOS {
    if (@available(iOS 17.0, *)) {
        XCTAssertEqual([PCFeaturePrint preferredRevision], (NSUInteger)VNGenerateImageFeaturePrintRequestRevision2);
    } else {
        XCTAssertEqual([PCFeaturePrint preferredRevision], (NSUInteger)VNGenerateImageFeaturePrintRequestRevision1);
    }
}

- (void)testExtractsVectorWithExpectedDimension {
    CGImageRef img = PCCreateScene(360, 1, 0);
    NSError *error = nil;
    PCFeatureVector *v = [PCFeaturePrint featureForImage:img orientation:kCGImagePropertyOrientationUp error:&error];
    CGImageRelease(img);
    XCTAssertNotNil(v, @"%@", error);
    XCTAssertEqual(v.revision, [PCFeaturePrint preferredRevision]);
    if (v.revision == VNGenerateImageFeaturePrintRequestRevision2) XCTAssertEqual(v.dimension, 768u);
    if (v.revision == VNGenerateImageFeaturePrintRequestRevision1) XCTAssertEqual(v.dimension, 2048u);
    XCTAssertEqual(v.float16Data.length, v.dimension * 2);
    NSLog(@"[M0-10] revision %lu, dimension %lu", (unsigned long)v.revision, (unsigned long)v.dimension);
}

- (void)testFloat16RoundTrip {
    const NSUInteger n = 768;
    float in[768], out[768];
    for (NSUInteger i = 0; i < n; i++) in[i] = sinf((float)i * 0.37f) * 0.2f;
    PCFeatureVector *v = [PCFeatureVector vectorWithRevision:2 floats:in count:n];
    PCFeatureVector *copy = [[PCFeatureVector alloc] initWithRevision:2 dimension:n float16Data:v.float16Data];
    [copy getFloats:out];
    for (NSUInteger i = 0; i < n; i++) XCTAssertEqualWithAccuracy(out[i], in[i], 1e-3);
    XCTAssertEqualWithAccuracy([v distanceTo:copy], 0.0f, 1e-6);
}

- (void)testDifferentRevisionsAreNotComparable {
    float a[4] = {1, 0, 0, 0};
    PCFeatureVector *r1 = [PCFeatureVector vectorWithRevision:1 floats:a count:4];
    PCFeatureVector *r2 = [PCFeatureVector vectorWithRevision:2 floats:a count:4];
    XCTAssertTrue(isnan([r1 distanceTo:r2]));
}

- (void)testSimilarShotsAreCloserThanDifferentScenes {
    NSUInteger rev = [PCFeaturePrint preferredRevision];
    int ok = 0, total = 0;
    for (unsigned seed = 1; seed <= 10; seed++) {
        CGImageRef a = PCCreateScene(360, seed, 0), b = PCCreateScene(360, seed, 0.02);
        CGImageRef c = PCCreateScene(360, seed + 1000, 0);
        PCFeatureVector *va = [PCFeaturePrint featureForImage:a orientation:kCGImagePropertyOrientationUp revision:rev error:nil];
        PCFeatureVector *vb = [PCFeaturePrint featureForImage:b orientation:kCGImagePropertyOrientationUp revision:rev error:nil];
        PCFeatureVector *vc = [PCFeaturePrint featureForImage:c orientation:kCGImagePropertyOrientationUp revision:rev error:nil];
        CGImageRelease(a); CGImageRelease(b); CGImageRelease(c);
        total++;
        if ([va distanceTo:vb] < [va distanceTo:vc]) ok++;
    }
    XCTAssertGreaterThanOrEqual(ok, 9, @"%d/%d", ok, total);
}

/// Acceptance: our float16 L2 distance and Vision's computeDistance must make
/// the same similar/not-similar decision in ≥ 99.5% of pairs. Thresholds are
/// unknown before M0-12, so the check is run at several quantiles of the
/// observed distance distribution.
- (void)testFloat16DistanceAgreesWithVision {
    NSUInteger rev = [PCFeaturePrint preferredRevision];
    NSMutableArray *observations = [NSMutableArray new];
    NSMutableArray<PCFeatureVector *> *vectors = [NSMutableArray new];
    for (unsigned seed = 1; seed <= 20; seed++) {
        for (int shot = 0; shot < 2; shot++) {
            CGImageRef img = PCCreateScene(360, seed, shot * 0.015);
            VNFeaturePrintObservation *obs = [PCFeaturePrint observationForImage:img orientation:kCGImagePropertyOrientationUp revision:rev error:nil];
            CGImageRelease(img);
            XCTAssertNotNil(obs);
            if (!obs) return;
            [observations addObject:obs];
            [vectors addObject:[PCFeaturePrint vectorFromObservation:obs revision:rev]];
        }
    }
    NSUInteger n = observations.count, pairs = n * (n - 1) / 2, k = 0;
    float *ours = malloc(pairs * sizeof(float)), *vision = malloc(pairs * sizeof(float));
    double maxRel = 0;
    for (NSUInteger i = 0; i < n; i++) {
        for (NSUInteger j = i + 1; j < n; j++, k++) {
            float d = 0;
            XCTAssertTrue([observations[i] computeDistance:&d toFeaturePrintObservation:observations[j] error:nil]);
            vision[k] = d;
            ours[k] = [vectors[i] distanceTo:vectors[j]];
            if (d > 1e-6) maxRel = MAX(maxRel, fabs(ours[k] - d) / d);
        }
    }
    float *sorted = malloc(pairs * sizeof(float));
    memcpy(sorted, vision, pairs * sizeof(float));
    vDSP_vsort(sorted, pairs, 1);
    double quantiles[] = {0.02, 0.05, 0.1, 0.25, 0.5};
    for (int q = 0; q < 5; q++) {
        float t = sorted[(NSUInteger)(quantiles[q] * (pairs - 1))];
        NSUInteger agree = 0;
        for (NSUInteger p = 0; p < pairs; p++) agree += ((ours[p] <= t) == (vision[p] <= t));
        double rate = (double)agree / pairs;
        NSLog(@"[M0-10] threshold q%.2f=%.4f agreement %.4f", quantiles[q], t, rate);
        XCTAssertGreaterThanOrEqual(rate, 0.995);
    }
    NSLog(@"[M0-10] %lu pairs, max relative distance error %.5f", (unsigned long)pairs, maxRel);
    free(ours); free(vision); free(sorted);
}

/// Acceptance (high-tier device): ≤ 20 ms per 360px image. Only enforced on
/// device; the simulator has no Neural Engine.
- (void)testExtractionSpeed {
    CGImageRef img = PCCreateScene(360, 3, 0);
    [PCFeaturePrint featureForImage:img orientation:kCGImagePropertyOrientationUp error:nil]; // warm up
    const int n = 30;
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    for (int i = 0; i < n; i++) {
        @autoreleasepool {
            [PCFeaturePrint featureForImage:img orientation:kCGImagePropertyOrientationUp error:nil];
        }
    }
    double ms = (CFAbsoluteTimeGetCurrent() - start) * 1000.0 / n;
    CGImageRelease(img);
    NSLog(@"[M0-10] FeaturePrint %.2f ms per image", ms);
#if !TARGET_OS_SIMULATOR
    XCTAssertLessThanOrEqual(ms, 20.0);
#endif
}

@end
