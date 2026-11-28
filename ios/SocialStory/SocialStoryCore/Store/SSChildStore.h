//
//  SSChildStore.h
//  SocialStoryCore
//
//  In-memory cache of the account's children + the default one, shared by the
//  generation page and the children pages so they don't each refetch. Posts
//  SSChildrenDidChangeNotification when the cached set changes.
//

#import <Foundation/Foundation.h>

@class SSChild;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const SSChildrenDidChangeNotification;

@interface SSChildStore : NSObject

+ (instancetype)shared;

/// Last fetched children (may be empty until -reloadWithCompletion: runs).
@property (nonatomic, copy, readonly) NSArray<SSChild *> *children;

/// The default child, or the first child, or nil if none.
@property (nonatomic, strong, readonly, nullable) SSChild *defaultChild;

@property (nonatomic, readonly) BOOL hasAnyChild;

/// Refetch from the server and update the cache (posts the notification).
- (void)reloadWithCompletion:(nullable void (^)(NSError * _Nullable error))completion;

/// Override the in-session selected child (e.g. user picked another in the
/// generation page). Does not hit the network.
- (void)selectChild:(SSChild *)child;

@end

NS_ASSUME_NONNULL_END
