//
//  PCMultiIndexHash.m
//  PhotoClean
//

#import "PCMultiIndexHash.h"
#import "PCDHash.h"

#define PC_MAX_SEGMENTS 16

typedef struct {
    uint64_t key;
    uint32_t index;
} PCSegEntry;

static int PCSegEntryCompare(const void *a, const void *b) {
    const PCSegEntry *x = a, *y = b;
    if (x->key != y->key) return x->key < y->key ? -1 : 1;
    return x->index < y->index ? -1 : (x->index > y->index ? 1 : 0);
}

static int PCHashPairCompare(const void *a, const void *b) {
    const PCHashPair *x = a, *y = b;
    if (x->first != y->first) return x->first < y->first ? -1 : 1;
    return x->second < y->second ? -1 : (x->second > y->second ? 1 : 0);
}

@implementation PCMultiIndexHash {
    int _segmentCount;
    int _shift[PC_MAX_SEGMENTS];
    uint64_t _mask[PC_MAX_SEGMENTS];
    NSMutableData *_hashes;                                         // uint64_t[]
    NSMutableArray<NSMutableDictionary<NSNumber *, NSMutableIndexSet *> *> *_tables;
}

- (instancetype)initWithThreshold:(int)threshold {
    NSParameterAssert(threshold >= 0 && threshold < PC_MAX_SEGMENTS);
    self = [super init];
    if (self) {
        _threshold = MAX(0, MIN(threshold, PC_MAX_SEGMENTS - 1));
        _segmentCount = _threshold + 1;
        // Spread 64 bits as evenly as possible; the first (64 % m) segments
        // get one extra bit. threshold 4 -> 13/13/13/13/12.
        int base = 64 / _segmentCount, extra = 64 % _segmentCount, shift = 0;
        for (int i = 0; i < _segmentCount; i++) {
            int bits = base + (i < extra ? 1 : 0);
            _shift[i] = shift;
            _mask[i] = bits >= 64 ? UINT64_MAX : ((1ULL << bits) - 1);
            shift += bits;
        }
        _hashes = [NSMutableData new];
        _tables = [NSMutableArray arrayWithCapacity:_segmentCount];
        for (int i = 0; i < _segmentCount; i++) [_tables addObject:[NSMutableDictionary new]];
    }
    return self;
}

static inline uint64_t PCSegment(uint64_t hash, int shift, uint64_t mask) {
    return (hash >> shift) & mask;
}

- (NSUInteger)count {
    return _hashes.length / sizeof(uint64_t);
}

- (uint32_t)addHash:(uint64_t)hash {
    uint32_t index = (uint32_t)self.count;
    [_hashes appendBytes:&hash length:sizeof(hash)];
    for (int i = 0; i < _segmentCount; i++) {
        NSNumber *key = @(PCSegment(hash, _shift[i], _mask[i]));
        NSMutableIndexSet *bucket = _tables[i][key];
        if (bucket == nil) {
            bucket = [NSMutableIndexSet new];
            _tables[i][key] = bucket;
        }
        [bucket addIndex:index];
    }
    return index;
}

- (NSIndexSet *)indicesNearHash:(uint64_t)hash excluding:(uint32_t)excluding {
    const uint64_t *hashes = _hashes.bytes;
    NSMutableIndexSet *candidates = [NSMutableIndexSet new];
    for (int i = 0; i < _segmentCount; i++) {
        NSIndexSet *bucket = _tables[i][@(PCSegment(hash, _shift[i], _mask[i]))];
        if (bucket) [candidates addIndexes:bucket];
    }
    NSMutableIndexSet *result = [NSMutableIndexSet new];
    int threshold = _threshold;
    [candidates enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx == excluding) return;
        if (PCHammingDistance(hash, hashes[idx]) <= threshold) [result addIndex:idx];
    }];
    return result;
}

- (NSData *)allPairs {
    NSUInteger n = self.count;
    NSMutableData *out = [NSMutableData new];
    if (n < 2) return out;

    const uint64_t *hashes = _hashes.bytes;
    PCSegEntry *entries = malloc(n * sizeof(PCSegEntry));
    if (entries == NULL) return out;

    for (int seg = 0; seg < _segmentCount; seg++) {
        for (NSUInteger k = 0; k < n; k++) {
            entries[k].key = PCSegment(hashes[k], _shift[seg], _mask[seg]);
            entries[k].index = (uint32_t)k;
        }
        qsort(entries, n, sizeof(PCSegEntry), PCSegEntryCompare);

        NSUInteger runStart = 0;
        while (runStart < n) {
            NSUInteger runEnd = runStart + 1;
            while (runEnd < n && entries[runEnd].key == entries[runStart].key) runEnd++;
            for (NSUInteger a = runStart; a < runEnd; a++) {
                for (NSUInteger b = a + 1; b < runEnd; b++) {
                    uint64_t ha = hashes[entries[a].index], hb = hashes[entries[b].index];
                    int d = PCHammingDistance(ha, hb);
                    if (d > _threshold) continue;
                    // Report each pair only from the first segment the two
                    // hashes agree on, so no separate de-duplication is needed.
                    BOOL seenEarlier = NO;
                    for (int prev = 0; prev < seg && !seenEarlier; prev++) {
                        seenEarlier = PCSegment(ha, _shift[prev], _mask[prev]) ==
                                      PCSegment(hb, _shift[prev], _mask[prev]);
                    }
                    if (seenEarlier) continue;
                    PCHashPair pair = { entries[a].index, entries[b].index, (uint8_t)d }; // a < b within a run
                    [out appendBytes:&pair length:sizeof(pair)];
                }
            }
            runStart = runEnd;
        }
    }
    free(entries);

    qsort(out.mutableBytes, out.length / sizeof(PCHashPair), sizeof(PCHashPair), PCHashPairCompare);
    return out;
}

@end
