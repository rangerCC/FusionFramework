//
//  PCClustering.h
//  PhotoClean
//
//  Candidate generation and clustering (tech plan §4.4, §4.6). Pure logic,
//  no PhotoKit or database access, so it can be unit tested in isolation.
//
//  - Similar candidates come from a time window instead of dHash: shots of
//    the same scene from different angles have large dHash distances but
//    are almost always taken within seconds of each other.
//  - Similar clustering is greedy and representative-centred: a photo joins
//    a group only if it is close to that group's representative, so A~B and
//    B~C cannot chain A and C together.
//  - Duplicate clustering uses union-find (near-duplicate is close to
//    transitive). A photo in a duplicate group is not put in a similar group.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    uint32_t first;    // first < second
    uint32_t second;
} PCIndexPair;

/// One photo as seen by the clusterer. Arrays of items must be sorted by
/// timestamp ascending; indices refer to positions in that array.
@interface PCClusterItem : NSObject
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, copy, readonly, nullable) NSString *burstIdentifier;
+ (instancetype)itemWithTimestamp:(NSTimeInterval)timestamp burstIdentifier:(nullable NSString *)burstIdentifier;
@end

typedef struct {
    NSTimeInterval windowSeconds;   // 60 by default
    NSUInteger maxNeighbors;        // 10 by default: later photos paired with each photo
    float distanceThreshold;        // FeaturePrint L2 distance; calibrated in M0-12
    NSUInteger maxGroupSize;        // 50 by default
    NSUInteger maxActiveGroups;     // 10 by default: groups a photo is compared against
} PCClusterOptions;

FOUNDATION_EXPORT PCClusterOptions PCClusterOptionsDefault(float distanceThreshold);

/// A group of at least two items. `representative` is a member of `members`.
@interface PCClusterGroup : NSObject
@property (nonatomic, readonly) NSUInteger representative;
@property (nonatomic, copy, readonly) NSIndexSet *members;
@end

/// Distance between items a and b, or NAN when unknown (e.g. no feature).
typedef float (^PCDistanceBlock)(NSUInteger a, NSUInteger b);

@interface PCClustering : NSObject

/// Pairs that need a Stage 2 comparison: each photo with up to
/// `maxNeighbors` later photos taken within `windowSeconds`, plus every
/// pair sharing a burst identifier. Sorted by (first, second), unique.
+ (NSData *)candidatePairsForItems:(NSArray<PCClusterItem *> *)items options:(PCClusterOptions)options;

/// Indices that appear in at least one candidate pair, i.e. the photos that
/// need a FeaturePrint. Everything else skips Stage 2.
+ (NSIndexSet *)indicesInPairs:(NSData *)pairs;

/// Connected components (size ≥ 2) of the pair graph over `count` items.
/// Representative is the lowest index.
+ (NSArray<PCClusterGroup *> *)duplicateGroupsWithPairs:(NSData *)pairs count:(NSUInteger)count;

/// Greedy representative-centred clustering over items not in `excluded`.
/// Only groups of size ≥ 2 are returned, ordered by representative.
+ (NSArray<PCClusterGroup *> *)similarGroupsWithItems:(NSArray<PCClusterItem *> *)items
                                             excluded:(nullable NSIndexSet *)excluded
                                              options:(PCClusterOptions)options
                                             distance:(PCDistanceBlock)distance;

@end

NS_ASSUME_NONNULL_END
