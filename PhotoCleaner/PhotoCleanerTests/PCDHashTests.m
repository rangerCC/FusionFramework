//
//  PCDHashTests.m
//  PhotoCleanerTests
//
//  Task M0-07 acceptance tests.
//

#import <XCTest/XCTest.h>
#import <PhotoClean/PhotoClean.h>

@interface PCDHashTests : XCTestCase
@end

@implementation PCDHashTests

/// Deterministic "photo-like" test image: smooth gradients plus a few blobs,
/// drawn at any size so the same scene can be rendered at several scales.
static CGImageRef PCCreateSceneImage(size_t size, unsigned seed, BOOL rotated) CF_RETURNS_RETAINED {
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, size, size, 8, 0, rgb,
                                             (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(rgb);
    if (rotated) {
        CGContextTranslateCTM(ctx, size, 0);
        CGContextRotateCTM(ctx, M_PI_2);
    }
    CGFloat s = (CGFloat)size;
    CGContextSetRGBFillColor(ctx, 0.2, 0.4, 0.8, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, s, s));
    srand(seed);
    for (int i = 0; i < 12; i++) {
        CGFloat r = (CGFloat)(rand() % 100) / 100.0, g = (CGFloat)(rand() % 100) / 100.0, b = (CGFloat)(rand() % 100) / 100.0;
        CGFloat x = (CGFloat)(rand() % 100) / 100.0 * s, y = (CGFloat)(rand() % 100) / 100.0 * s;
        CGFloat w = (0.15 + (CGFloat)(rand() % 40) / 100.0) * s;
        CGContextSetRGBFillColor(ctx, r, g, b, 1);
        CGContextFillEllipseInRect(ctx, CGRectMake(x - w / 2, y - w / 3, w, w * 0.66));
    }
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    return image;
}

static CGImageRef PCCreateSolidImage(size_t size, CGFloat gray) CF_RETURNS_RETAINED {
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, size, size, 8, 0, rgb,
                                             (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(rgb);
    CGContextSetRGBFillColor(ctx, gray, gray, gray, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, size, size));
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    return image;
}

/// Downscales the way PhotoKit thumbnails reach the hasher: to 64px first.
static CGImageRef PCCreateThumbnail(CGImageRef source, size_t size) CF_RETURNS_RETAINED {
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, size, size, 8, 0, rgb,
                                             (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(rgb);
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    CGContextDrawImage(ctx, CGRectMake(0, 0, size, size), source);
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    return image;
}

static uint64_t PCHashOf(CGImageRef image) {
    uint64_t h = 0;
    BOOL ok = PCDHashCompute(image, &h);
    NSCAssert(ok, @"hash failed");
    return h;
}

- (void)testSameSceneDifferentSizesIsNearIdentical {
    for (unsigned seed = 1; seed <= 20; seed++) {
        CGImageRef big = PCCreateSceneImage(1024, seed, NO);
        CGImageRef small = PCCreateSceneImage(300, seed, NO);
        CGImageRef t1 = PCCreateThumbnail(big, 64), t2 = PCCreateThumbnail(small, 64);
        int d = PCHammingDistance(PCHashOf(t1), PCHashOf(t2));
        XCTAssertLessThanOrEqual(d, 2, @"seed %u", seed);
        CGImageRelease(big); CGImageRelease(small); CGImageRelease(t1); CGImageRelease(t2);
    }
}

- (void)testSolidImagesAreNotInformative {
    for (CGFloat g = 0; g <= 1.0; g += 0.25) {
        CGImageRef img = PCCreateSolidImage(64, g);
        XCTAssertFalse(PCDHashIsInformative(PCHashOf(img)), @"gray %.2f", g);
        CGImageRelease(img);
    }
}

- (void)testSceneImagesAreInformative {
    for (unsigned seed = 1; seed <= 20; seed++) {
        CGImageRef img = PCCreateSceneImage(64, seed, NO);
        XCTAssertTrue(PCDHashIsInformative(PCHashOf(img)), @"seed %u", seed);
        CGImageRelease(img);
    }
}

- (void)testRotationChangesHashSubstantially {
    for (unsigned seed = 1; seed <= 20; seed++) {
        CGImageRef a = PCCreateSceneImage(64, seed, NO);
        CGImageRef b = PCCreateSceneImage(64, seed, YES);
        XCTAssertGreaterThan(PCHammingDistance(PCHashOf(a), PCHashOf(b)), 10, @"seed %u", seed);
        CGImageRelease(a); CGImageRelease(b);
    }
}

- (void)testDifferentScenesAreFarApart {
    CGImageRef a = PCCreateSceneImage(64, 101, NO);
    CGImageRef b = PCCreateSceneImage(64, 202, NO);
    XCTAssertGreaterThan(PCHammingDistance(PCHashOf(a), PCHashOf(b)), 10);
    CGImageRelease(a); CGImageRelease(b);
}

- (void)testHammingDistance {
    XCTAssertEqual(PCHammingDistance(0, 0), 0);
    XCTAssertEqual(PCHammingDistance(0, UINT64_MAX), 64);
    XCTAssertEqual(PCHammingDistance(0xF0, 0x0F), 8);
}

- (void)testNullImageFails {
    uint64_t h = 42;
    XCTAssertFalse(PCDHashCompute(NULL, &h));
    XCTAssertEqual(h, 42ULL);
}

/// Acceptance: ≤ 0.5 ms per 64px thumbnail (measured on device; the
/// simulator number is only indicative).
- (void)testHashSpeed {
    CGImageRef img = PCCreateSceneImage(64, 7, NO);
    const int n = 2000;
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    uint64_t sink = 0;
    for (int i = 0; i < n; i++) sink ^= PCHashOf(img);
    double perImageMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0 / n;
    CGImageRelease(img);
    NSLog(@"[M0-07] dHash %.4f ms per image (sink %llu)", perImageMs, sink);
    XCTAssertLessThanOrEqual(perImageMs, 0.5);
}

@end
