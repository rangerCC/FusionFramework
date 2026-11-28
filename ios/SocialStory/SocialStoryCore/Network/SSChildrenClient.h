//
//  SSChildrenClient.h
//  SocialStoryCore
//
//  Authenticated client for /v1/children. Base URL and bearer token come from
//  AccountKit (same source as login), so this stays in sync with the session.
//

#import <Foundation/Foundation.h>

@class SSChild;

NS_ASSUME_NONNULL_BEGIN

@interface SSChildrenClient : NSObject

+ (instancetype)shared;

/// GET /v1/children — completion on main thread.
- (void)fetchChildren:(void (^)(NSArray<SSChild *> * _Nullable children, NSError * _Nullable error))completion;

/// POST /v1/children — completion returns the created child (with server fields).
- (void)createChild:(SSChild *)child
         completion:(void (^)(SSChild * _Nullable created, NSError * _Nullable error))completion;

/// PUT /v1/children/{id} — update an existing child; returns the updated child.
- (void)updateChildID:(NSString *)childID
                child:(SSChild *)child
           completion:(void (^)(SSChild * _Nullable updated, NSError * _Nullable error))completion;

/// DELETE /v1/children/{id} — remove a child.
- (void)deleteChildID:(NSString *)childID
           completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/// POST /v1/children/{id}/default — set the account's default child.
- (void)setDefaultChildID:(NSString *)childID
               completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
