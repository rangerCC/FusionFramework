//
//  PCMultiIndexHash.h
//  PhotoClean
//
//  Multi-index hashing for near-duplicate lookup (tech plan §4.4, §17.2).
//
//  The 64-bit hash is split into (threshold + 1) disjoint segments. By the
//  pigeonhole principle, two hashes within `threshold` bits of each other
//  agree exactly on at least one segment, so only items sharing a segment
//  value need a full Hamming comparison. Results are exact: identical to a
//  brute-force pairwise scan.
//
//  Not thread-safe. Build and query from a single thread (the cluster actor).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A pair of item indices (first < second) whose hashes are within threshold.
typedef struct {
    uint32_t first;
    uint32_t second;
    uint8_t distance;
} PCHashPair;

@interface PCMultiIndexHash : NSObject

/// threshold: maximum Hamming distance counted as a match, 0...15.
- (instancetype)initWithThreshold:(int)threshold NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) int threshold;
@property (nonatomic, readonly) NSUInteger count;

/// Appends a hash and returns its index (0, 1, 2, ...).
- (uint32_t)addHash:(uint64_t)hash;

/// Indices of stored hashes within threshold of `hash`, in ascending order.
/// `excluding` is skipped (pass UINT32_MAX to skip nothing).
- (NSIndexSet *)indicesNearHash:(uint64_t)hash excluding:(uint32_t)excluding;

/// Every matching pair among the stored hashes, each reported once,
/// sorted by (first, second).
- (NSData *)allPairs;   // packed PCHashPair array

@end

NS_ASSUME_NONNULL_END
