//
//  PCDHash.m
//  PhotoClean
//

#import "PCDHash.h"

enum { kPCDHashWidth = 9, kPCDHashHeight = 8 };

BOOL PCDHashCompute(CGImageRef image, uint64_t *outHash) {
    if (image == NULL || outHash == NULL) return NO;

    uint8_t pixels[kPCDHashWidth * kPCDHashHeight] = {0};
    CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
    CGContextRef ctx = CGBitmapContextCreate(pixels, kPCDHashWidth, kPCDHashHeight, 8,
                                             kPCDHashWidth, gray, (CGBitmapInfo)kCGImageAlphaNone);
    CGColorSpaceRelease(gray);
    if (ctx == NULL) return NO;

    CGContextSetInterpolationQuality(ctx, kCGInterpolationMedium);
    CGContextDrawImage(ctx, CGRectMake(0, 0, kPCDHashWidth, kPCDHashHeight), image);
    CGContextRelease(ctx);

    uint64_t hash = 0;
    for (int y = 0; y < kPCDHashHeight; y++) {
        const uint8_t *row = pixels + y * kPCDHashWidth;
        for (int x = 0; x < kPCDHashWidth - 1; x++) {
            hash <<= 1;
            if (row[x] < row[x + 1]) hash |= 1;
        }
    }
    *outHash = hash;
    return YES;
}
