//
//  PCClustering.m
//  PhotoClean
//

#import "PCClustering.h"

PCClusterOptions PCClusterOptionsDefault(float distanceThreshold) {
    PCClusterOptions o;
    o.windowSeconds = 60;
    o.maxNeighbors = 10;
    o.distanceThreshold = distanceThreshold;
    o.maxGroupSize = 50;
    o.maxActiveGroups = 10;
    return o;
}

@implementation PCClusterItem
+ (instancetype)itemWithTimestamp:(NSTimeInterval)timestamp burstIdentifier:(NSString *)burstIdentifier {
    PCClusterItem *item = [self new];
    item->_timestamp = timestamp;
    item->_burstIdentifier = burstIdentifier.length ? [burstIdentifier copy] : nil;
    return item;
}
@end

@interface PCClusterGroup ()
@property (nonatomic, readwrite) NSUInteger representative;
@property (nonatomic, copy, readwrite) NSIndexSet *members;
@end

@implementation PCClusterGroup
- (NSString *)description {
    return [NSString stringWithFormat:@"<group rep=%lu members=%@>", (unsigned long)_representative, _members];
}
@end

static int PCIndexPairCompare(const void *a, const void *b) {
    const PCIndexPair *x = a, *y = b;
    if (x->first != y->first) return x->first < y->first ? -1 : 1;
    return x->second < y->second ? -1 : (x->second > y->second ? 1 : 0);
}

static void PCAssertSorted(NSArray<PCClusterItem *> *items) {
#if DEBUG
    for (NSUInteger i = 1; i < items.count; i++) {
        NSCAssert(items[i - 1].timestamp <= items[i].timestamp, @"items must be sorted by timestamp");
    }
#endif
}

@implementation PCClustering

+ (NSData *)candidatePairsForItems:(NSArray<PCClusterItem *> *)items options:(PCClusterOptions)options {
    PCAssertSorted(items);
    NSUInteger n = items.count;
    NSMutableData *out = [NSMutableData new];

    // Time window
    for (NSUInteger i = 0; i < n; i++) {
        NSTimeInterval t = items[i].timestamp;
        for (NSUInteger j = i + 1, taken = 0; j < n && taken < options.maxNeighbors; j++, taken++) {
            if (items[j].timestamp - t > options.windowSeconds) break;
            PCIndexPair p = { (uint32_t)i, (uint32_t)j };
            [out appendBytes:&p length:sizeof(p)];
        }
    }
    // Bursts: every pair inside a burst
    NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *bursts = [NSMutableDictionary new];
    for (NSUInteger i = 0; i < n; i++) {
        NSString *bid = items[i].burstIdentifier;
        if (!bid) continue;
        NSMutableArray *list = bursts[bid] ?: (bursts[bid] = [NSMutableArray new]);
        [list addObject:@(i)];
    }
    for (NSArray<NSNumber *> *list in bursts.allValues) {
        for (NSUInteger a = 0; a < list.count; a++) {
            for (NSUInteger b = a + 1; b < list.count; b++) {
                PCIndexPair p = { list[a].unsignedIntValue, list[b].unsignedIntValue };
                [out appendBytes:&p length:sizeof(p)];
            }
        }
    }
    // Sort and drop duplicates (a burst pair may also be a window pair)
    NSUInteger count = out.length / sizeof(PCIndexPair);
    PCIndexPair *p = out.mutableBytes;
    qsort(p, count, sizeof(PCIndexPair), PCIndexPairCompare);
    NSUInteger w = 0;
    for (NSUInteger r = 0; r < count; r++) {
        if (w > 0 && p[w - 1].first == p[r].first && p[w - 1].second == p[r].second) continue;
        p[w++] = p[r];
    }
    out.length = w * sizeof(PCIndexPair);
    return out;
}

+ (NSIndexSet *)indicesInPairs:(NSData *)pairs {
    NSMutableIndexSet *set = [NSMutableIndexSet new];
    const PCIndexPair *p = pairs.bytes;
    for (NSUInteger k = 0, n = pairs.length / sizeof(PCIndexPair); k < n; k++) {
        [set addIndex:p[k].first];
        [set addIndex:p[k].second];
    }
    return set;
}

#pragma mark - Duplicates

static uint32_t PCFind(uint32_t *parent, uint32_t x) {
    while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
    }
    return x;
}

+ (NSArray<PCClusterGroup *> *)duplicateGroupsWithPairs:(NSData *)pairs count:(NSUInteger)count {
    if (count < 2) return @[];
    uint32_t *parent = malloc(count * sizeof(uint32_t));
    if (!parent) return @[];
    for (NSUInteger i = 0; i < count; i++) parent[i] = (uint32_t)i;

    const PCIndexPair *p = pairs.bytes;
    for (NSUInteger k = 0, n = pairs.length / sizeof(PCIndexPair); k < n; k++) {
        if (p[k].first >= count || p[k].second >= count) continue;
        uint32_t a = PCFind(parent, p[k].first), b = PCFind(parent, p[k].second);
        if (a != b) parent[MAX(a, b)] = MIN(a, b);   // root is always the lowest index
    }
    NSMutableDictionary<NSNumber *, NSMutableIndexSet *> *components = [NSMutableDictionary new];
    for (NSUInteger i = 0; i < count; i++) {
        NSNumber *root = @(PCFind(parent, (uint32_t)i));
        NSMutableIndexSet *set = components[root] ?: (components[root] = [NSMutableIndexSet new]);
        [set addIndex:i];
    }
    free(parent);

    NSMutableArray *groups = [NSMutableArray new];
    for (NSNumber *root in [components.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSIndexSet *members = components[root];
        if (members.count < 2) continue;
        PCClusterGroup *g = [PCClusterGroup new];
        g.representative = root.unsignedIntegerValue;
        g.members = members;
        [groups addObject:g];
    }
    return groups;
}

#pragma mark - Similar

+ (NSArray<PCClusterGroup *> *)similarGroupsWithItems:(NSArray<PCClusterItem *> *)items
                                             excluded:(NSIndexSet *)excluded
                                              options:(PCClusterOptions)options
                                             distance:(PCDistanceBlock)distance {
    PCAssertSorted(items);
    NSMutableArray<PCClusterGroup *> *all = [NSMutableArray new];
    NSMutableArray<NSMutableIndexSet *> *allMembers = [NSMutableArray new];
    NSMutableArray<NSNumber *> *lastTime = [NSMutableArray new];   // per group
    NSMutableArray<NSNumber *> *active = [NSMutableArray new];     // group indices, oldest first

    for (NSUInteger i = 0; i < items.count; i++) {
        if ([excluded containsIndex:i]) continue;
        NSTimeInterval t = items[i].timestamp;

        // Retire groups that are full or too old to accept this photo.
        NSMutableArray *stillActive = [NSMutableArray new];
        for (NSNumber *gi in active) {
            NSUInteger g = gi.unsignedIntegerValue;
            BOOL fresh = t - lastTime[g].doubleValue <= options.windowSeconds;
            BOOL roomy = allMembers[g].count < options.maxGroupSize;
            if (fresh && roomy) [stillActive addObject:gi];
        }
        while (stillActive.count > options.maxActiveGroups) [stillActive removeObjectAtIndex:0];
        active = stillActive;

        // Join the closest representative within the threshold.
        NSInteger best = -1;
        float bestDistance = INFINITY;
        for (NSNumber *gi in active) {
            NSUInteger g = gi.unsignedIntegerValue;
            float d = distance(all[g].representative, i);
            if (isnan(d) || d > options.distanceThreshold) continue;
            if (d < bestDistance) { bestDistance = d; best = (NSInteger)g; }
        }
        if (best >= 0) {
            [allMembers[best] addIndex:i];
            lastTime[best] = @(t);
        } else {
            PCClusterGroup *g = [PCClusterGroup new];
            g.representative = i;
            [all addObject:g];
            [allMembers addObject:[NSMutableIndexSet indexSetWithIndex:i]];
            [lastTime addObject:@(t)];
            [active addObject:@(all.count - 1)];
        }
    }

    NSMutableArray *result = [NSMutableArray new];
    for (NSUInteger g = 0; g < all.count; g++) {
        if (allMembers[g].count < 2) continue;
        all[g].members = allMembers[g];
        [result addObject:all[g]];
    }
    return result;
}

@end
