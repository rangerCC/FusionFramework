//
//  SSChildStore.m
//  SocialStoryCore
//

#import "SSChildStore.h"
#import "SSChild.h"

NSString *const SSChildrenDidChangeNotification = @"SSChildrenDidChangeNotification";

static NSString *const kChildrenKey = @"ss_children_local";

@interface SSChildStore ()
@property (nonatomic, copy) NSArray<SSChild *> *children;
@property (nonatomic, strong, nullable) SSChild *selectedChild;
@end

@implementation SSChildStore

+ (instancetype)shared {
    static SSChildStore *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [SSChildStore new]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) { _children = [self loadFromDefaults]; }
    return self;
}

- (BOOL)hasAnyChild { return self.children.count > 0; }

- (SSChild *)defaultChild {
    if (self.selectedChild) {
        for (SSChild *c in self.children) {
            if ([c.childID isEqualToString:self.selectedChild.childID]) { return self.selectedChild; }
        }
    }
    for (SSChild *c in self.children) {
        if (c.isDefault) { return c; }
    }
    return self.children.firstObject;
}

- (void)selectChild:(SSChild *)child {
    self.selectedChild = child;
    [[NSNotificationCenter defaultCenter] postNotificationName:SSChildrenDidChangeNotification object:self];
}

// PoC: children are stored locally in UserDefaults (no server sync).
- (void)reloadWithCompletion:(nullable void (^)(NSError *))completion {
    self.children = [self loadFromDefaults];
    if (self.selectedChild) {
        BOOL found = NO;
        for (SSChild *c in self.children) {
            if ([c.childID isEqualToString:self.selectedChild.childID]) { found = YES; break; }
        }
        if (!found) { self.selectedChild = nil; }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SSChildrenDidChangeNotification object:self];
    if (completion) { completion(nil); }
}

- (void)saveChild:(SSChild *)child {
    NSMutableArray<SSChild *> *list = [self.children mutableCopy];
    // If first child, mark default.
    if (list.count == 0) { child.isDefault = YES; }
    // Replace if same childID, otherwise append.
    BOOL replaced = NO;
    for (NSUInteger i = 0; i < list.count; i++) {
        if ([list[i].childID isEqualToString:child.childID]) {
            [list replaceObjectAtIndex:i withObject:child];
            replaced = YES; break;
        }
    }
    if (!replaced) { [list addObject:child]; }
    self.children = list;
    [self persistToDefaults:list];
    [[NSNotificationCenter defaultCenter] postNotificationName:SSChildrenDidChangeNotification object:self];
}

- (void)deleteChildWithID:(NSString *)childID {
    NSMutableArray<SSChild *> *list = [self.children mutableCopy];
    [list filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SSChild *c, id _) {
        return ![c.childID isEqualToString:childID];
    }]];
    // If we deleted the default, promote the first remaining child.
    BOOL hasDefault = NO;
    for (SSChild *c in list) { if (c.isDefault) { hasDefault = YES; break; } }
    if (!hasDefault && list.count > 0) { list.firstObject.isDefault = YES; }
    self.children = list;
    if ([self.selectedChild.childID isEqualToString:childID]) { self.selectedChild = nil; }
    [self persistToDefaults:list];
    [[NSNotificationCenter defaultCenter] postNotificationName:SSChildrenDidChangeNotification object:self];
}

#pragma mark - UserDefaults persistence

- (NSArray<SSChild *> *)loadFromDefaults {
    NSArray *raw = [[NSUserDefaults standardUserDefaults] arrayForKey:kChildrenKey];
    if (![raw isKindOfClass:[NSArray class]]) { return @[]; }
    NSMutableArray<SSChild *> *result = [NSMutableArray array];
    for (id item in raw) {
        if (![item isKindOfClass:[NSDictionary class]]) { continue; }
        SSChild *c = [SSChild childFromJSON:item];
        if (c) { [result addObject:c]; }
    }
    return result;
}

- (void)persistToDefaults:(NSArray<SSChild *> *)list {
    NSMutableArray *raw = [NSMutableArray array];
    for (SSChild *c in list) { [raw addObject:[c localStorageJSON]]; }
    [[NSUserDefaults standardUserDefaults] setObject:raw forKey:kChildrenKey];
}

@end
