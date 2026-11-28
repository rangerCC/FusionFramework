//
//  TestTabBar.m
//  社交故事生成器
//

#import "TestTabBar.h"
#import <SocialStoryCore/SocialStoryCore.h>
#import <FusionUI/FusionPageNavigator+Auto.h>
#import <FusionUI/FusionNaviAnimeHelper.h>
#import "SafeARC.h"

@interface TestTabBar() {
@private
    NSMutableArray  *_buttonArray;
    NSArray         *_pageNames;
    NSUInteger      _currentIndex;
}
@end

@implementation TestTabBar

- (id)initWithConfig:(NSDictionary *)config {
    self = [super initWithConfig:config];
    if (self) {
        [self setBackgroundColor:[SSTheme cardColor]];
        _currentIndex = 0;
        _pageNames = @[SSPageLibrary, SSPageGenerate, SSPageProfile];
        NSArray *titles = @[
            @{@"title": @"我的故事", @"icon_normal":@"icon_story_normal", @"icon_selected":@"icon_story_selected"},
            @{@"title": @"创建", @"icon_normal":@"icon_createstory_normal", @"icon_selected":@"icon_createstory_selected"},
            @{@"title": @"我的", @"icon_normal":@"icon_home_normal", @"icon_selected":@"icon_home_selected"},
        ];

        _buttonArray = [NSMutableArray new];
        for (NSUInteger i = 0; i < titles.count; i++) {
            NSDictionary *titleInfo = titles[i];
            UIButton *button = [self createTopImageBottomTitleSelectButton:CGRectMake(0, 0, 50, 50)
                                                            normalImage:[UIImage imageNamed:titleInfo[@"icon_normal"]]
                                                           selectedImage:[UIImage imageNamed:titleInfo[@"icon_selected"]]
                                                                  title:titleInfo[@"title"]
                                                                  space:4];
            [button addTarget:self action:@selector(onTapTab:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:button];
            [_buttonArray addObject:button];
        }
        [(UIButton *)_buttonArray[0] setSelected:YES];

        // top hairline
        UIView *line = [[UIView alloc] initWithFrame:CGRectZero];
        line.backgroundColor = [SSTheme secondaryTextColor];
        line.alpha = 0.2;
        line.tag = 9999;
        [self addSubview:line];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (_buttonArray.count == 0) return;
    CGFloat w = self.frame.size.width / _buttonArray.count;
    for (NSUInteger i = 0; i < _buttonArray.count; i++) {
        [(UIButton *)_buttonArray[i] setFrame:CGRectMake(i * w, 0, w, self.frame.size.height)];
    }
    [[self viewWithTag:9999] setFrame:CGRectMake(0, 0, self.frame.size.width, 0.5)];
}

- (void)onTapTab:(UIButton *)sender {
    NSUInteger index = [_buttonArray indexOfObject:sender];
    if (index == NSNotFound) return;

    for (UIButton *b in _buttonArray) { [b setSelected:NO]; }
    [sender setSelected:YES];

    FusionPageMessage *message = [[FusionPageMessage alloc] initWithPageName:_pageNames[index]
                                                                    pageNick:nil
                                                                     command:nil
                                                                        args:nil
                                                                    callback:nil];
    if (_currentIndex > index) {
        [message setNaviAnimeType:ScrollL2R_NaviAnime];
    } else if (_currentIndex < index) {
        [message setNaviAnimeType:ScrollR2L_NaviAnime];
    }
    _currentIndex = index;
    [[self navigator] gotoPage:message];
}

- (void)dealloc {
    SafeSuperDealloc(super);
}

- (UIButton *)createTopImageBottomTitleSelectButton:(CGRect)frame
                                        normalImage:(UIImage *)normalImage
                                       selectedImage:(UIImage *)selectedImage
                                              title:(NSString *)title
                                              space:(CGFloat)space {

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = frame;

    // 图片
    [button setImage:normalImage forState:UIControlStateNormal];
    [button setImage:selectedImage forState:UIControlStateSelected];

    // 文字
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14];
    [button setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blueColor] forState:UIControlStateSelected]; // 选中颜色

    // 上图下文布局
    [self layoutButtonTopImageBottomTitle:button space:space];

    return button;
}

// 上图下文核心布局（通用）
- (void)layoutButtonTopImageBottomTitle:(UIButton *)button space:(CGFloat)space {
    CGFloat imageWidth = button.imageView.intrinsicContentSize.width;
    CGFloat imageHeight = button.imageView.intrinsicContentSize.height;
    CGFloat labelWidth = button.titleLabel.intrinsicContentSize.width;
    CGFloat labelHeight = button.titleLabel.intrinsicContentSize.height;

    CGFloat totalHeight = imageHeight + labelHeight + space;

    button.imageEdgeInsets = UIEdgeInsetsMake(
        -(totalHeight - imageHeight)/2,
        (labelWidth + imageWidth)/2,
        (totalHeight - imageHeight)/2 + space,
        (labelWidth - imageWidth)/2
    );

    button.titleEdgeInsets = UIEdgeInsetsMake(
        (totalHeight - labelHeight)/2 + space,
        -labelWidth,
        -(totalHeight - labelHeight)/2,
        0
    );
}
@end
