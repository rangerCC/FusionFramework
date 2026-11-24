//
//  PCMultiIndexHashTests.m
//  PhotoCleanerTests
//
//  Task M0-08 acceptance tests: results must match a brute-force scan
//  exactly, and a 10K full self-join must finish within 1 second.
//

#import <XCTest/XCTest.h>
#import <PhotoClean/PhotoClean.h>

@interface PCMultiIndexHashTests : XCTestCase
@end

@implementation PCMultiIndexHashTests

static uint64_t PCRand64(uint64_t *state) {
    // splitmix64: deterministic, good bit distribution
    uint64_t z = (*state += 0x9E3779B97F4A7C15ULL);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}

static uint64_t PCFlipBits(uint64_t h, int count, uint64_t *state) {
    while (count > 0) {
        uint64_t bit = 1ULL << (PCRand64(state) % 64);
        if (h & bit) { h &= ~bit; } else { h |= bit; }
        count--;
        // a bit may be flipped twice; that only lowers the distance
    }
    return h;
}

/// 10K hashes: random ones plus clusters of near duplicates at distances
/// 0...6 so that both sides of the threshold are exercised.
static NSData *PCMakeDataset(NSUInteger total, uint64_t seed) {
    uint64_t state = seed;
    NSMutableData *data = [NSMutableData dataWithLength:total * sizeof(uint64_t)];
    uint64_t *h = data.mutableBytes;
    NSUInteger i = 0;
    while (i < total) {
        uint64_t base = PCRand64(&state);
        h[i++] = base;
        if (PCRand64(&state) % 4 == 0) {          // 25% of items get variants
            int variants = 1 + (int)(PCRand64(&state) % 4);
            for (int v = 0; v < variants && i < total; v++) {
                h[i++] = PCFlipBits(base, (int)(PCRand64(&state) % 7), &state);
            }
        }
    }
    return data;
}

static NSSet<NSString *> *PCBrutePairs(const uint64_t *h, NSUInteger n, int threshold) {
    NSMutableSet *set = [NSMutableSet new];
    for (NSUInteger a = 0; a < n; a++) {
        for (NSUInteger b = a + 1; b < n; b++) {
            if (PCHammingDistance(h[a], h[b]) <= threshold) {
                [set addObject:[NSString stringWithFormat:@"%lu-%lu", (unsigned long)a, (unsigned long)b]];
            }
        }
    }
    return set;
}

- (void)checkAllPairsMatchBruteForceWithThreshold:(int)threshold count:(NSUInteger)n {
    NSData *data = PCMakeDataset(n, 0xC0FFEE + threshold);
    const uint64_t *h = data.bytes;
    PCMultiIndexHash *index = [[PCMultiIndexHash alloc] initWithThreshold:threshold];
    for (NSUInteger i = 0; i < n; i++) XCTAssertEqual([index addHash:h[i]], (uint32_t)i);

    NSData *pairs = [index allPairs];
    const PCHashPair *p = pairs.bytes;
    NSUInteger pairCount = pairs.length / sizeof(PCHashPair);
    NSMutableSet *found = [NSMutableSet new];
    for (NSUInteger k = 0; k < pairCount; k++) {
        XCTAssertLessThan(p[k].first, p[k].second);
        XCTAssertEqual(p[k].distance, PCHammingDistance(h[p[k].first], h[p[k].second]));
        if (k > 0) {
            BOOL ordered = p[k - 1].first < p[k].first ||
                           (p[k - 1].first == p[k].first && p[k - 1].second < p[k].second);
            XCTAssertTrue(ordered, @"pairs must be sorted and unique");
        }
        [found addObject:[NSString stringWithFormat:@"%u-%u", p[k].first, p[k].second]];
    }
    NSSet *expected = PCBrutePairs(h, n, threshold);
    XCTAssertGreaterThan(expected.count, 0u);
    XCTAssertEqualObjects(found, expected, @"threshold %d", threshold);
}

- (void)testAllPairsMatchesBruteForceThreshold4 {
    [self checkAllPairsMatchBruteForceWithThreshold:4 count:10000];
}

- (void)testAllPairsMatchesBruteForceOtherThresholds {
    for (int t = 0; t <= 8; t++) {
        if (t == 4) continue;
        [self checkAllPairsMatchBruteForceWithThreshold:t count:3000];
    }
}

- (void)testQueryMatchesBruteForce {
    const NSUInteger n = 10000;
    NSData *data = PCMakeDataset(n, 42);
    const uint64_t *h = data.bytes;
    PCMultiIndexHash *index = [[PCMultiIndexHash alloc] initWithThreshold:4];
    for (NSUInteger i = 0; i < n; i++) [index addHash:h[i]];

    for (NSUInteger q = 0; q < n; q += 37) {
        NSMutableIndexSet *expected = [NSMutableIndexSet new];
        for (NSUInteger i = 0; i < n; i++) {
            if (i != q && PCHammingDistance(h[q], h[i]) <= 4) [expected addIndex:i];
        }
        XCTAssertEqualObjects([index indicesNearHash:h[q] excluding:(uint32_t)q], expected, @"query %lu", (unsigned long)q);
    }
}

- (void)testEmptyAndSingle {
    PCMultiIndexHash *index = [[PCMultiIndexHash alloc] initWithThreshold:4];
    XCTAssertEqual([index allPairs].length, 0u);
    [index addHash:123];
    XCTAssertEqual([index allPairs].length, 0u);
    XCTAssertEqual([index indicesNearHash:123 excluding:UINT32_MAX].count, 1u);
}

/// Acceptance: full self-join of 10K hashes ≤ 1 s.
- (void)testTenThousandSelfJoinSpeed {
    NSData *data = PCMakeDataset(10000, 7);
    const uint64_t *h = data.bytes;
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    PCMultiIndexHash *index = [[PCMultiIndexHash alloc] initWithThreshold:4];
    for (NSUInteger i = 0; i < 10000; i++) [index addHash:h[i]];
    NSData *pairs = [index allPairs];
    double seconds = CFAbsoluteTimeGetCurrent() - start;
    NSLog(@"[M0-08] 10K build + self-join %.3f s, %lu pairs", seconds, (unsigned long)(pairs.length / sizeof(PCHashPair)));
    XCTAssertLessThanOrEqual(seconds, 1.0);
}

@end
