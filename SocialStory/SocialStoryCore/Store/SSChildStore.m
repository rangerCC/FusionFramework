//
//  SSChildStore.m
//  SocialStoryCore
//

#import "SSChildStore.h"
#import "SSChild.h"
#import "SSChildrenClient.h"

NSString *const SSChildrenDidChangeNotification = @"SSChildrenDidChangeNotification";

@interface SSChildStore ()
@property (nonatomic, copy) NSArray<SSChild *> *children;
@property (nonatomic, strong, nullable) SSChild *selectedChild; // session override
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
    if (self) { _children = @[]; }
    return self;
}

- (BOOL)hasAnyChild { return self.children.count > 0; }

- (SSChild *)defaultChild {
    // Session selection wins if it still exists in the current set.
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

- (void)reloadWithCompletion:(void (^)(NSError *))completion {
    __weak typeof(self) weakSelf = self;
    [[SSChildrenClient shared] fetchChildren:^(NSArray<SSChild *> *children, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        if (!error && children) {
            self.children = children;
            // Drop a stale session selection that no longer exists.
            if (self.selectedChild) {
                BOOL stillThere = NO;
                for (SSChild *c in children) {
                    if ([c.childID isEqualToString:self.selectedChild.childID]) { stillThere = YES; break; }
                }
                if (!stillThere) { self.selectedChild = nil; }
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:SSChildrenDidChangeNotification object:self];
        }
        if (completion) { completion(error); }
    }];
}

@end
