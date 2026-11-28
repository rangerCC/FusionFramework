Pod::Spec.new do |s|
  s.name             = 'StoryLibrary'
  s.version          = '1.0.0'
  s.summary          = 'Story library/management feature'
  s.description      = 'Lists saved stories with pull-to-refresh and swipe-to-delete, driven by NSFetchedResultsController.'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.requires_arc = true

  s.source_files = 'SocialStory/StoryLibrary/**/*.{h,m}'
  s.public_header_files = 'SocialStory/StoryLibrary/**/*.h'

  s.frameworks = 'Foundation', 'UIKit', 'CoreData'
  s.dependency 'SocialStoryCore'
  s.dependency 'FusionUI'
  s.dependency 'SDWebImage', '~> 5.0'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader'
  }
end
