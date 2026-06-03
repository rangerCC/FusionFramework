//
//  SSHelpPageController.m
//  StorySettings
//

#import "SSHelpPageController.h"

@implementation SSHelpPageController

- (NSString *)pageTitle { return @"帮助"; }
- (BOOL)showsBackButton { return YES; }

- (void)buildPageContent {
    CGFloat top = [self naviBarBottom];
    UITextView *textView = [[UITextView alloc] initWithFrame:
        CGRectMake(0, top, self.view.bounds.size.width, self.view.bounds.size.height - top)];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    textView.editable = NO;
    textView.backgroundColor = [SSTheme backgroundColor];
    textView.textColor = [SSTheme primaryTextColor];
    textView.font = [UIFont systemFontOfSize:16];
    textView.textContainerInset = UIEdgeInsetsMake(16, 16, 16, 16);
    textView.text =
        @"什么是社交故事？\n\n"
        @"社交故事（Social Stories）是一种用简单、具体的叙事，帮助儿童（尤其是有自闭症谱系或社交沟通困难的孩子）理解某个社交场景的方法。它用第一人称、正面的语气，描述「会发生什么」「我可以怎么做」「这样做的感受」，降低孩子面对陌生场景时的焦虑。\n\n"
        @"如何使用本 App\n\n"
        @"1. 在「生成」页填写场景描述（也可从模板一键选择）、孩子的名字、年龄和语言水平。\n\n"
        @"2. 点击「生成故事」，稍候即可得到一篇社交故事。\n\n"
        @"3. 在「我的故事」中查看、管理所有生成的故事，左滑可删除。\n\n"
        @"4. 点开任意故事进入阅读器，可以朗读全文、调节语速和字号。\n\n"
        @"5. 免费用户每月可生成 3 个故事；订阅会员可无限生成。\n\n"
        @"温馨提示\n\n"
        @"生成的故事仅供参考，请结合孩子的实际情况调整内容，并在大人陪伴下一起阅读，效果更好。";
    textView.accessibilityLabel = @"帮助说明";
    [self.view addSubview:textView];
}

@end
