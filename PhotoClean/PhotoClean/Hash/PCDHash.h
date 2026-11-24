//
//  PCDHash.h
//  PhotoClean
//
//  Stage 1 perceptual hash (tech plan §4.4, §17.1).
//
//  dHash: downscale to 9x8 grayscale, compare each pixel with its right-hand
//  neighbour, giving 64 bits. Bits are packed row-major, most significant bit
//  first. The input should already be small (e.g. the 64px PhotoKit
//  thumbnail); drawing a full-size image straight into 9x8 aliases badly.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// Computes the dHash of `image`. Returns NO (and leaves *outHash untouched)
/// if a bitmap context could not be created.
FOUNDATION_EXPORT BOOL PCDHashCompute(CGImageRef image, uint64_t *outHash);

/// Number of differing bits between two hashes (0...64).
static inline int PCHammingDistance(uint64_t a, uint64_t b) {
    return __builtin_popcountll(a ^ b);
}

/// Low-information images (solid colour, black screens) produce hashes that
/// are almost all 0 or all 1 and would match each other spuriously. Such
/// hashes must not take part in duplicate detection.
static inline BOOL PCDHashIsInformative(uint64_t hash) {
    int ones = __builtin_popcountll(hash);
    return ones >= 4 && ones <= 60;
}

NS_ASSUME_NONNULL_END
