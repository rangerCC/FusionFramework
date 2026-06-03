Pod::Spec.new do |s|
  s.name             = 'StorySettings'
  s.version          = '1.0.0'
  s.summary          = 'Settings and help feature'
  s.description      = 'Settings page (subscription status, free quota, speech rate, clear data, restore) and a help page.'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.requires_arc = true

  s.source_files = 'SocialStory/StorySettings/**/*.{h,m}'
  s.public_header_files = 'SocialStory/StorySettings/**/*.h'

  s.frameworks = 'Foundation', 'UIKit'
  s.dependency 'SocialStoryCore'
  s.dependency 'FusionUI'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader'
  }
end
