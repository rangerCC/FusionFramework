//
//  SSNavigation.h
//  SocialStoryCore
//
//  Shared page-name constants so feature pods can navigate without
//  importing one another.
//

#import <Foundation/Foundation.h>

#define SSPageLibrary        @"StoryLibraryPage"
#define SSPageGenerate       @"StoryGeneratePage"
#define SSPageReader         @"StoryReaderPage"
#define SSPageSubscription   @"StorySubscriptionPage"
#define SSPageTemplate       @"StoryTemplatePage"
#define SSPageSettings       @"StorySettingsPage"
#define SSPageHelp           @"StoryHelpPage"

#define SSTabBarName         @"SocialStoryTabBar"

// args / callback keys
#define SSArgStoryID         @"story_id"
#define SSArgSceneText       @"scene_text"
#define SSCommandFillScene   @"fill_scene"
