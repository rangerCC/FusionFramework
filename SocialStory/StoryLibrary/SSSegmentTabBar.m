//
//  SSSegmentTabBar.m
//  StoryLibrary
//

#import "SSSegmentTabBar.h"
#import <SocialStoryCore/SocialStoryCore.h>

static const CGFloat kIndicatorHeight = 3.0;
static const CGFloat kIndicatorWidthRatio = 0.4; // underline width = tab width * ratio

@interface SSSegmentTabBar ()
@property (nonatomic, strong) NSArray<UIButton *> *buttons;
@property (nonatomic, strong) UIView *indicator;
@property (nonatomic, strong) UIView *hairline;
@end

@implementation SSSegmentTabBar

- (instancetype)initWithTitles:(NSArray<NSString *> *)titles {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _selectedIndex = 0;
        self.backgroundColor = [SSTheme cardColor];

        NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
        [titles enumerateObjectsUsingBlock:^(NSString *title, NSUInteger idx, BOOL *stop) {
            UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
            [b setTitle:title forState:UIControlStateNormal];
            b.titleLabel.font = [UIFont systemFontOfSize:16];
            b.tag = idx;
            [b addTarget:self action:@selector(onTap:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:b];
            [buttons addObject:b];
        }];
        _buttons = buttons;

        // Bottom hairline separator.
        _hairline = [UIView new];
        _hairline.backgroundColor = [[SSTheme secondaryTextColor] colorWithAlphaComponent:0.2];
        [self addSubview:_hairline];

        _indicator = [UIView new];
        _indicator.backgroundColor = [SSTheme accentColor];
        _indicator.layer.cornerRadius = kIndicatorHeight / 2.0;
        [self addSubview:_indicator];

        [self refreshButtonStyles];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    NSUInteger count = self.buttons.count;
    if (count == 0 || w <= 0) { return; }

    CGFloat tabW = w / (CGFloat)count;
    for (NSUInteger i = 0; i < count; i++) {
        self.buttons[i].frame = CGRectMake(i * tabW, 0, tabW, h - kIndicatorHeight);
    }
    self.hairline.frame = CGRectMake(0, h - 0.5, w, 0.5);
    [self layoutIndicatorAnimated:NO];
}

- (void)layoutIndicatorAnimated:(BOOL)animated {
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    NSUInteger count = self.buttons.count;
    if (count == 0 || w <= 0) { return; }
    if (self.selectedIndex < 0 || self.selectedIndex >= (NSInteger)count) { return; }

    CGFloat tabW = w / (CGFloat)count;
    CGFloat indW = tabW * kIndicatorWidthRatio;
    CGFloat x = self.selectedIndex * tabW + (tabW - indW) / 2.0;
    CGRect target = CGRectMake(x, h - kIndicatorHeight, indW, kIndicatorHeight);

    void (^apply)(void) = ^{ self.indicator.frame = target; };
    if (animated) {
        [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseInOut
                         animations:apply completion:nil];
    } else {
        apply();
    }
}

- (void)refreshButtonStyles {
    for (NSUInteger i = 0; i < self.buttons.count; i++) {
        UIButton *b = self.buttons[i];
        BOOL selected = ((NSInteger)i == self.selectedIndex);
        [b setTitleColor:(selected ? [SSTheme primaryTextColor] : [SSTheme secondaryTextColor])
                forState:UIControlStateNormal];
        b.titleLabel.font = selected ? [UIFont boldSystemFontOfSize:16] : [UIFont systemFontOfSize:16];
    }
}

- (void)onTap:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx == self.selectedIndex) { return; }
    [self setSelectedIndex:idx];
    if (self.onSelect) { self.onSelect(idx); }
}

- (void)setSelectedIndex:(NSInteger)selectedIndex {
    if (_selectedIndex == selectedIndex) { return; }
    _selectedIndex = selectedIndex;
    [self refreshButtonStyles];
    [self layoutIndicatorAnimated:YES];
}

@end
