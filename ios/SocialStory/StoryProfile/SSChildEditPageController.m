//
//  SSChildEditPageController.m
//  StoryProfile
//
//  Three modes:
//   - Create (no child_id arg): editable form, button "保存" → POST /v1/children.
//   - View   (child_id arg):    read-only form, button "修改信息" → enters edit.
//   - Edit:                     editable; once any field changes the button
//                               becomes "更新信息" → PUT /v1/children/{id}, then
//                               refresh from the server.
//  Form style mirrors the generation page.
//

#import "SSChildEditPageController.h"
#import <FusionUI/FusionPageNavigator+Auto.h>
#import <FusionUI/FusionNaviAnimeHelper.h>
#import <SocialStoryCore/SocialStoryCore-Swift.h>

typedef NS_ENUM(NSInteger, SSChildEditMode) {
    SSChildEditModeCreate = 0,
    SSChildEditModeView,
    SSChildEditModeEdit,
};

@interface SSChildEditPageController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UISegmentedControl *genderControl;
@property (nonatomic, strong) UIDatePicker *birthdayPicker;
@property (nonatomic, strong) UISegmentedControl *diagnosisControl;
@property (nonatomic, strong) UISegmentedControl *levelControl;
@property (nonatomic, strong) UITextField *interestField;
@property (nonatomic, strong) UIButton *saveButton;

@property (nonatomic, assign) SSChildEditMode mode;
@property (nonatomic, assign) BOOL dirty;
@property (nonatomic, copy) NSString *childID;       // set in view/edit mode
@property (nonatomic, strong) SSChild *editingChild; // source data in view/edit
@end

@implementation SSChildEditPageController

- (NSString *)pageTitle { return self.childID.length ? @"孩子信息" : @"添加孩子"; }
- (BOOL)showsBackButton { return YES; }

// The list page pushes with @{SSArgChildID: id} to view an existing child.
- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args {
    NSString *cid = args[SSArgChildID];
    if (cid.length) {
        self.childID = cid;
        self.mode = SSChildEditModeView;
        self.editingChild = [self childFromStore:cid];
        if ([self contentBuilt]) {
            [self populateFromChild];
            [self applyMode];
        }
    }
}

- (SSChild *)childFromStore:(NSString *)cid {
    for (SSChild *c in [SSChildStore shared].children) {
        if ([c.childID isEqualToString:cid]) { return c; }
    }
    return nil;
}

- (void)buildPageContent {
    CGFloat top = [self naviBarBottom];
    CGFloat bottom = [self contentBottomInset];
    self.scrollView = [[UIScrollView alloc] initWithFrame:
        CGRectMake(0, top, self.view.bounds.size.width, self.view.bounds.size.height - top - bottom)];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:self.scrollView];

    CGFloat margin = 16;
    CGFloat width = self.view.bounds.size.width - margin * 2;
    CGFloat y = 16;

    y = [self addSectionLabel:@"孩子名字" atY:y margin:margin];
    self.nameField = [self addTextFieldAtY:y margin:margin width:width placeholder:@"小朋友"];
    [self.nameField addTarget:self action:@selector(markDirty) forControlEvents:UIControlEventEditingChanged];
    y += 44 + 16;

    y = [self addSectionLabel:@"性别" atY:y margin:margin];
    self.genderControl = [self addSegmentAtY:y margin:margin width:width items:@[@"男孩", @"女孩"]];
    [self.genderControl addTarget:self action:@selector(markDirty) forControlEvents:UIControlEventValueChanged];
    y += 36 + 16;

    y = [self addSectionLabel:@"生日" atY:y margin:margin];
    self.birthdayPicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(margin, y, width, 40)];
    self.birthdayPicker.datePickerMode = UIDatePickerModeDate;
    self.birthdayPicker.maximumDate = [NSDate date];
    if (@available(iOS 13.4, *)) { self.birthdayPicker.preferredDatePickerStyle = UIDatePickerStyleCompact; }
    self.birthdayPicker.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.birthdayPicker addTarget:self action:@selector(markDirty) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:self.birthdayPicker];
    y += 44 + 16;

    y = [self addSectionLabel:@"诊断类型" atY:y margin:margin];
    self.diagnosisControl = [self addSegmentAtY:y margin:margin width:width
                                          items:@[@"自闭症", @"多动症", @"社交焦虑", @"其他"]];
    self.diagnosisControl.apportionsSegmentWidthsByContent = YES;
    [self.diagnosisControl addTarget:self action:@selector(markDirty) forControlEvents:UIControlEventValueChanged];
    y += 36 + 16;

    y = [self addSectionLabel:@"语言水平" atY:y margin:margin];
    self.levelControl = [self addSegmentAtY:y margin:margin width:width items:@[@"简单句", @"复合句", @"复杂句"]];
    [self.levelControl addTarget:self action:@selector(markDirty) forControlEvents:UIControlEventValueChanged];
    y += 36 + 16;

    y = [self addSectionLabel:@"兴趣点（选填，逗号分隔）" atY:y margin:margin];
    self.interestField = [self addTextFieldAtY:y margin:margin width:width placeholder:@"如：恐龙，火车，太空"];
    [self.interestField addTarget:self action:@selector(markDirty) forControlEvents:UIControlEventEditingChanged];
    y += 44 + 28;

    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.saveButton.frame = CGRectMake(margin, y, width, 50);
    self.saveButton.backgroundColor = [SSTheme accentColor];
    [self.saveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.saveButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.saveButton.layer.cornerRadius = 12;
    self.saveButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.saveButton addTarget:self action:@selector(onPrimaryButton) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.saveButton];
    y += 50 + 24;

    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, y);

    if (self.editingChild) { [self populateFromChild]; }
    [self applyMode];
}

#pragma mark - Mode

- (void)applyMode {
    BOOL editable = (self.mode != SSChildEditModeView);
    self.nameField.enabled = editable;
    self.genderControl.enabled = editable;
    self.birthdayPicker.enabled = editable;
    self.diagnosisControl.enabled = editable;
    self.levelControl.enabled = editable;
    self.interestField.enabled = editable;
    self.nameField.alpha = editable ? 1.0 : 0.6;
    self.interestField.alpha = editable ? 1.0 : 0.6;

    NSString *title;
    switch (self.mode) {
        case SSChildEditModeCreate: title = @"保存"; break;
        case SSChildEditModeView:   title = @"修改信息"; break;
        case SSChildEditModeEdit:   title = self.dirty ? @"更新信息" : @"修改信息"; break;
    }
    [self.saveButton setTitle:title forState:UIControlStateNormal];
    [self setupNaviBar]; // refresh title (孩子信息 vs 添加孩子)
}

- (void)markDirty {
    if (self.mode == SSChildEditModeEdit && !self.dirty) {
        self.dirty = YES;
        [self.saveButton setTitle:@"更新信息" forState:UIControlStateNormal];
    }
}

- (void)populateFromChild {
    SSChild *c = self.editingChild;
    if (!c) { return; }
    self.nameField.text = c.name;
    self.genderControl.selectedSegmentIndex = (c.gender == SSGenderGirl) ? 1 : 0;
    self.diagnosisControl.selectedSegmentIndex = c.diagnosisType;
    self.levelControl.selectedSegmentIndex = c.level;
    self.interestField.text = [c.interests componentsJoinedByString:@"，"];
    NSDate *bday = [self dateFromYYYYMMDD:c.birthday];
    if (bday) { self.birthdayPicker.date = bday; }
}

#pragma mark - Primary button

- (void)onPrimaryButton {
    switch (self.mode) {
        case SSChildEditModeCreate: [self submitCreate]; break;
        case SSChildEditModeView:
            // Enter edit mode (fields become editable).
            self.mode = SSChildEditModeEdit;
            self.dirty = NO;
            [self applyMode];
            break;
        case SSChildEditModeEdit:
            if (self.dirty) { [self submitUpdate]; }
            // Not dirty: nothing to update; stay in edit mode.
            break;
    }
}

- (SSChild *)childFromForm {
    SSChild *child = [SSChild new];
    child.name = [self.nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    child.gender = (self.genderControl.selectedSegmentIndex == 0) ? SSGenderBoy : SSGenderGirl;
    child.birthday = [self yyyymmddFromDate:self.birthdayPicker.date];
    child.diagnosisType = (SSDiagnosisType)self.diagnosisControl.selectedSegmentIndex;
    child.level = (SSLanguageLevel)self.levelControl.selectedSegmentIndex;
    child.interests = [self parseInterests:self.interestField.text];
    return child;
}

- (BOOL)validateForm {
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (name.length == 0) {
        [self showAlert:@"请完善信息" message:@"请填写孩子名字"];
        return NO;
    }
    if (name.length > 24) {
        [self showAlert:@"名字过长" message:@"孩子名字请控制在 24 字以内"];
        return NO;
    }
    NSInteger age = [self ageFromDate:self.birthdayPicker.date];
    if (age < 2 || age > 16) {
        [self showAlert:@"生日不合适" message:@"孩子年龄需在 2-16 岁之间，请重新选择生日"];
        return NO;
    }
    // Interests are optional, but match the backend cap (≤10 items, ≤16 chars each).
    for (NSString *tag in [self parseInterests:self.interestField.text]) {
        if (tag.length > 16) {
            [self showAlert:@"兴趣点过长" message:@"每个兴趣点请控制在 16 字以内"];
            return NO;
        }
    }
    return YES;
}

- (void)submitCreate {
    if (![self validateForm]) { return; }
    [self.view endEditing:YES];
    self.saveButton.enabled = NO;
    [self.saveButton setTitle:@"保存中…" forState:UIControlStateNormal];
    __weak typeof(self) weakSelf = self;
    [[SSChildrenClient shared] createChild:[self childFromForm] completion:^(SSChild *created, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.saveButton.enabled = YES;
        [self.saveButton setTitle:@"保存" forState:UIControlStateNormal];
        if (error || !created) {
            [self showAlert:@"保存失败" message:error.localizedDescription ?: @"请检查网络后重试"];
            return;
        }
        // Refresh the shared store, then confirm success and return to the list.
        // (The list page reloads itself on enterAnimeFinish.)
        [[SSChildStore shared] reloadWithCompletion:nil];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存成功"
            message:[NSString stringWithFormat:@"已添加「%@」", created.name]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) { [self goBack]; }]];
        [self presentViewController:alert animated:YES completion:nil];
    }];
}

- (void)submitUpdate {
    if (![self validateForm]) { return; }
    [self.view endEditing:YES];
    self.saveButton.enabled = NO;
    [self.saveButton setTitle:@"更新中…" forState:UIControlStateNormal];
    __weak typeof(self) weakSelf = self;
    [[SSChildrenClient shared] updateChildID:self.childID child:[self childFromForm]
                                  completion:^(SSChild *updated, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.saveButton.enabled = YES;
        if (error || !updated) {
            [self applyMode]; // restore the button title
            [self showAlert:@"更新失败" message:error.localizedDescription ?: @"请检查网络后重试"];
            return;
        }
        // Re-fetch the canonical list, then reflect the refreshed child here and
        // drop back to read-only view mode.
        [[SSChildStore shared] reloadWithCompletion:^(NSError *e) {
            self.editingChild = [self childFromStore:self.childID] ?: updated;
            [self populateFromChild];
            self.mode = SSChildEditModeView;
            self.dirty = NO;
            [self applyMode];
        }];
        [self showAlert:@"更新成功" message:@"孩子信息已更新"];
    }];
}

#pragma mark - Form helpers (mirror the generation page styling)

- (UITextField *)addTextFieldAtY:(CGFloat)y margin:(CGFloat)margin width:(CGFloat)width placeholder:(NSString *)placeholder {
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(margin, y, width, 44)];
    tf.borderStyle = UITextBorderStyleRoundedRect;
    tf.placeholder = placeholder;
    tf.font = [UIFont systemFontOfSize:16];
    tf.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:tf];
    return tf;
}

- (UISegmentedControl *)addSegmentAtY:(CGFloat)y margin:(CGFloat)margin width:(CGFloat)width items:(NSArray *)items {
    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:items];
    seg.frame = CGRectMake(margin, y, width, 36);
    seg.selectedSegmentIndex = 0;
    seg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:seg];
    return seg;
}

- (CGFloat)addSectionLabel:(NSString *)text atY:(CGFloat)y margin:(CGFloat)margin {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, self.view.bounds.size.width - margin * 2, 22)];
    label.text = text;
    label.font = [UIFont boldSystemFontOfSize:15];
    label.textColor = [SSTheme secondaryTextColor];
    [self.scrollView addSubview:label];
    return y + 22 + 6;
}

#pragma mark - Interests / dates

- (NSArray<NSString *> *)parseInterests:(NSString *)text {
    if (text.length == 0) { return @[]; }
    NSString *normalized = [text stringByReplacingOccurrencesOfString:@"，" withString:@","];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *raw in [normalized componentsSeparatedByString:@","]) {
        NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (s.length > 0 && out.count < 10) { [out addObject:s]; }
    }
    return out;
}

- (NSString *)yyyymmddFromDate:(NSDate *)date {
    NSDateFormatter *f = [NSDateFormatter new];
    f.dateFormat = @"yyyy-MM-dd";
    return [f stringFromDate:date];
}

- (NSDate *)dateFromYYYYMMDD:(NSString *)s {
    if (s.length == 0) { return nil; }
    NSDateFormatter *f = [NSDateFormatter new];
    f.dateFormat = @"yyyy-MM-dd";
    return [f dateFromString:s];
}

- (NSInteger)ageFromDate:(NSDate *)date {
    NSDateComponents *c = [[NSCalendar currentCalendar] components:NSCalendarUnitYear
                                                         fromDate:date toDate:[NSDate date] options:0];
    return c.year;
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
