//
//  SSStory.h
//  SocialStoryCore
//
//  Models for a generated multi-page social story.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// One page of a social story: illustration + narration audio + text.
@interface SSStoryPage : NSObject
@property (nonatomic, assign) NSInteger pageNumber;
@property (nonatomic, copy, nullable) NSString *pageTitle;
@property (nonatomic, copy, nullable) NSString *content;
@property (nonatomic, copy, nullable) NSString *illustrationURL;
@property (nonatomic, copy, nullable) NSString *audioURL;
@property (nonatomic, assign) NSInteger durationSeconds;
@end

/// A comprehension question shown after the story.
@interface SSComprehensionQA : NSObject
@property (nonatomic, copy, nullable) NSString *question;
@property (nonatomic, copy, nullable) NSString *expectedAnswer;
@end

@interface SSStory : NSObject

@property (nonatomic, copy)   NSString *storyID;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy, nullable) NSString *imageURL;   // first page illustration (list thumbnail)
@property (nonatomic, strong) NSDate   *createdAt;
@property (nonatomic, strong, nullable) NSDate *lastReadAt;
@property (nonatomic, assign) NSInteger wordCount;          // sum of page content lengths
@property (nonatomic, assign) NSInteger totalDurationSeconds;

@property (nonatomic, copy) NSArray<SSStoryPage *> *pages;
@property (nonatomic, copy) NSArray<SSComprehensionQA *> *questions;

// Parent guide (parent_guide.*)
@property (nonatomic, copy, nullable) NSString *guideBeforeReading;
@property (nonatomic, copy, nullable) NSString *guideDuringReading;
@property (nonatomic, copy, nullable) NSString *guideAfterReading;
@property (nonatomic, copy, nullable) NSString *guideReinforcement;

// voice_params
@property (nonatomic, assign) CGFloat speakingRate;        // default 0.75
@property (nonatomic, copy, nullable) NSString *voiceName;

/// Build a story from the Coze response dictionary.
+ (instancetype)storyFromCozeResponse:(NSDictionary *)json;

@end

NS_ASSUME_NONNULL_END
