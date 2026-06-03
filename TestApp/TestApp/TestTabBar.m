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
        _pageNames = @[SSPageLibrary, SSPageGenerate, SSPageSettings];
        NSArray *titles = @[@"我的故事", @"生成", @"设置"];

        _buttonArray = [NSMutableArray new];
        for (NSUInteger i = 0; i < titles.count; i++) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            [button setTitle:titles[i] forState:UIControlStateNormal];
            [button setTitleColor:[SSTheme secondaryTextColor] forState:UIControlStateNormal];
            [button setTitleColor:[SSTheme accentColor] forState:UIControlStateSelected];
            button.titleLabel.font = [UIFont systemFontOfSize:13];
            button.accessibilityLabel = titles[i];
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

@end
