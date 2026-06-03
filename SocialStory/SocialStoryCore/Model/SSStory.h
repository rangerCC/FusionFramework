//
//  SSStory.h
//  SocialStoryCore
//
//  Plain model object for a generated social story.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSStory : NSObject

@property (nonatomic, copy)   NSString *storyID;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *content;
@property (nonatomic, copy, nullable) NSString *imageURL;
@property (nonatomic, strong) NSDate   *createdAt;
@property (nonatomic, strong, nullable) NSDate *lastReadAt;
@property (nonatomic, assign) NSInteger wordCount;

+ (instancetype)storyWithTitle:(NSString *)title
                       content:(NSString *)content
                      imageURL:(nullable NSString *)imageURL
                     wordCount:(NSInteger)wordCount;

@end

NS_ASSUME_NONNULL_END
