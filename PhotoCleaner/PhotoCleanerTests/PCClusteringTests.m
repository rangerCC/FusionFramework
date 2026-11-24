//
//  PCClusteringTests.m
//  PhotoCleanerTests
//
//  Task M0-11 acceptance tests.
//

#import <XCTest/XCTest.h>
#import <PhotoClean/PhotoClean.h>

@interface PCClusteringTests : XCTestCase
@end

@implementation PCClusteringTests

static NSArray<PCClusterItem *> *PCItems(NSArray<NSNumber *> *times) {
    NSMutableArray *a = [NSMutableArray new];
    for (NSNumber *t in times) [a addObject:[PCClusterItem itemWithTimestamp:t.doubleValue burstIdentifier:nil]];
    return a;
}

static NSSet<NSString *> *PCPairSet(NSData *pairs) {
    NSMutableSet *s = [NSMutableSet new];
    const PCIndexPair *p = pairs.bytes;
    for (NSUInteger k = 0; k < pairs.length / sizeof(PCIndexPair); k++) {
        [s addObject:[NSString stringWithFormat:@"%u-%u", p[k].first, p[k].second]];
    }
    return s;
}

/// Distance table: unspecified pairs are far apart (1.0).
static PCDistanceBlock PCDistances(NSDictionary<NSString *, NSNumber *> *table) {
    return ^float(NSUInteger a, NSUInteger b) {
        NSString *key = [NSString stringWithFormat:@"%lu-%lu", (unsigned long)MIN(a, b), (unsigned long)MAX(a, b)];
        NSNumber *d = table[key];
        return d ? d.floatValue : 1.0f;
    };
}

#pragma mark - Candidates

- (void)testWindowPairs {
    // 0,10,20 within 60 s of each other; 200 is alone; 230 pairs with 200
    NSArray *items = PCItems(@[@0, @10, @20, @200, @230]);
    NSData *pairs = [PCClustering candidatePairsForItems:items options:PCClusterOptionsDefault(0.5)];
    NSSet *expected = [NSSet setWithArray:@[@"0-1", @"0-2", @"1-2", @"3-4"]];
    XCTAssertEqualObjects(PCPairSet(pairs), expected);
}

- (void)testMaxNeighborsCapsPairs {
    NSMutableArray *times = [NSMutableArray new];
    for (int i = 0; i < 30; i++) [times addObject:@(i)];   // 30 photos within 30 s
    NSData *pairs = [PCClustering candidatePairsForItems:PCItems(times) options:PCClusterOptionsDefault(0.5)];
    const PCIndexPair *p = pairs.bytes;
    NSUInteger n = pairs.length / sizeof(PCIndexPair);
    for (NSUInteger k = 0; k < n; k++) XCTAssertLessThanOrEqual(p[k].second - p[k].first, 10u);
    // each photo pairs with min(10, remaining) later photos
    NSUInteger expected = 0;
    for (int i = 0; i < 30; i++) expected += MIN(10, 29 - i);
    XCTAssertEqual(n, expected);
}

- (void)testBurstPairsIgnoreWindowAndCap {
    NSMutableArray *items = [NSMutableArray new];
    for (int i = 0; i < 15; i++) [items addObject:[PCClusterItem itemWithTimestamp:i * 0.1 burstIdentifier:@"B"]];
    [items addObject:[PCClusterItem itemWithTimestamp:500 burstIdentifier:@"B"]];   // same burst, far in time
    NSData *pairs = [PCClustering candidatePairsForItems:items options:PCClusterOptionsDefault(0.5)];
    NSSet *s = PCPairSet(pairs);
    XCTAssertTrue([s containsObject:@"0-14"], @"burst pairs beyond the neighbour cap");
    XCTAssertTrue([s containsObject:@"0-15"], @"burst pairs beyond the time window");
    XCTAssertEqual(s.count, 16u * 15u / 2u, @"all burst pairs, no duplicates");
}

- (void)testIndicesInPairs {
    NSArray *items = PCItems(@[@0, @10, @500, @1000, @1001]);
    NSData *pairs = [PCClustering candidatePairsForItems:items options:PCClusterOptionsDefault(0.5)];
    NSMutableIndexSet *expected = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)];
    [expected addIndexesInRange:NSMakeRange(3, 2)];
    XCTAssertEqualObjects([PCClustering indicesInPairs:pairs], expected);
}

#pragma mark - Duplicates

- (void)testDuplicateGroupsUnionFind {
    PCIndexPair raw[] = { {0, 3}, {3, 5}, {1, 2}, {7, 8} };
    NSData *pairs = [NSData dataWithBytes:raw length:sizeof(raw)];
    NSArray<PCClusterGroup *> *groups = [PCClustering duplicateGroupsWithPairs:pairs count:10];
    XCTAssertEqual(groups.count, 3u);
    XCTAssertEqual(groups[0].representative, 0u);
    XCTAssertEqualObjects(groups[0].members, ([self set:@[@0, @3, @5]]));
    XCTAssertEqualObjects(groups[1].members, ([self set:@[@1, @2]]));
    XCTAssertEqualObjects(groups[2].members, ([self set:@[@7, @8]]));
}

- (NSIndexSet *)set:(NSArray<NSNumber *> *)values {
    NSMutableIndexSet *s = [NSMutableIndexSet new];
    for (NSNumber *v in values) [s addIndex:v.unsignedIntegerValue];
    return s;
}

#pragma mark - Similar

/// A~B and B~C but A and C are not similar: A and C must not end up together.
- (void)testNoChainMerging {
    NSArray *items = PCItems(@[@0, @5, @10]);
    PCDistanceBlock d = PCDistances(@{@"0-1": @0.3, @"1-2": @0.3, @"0-2": @0.9});
    NSArray<PCClusterGroup *> *groups = [PCClustering similarGroupsWithItems:items excluded:nil
                                                                     options:PCClusterOptionsDefault(0.5) distance:d];
    XCTAssertEqual(groups.count, 1u);
    XCTAssertEqualObjects(groups[0].members, ([self set:@[@0, @1]]));
}

- (void)testLongChainDoesNotCollapse {
    // 20 photos, each similar only to its neighbours: no group may contain
    // two photos that are not similar to each other's representative.
    NSMutableArray *times = [NSMutableArray new];
    NSMutableDictionary *table = [NSMutableDictionary new];
    for (int i = 0; i < 20; i++) {
        [times addObject:@(i)];
        if (i > 0) table[[NSString stringWithFormat:@"%d-%d", i - 1, i]] = @0.3;
    }
    NSArray<PCClusterGroup *> *groups = [PCClustering similarGroupsWithItems:PCItems(times) excluded:nil
                                                                     options:PCClusterOptionsDefault(0.5)
                                                                    distance:PCDistances(table)];
    for (PCClusterGroup *g in groups) XCTAssertLessThanOrEqual(g.members.count, 2u);
}

- (void)testJoinsClosestRepresentative {
    // Two scenes interleaved within the window
    NSArray *items = PCItems(@[@0, @1, @2, @3]);
    PCDistanceBlock d = PCDistances(@{@"0-2": @0.2, @"1-3": @0.2, @"0-3": @0.45, @"1-2": @0.45});
    NSArray<PCClusterGroup *> *groups = [PCClustering similarGroupsWithItems:items excluded:nil
                                                                     options:PCClusterOptionsDefault(0.5) distance:d];
    XCTAssertEqual(groups.count, 2u);
    XCTAssertEqualObjects(groups[0].members, ([self set:@[@0, @2]]));
    XCTAssertEqualObjects(groups[1].members, ([self set:@[@1, @3]]));
}

- (void)testTimeWindowSplitsGroups {
    NSArray *items = PCItems(@[@0, @30, @500, @520]);
    PCDistanceBlock all = ^float(NSUInteger a, NSUInteger b) { return 0.1f; };
    NSArray<PCClusterGroup *> *groups = [PCClustering similarGroupsWithItems:items excluded:nil
                                                                     options:PCClusterOptionsDefault(0.5) distance:all];
    XCTAssertEqual(groups.count, 2u);
    XCTAssertEqualObjects(groups[0].members, ([self set:@[@0, @1]]));
    XCTAssertEqualObjects(groups[1].members, ([self set:@[@2, @3]]));
}

- (void)testGroupSizeCap {
    NSMutableArray *times = [NSMutableArray new];
    for (int i = 0; i < 120; i++) [times addObject:@(i * 0.2)];
    PCDistanceBlock all = ^float(NSUInteger a, NSUInteger b) { return 0.1f; };
    NSArray<PCClusterGroup *> *groups = [PCClustering similarGroupsWithItems:PCItems(times) excluded:nil
                                                                     options:PCClusterOptionsDefault(0.5) distance:all];
    NSUInteger total = 0;
    for (PCClusterGroup *g in groups) {
        XCTAssertLessThanOrEqual(g.members.count, 50u);
        total += g.members.count;
    }
    XCTAssertEqual(total, 120u);
    XCTAssertEqual(groups.count, 3u);
}

- (void)testExcludedAndUnknownDistance {
    NSArray *items = PCItems(@[@0, @1, @2, @3]);
    PCDistanceBlock d = ^float(NSUInteger a, NSUInteger b) {
        if (a == 3 || b == 3) return NAN;   // photo 3 has no feature
        return 0.1f;
    };
    NSArray<PCClusterGroup *> *groups = [PCClustering similarGroupsWithItems:items excluded:[self set:@[@1]]
                                                                     options:PCClusterOptionsDefault(0.5) distance:d];
    XCTAssertEqual(groups.count, 1u);
    XCTAssertEqualObjects(groups[0].members, ([self set:@[@0, @2]]));
}

@end
