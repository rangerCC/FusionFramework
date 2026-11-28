//
//  SSStoryCardCell.h
//  StoryLibrary
//
//  Waterfall card: cover image (4:3) + title (<=2 lines) + a meta line
//  (word count for user stories, page count for demo stories).
//

#import <UIKit/UIKit.h>

@class SSStory;

NS_ASSUME_NONNULL_BEGIN

@interface SSStoryCardCell : UICollectionViewCell

@property (nonatomic, class, readonly) NSString *reuseID;

/// Configure the card. `isDemo` switches the meta line wording.
- (void)configureWithStory:(SSStory *)story isDemo:(BOOL)isDemo;

/// Total cell height for a given column width, sized to fit the title.
+ (CGFloat)heightForStory:(SSStory *)story width:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
