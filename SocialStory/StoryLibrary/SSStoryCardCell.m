//
//  SSStoryCardCell.m
//  StoryLibrary
//

#import "SSStoryCardCell.h"
#import <SocialStoryCore/SocialStoryCore.h>
#import <SDWebImage/UIImageView+WebCache.h>

// Shared layout metrics — used by both -layoutSubviews and +heightForStory:.
static const CGFloat kImageRatio = 0.75;   // image height = width * 3/4
static const CGFloat kPad = 10.0;          // inner horizontal/vertical padding
static const CGFloat kTitleFontSize = 15.0;
static const CGFloat kMetaFontSize = 12.0;
static const CGFloat kTitleToMeta = 4.0;
static const CGFloat kMetaHeight = 16.0;
static const NSInteger kTitleMaxLines = 2;

@interface SSStoryCardCell ()
@property (nonatomic, strong) UIImageView *coverView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@end

@implementation SSStoryCardCell

+ (NSString *)reuseID { return @"SSStoryCardCell"; }

+ (UIFont *)titleFont { return [UIFont boldSystemFontOfSize:kTitleFontSize]; }

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = [SSTheme cardColor];
        self.contentView.layer.cornerRadius = 12;
        self.contentView.layer.masksToBounds = YES;

        // Soft shadow on the cell layer (outside the clipped contentView).
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.08;
        self.layer.shadowRadius = 4;
        self.layer.shadowOffset = CGSizeMake(0, 2);
        self.layer.masksToBounds = NO;

        _coverView = [UIImageView new];
        _coverView.contentMode = UIViewContentModeScaleAspectFill;
        _coverView.clipsToBounds = YES;
        _coverView.backgroundColor = [SSTheme backgroundColor];
        _coverView.isAccessibilityElement = YES;
        [self.contentView addSubview:_coverView];

        _titleLabel = [UILabel new];
        _titleLabel.font = [SSStoryCardCell titleFont];
        _titleLabel.textColor = [SSTheme primaryTextColor];
        _titleLabel.numberOfLines = kTitleMaxLines;
        [self.contentView addSubview:_titleLabel];

        _metaLabel = [UILabel new];
        _metaLabel.font = [UIFont systemFontOfSize:kMetaFontSize];
        _metaLabel.textColor = [SSTheme secondaryTextColor];
        _metaLabel.numberOfLines = 1;
        [self.contentView addSubview:_metaLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat imgH = floor(w * kImageRatio);

    self.coverView.frame = CGRectMake(0, 0, w, imgH);

    CGFloat textW = w - kPad * 2;
    CGFloat titleY = imgH + kPad;
    CGFloat titleH = [SSStoryCardCell titleHeightForText:self.titleLabel.text width:textW];
    self.titleLabel.frame = CGRectMake(kPad, titleY, textW, titleH);

    CGFloat metaY = titleY + titleH + kTitleToMeta;
    self.metaLabel.frame = CGRectMake(kPad, metaY, textW, kMetaHeight);

    // Keep the shadow path in sync for performance.
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:12].CGPath;
}

- (void)configureWithStory:(SSStory *)story isDemo:(BOOL)isDemo {
    self.titleLabel.text = story.title;
    self.coverView.accessibilityLabel = story.title;
    if (isDemo) {
        self.metaLabel.text = [NSString stringWithFormat:@"内置 · %ld 页", (long)story.pages.count];
    } else {
        self.metaLabel.text = [NSString stringWithFormat:@"%ld 字", (long)story.wordCount];
    }
    NSURL *coverURL = story.imageURL.length ? [NSURL URLWithString:story.imageURL] : nil;
    [self.coverView sd_setImageWithURL:coverURL];
    [self setNeedsLayout];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.coverView.image = nil;
    self.titleLabel.text = nil;
    self.metaLabel.text = nil;
}

#pragma mark - Sizing

+ (CGFloat)titleHeightForText:(NSString *)text width:(CGFloat)width {
    if (text.length == 0 || width <= 0) { return 0; }
    UIFont *font = [self titleFont];
    CGFloat maxH = ceil(font.lineHeight * kTitleMaxLines);
    CGRect rect = [text boundingRectWithSize:CGSizeMake(width, maxH + 1)
                                     options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                  attributes:@{NSFontAttributeName: font}
                                     context:nil];
    return ceil(MIN(rect.size.height, maxH));
}

+ (CGFloat)heightForStory:(SSStory *)story width:(CGFloat)width {
    CGFloat imgH = floor(width * kImageRatio);
    CGFloat textW = width - kPad * 2;
    CGFloat titleH = [self titleHeightForText:story.title width:textW];
    return imgH + kPad + titleH + kTitleToMeta + kMetaHeight + kPad;
}

@end
