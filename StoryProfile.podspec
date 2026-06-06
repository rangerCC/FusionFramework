Pod::Spec.new do |s|
  s.name             = 'StoryProfile'
  s.version          = '1.0.0'
  s.summary          = 'Profile & account tab for the Social Story app'
  s.description      = 'The "我的" tab: avatar, login state, membership card and settings entry points. Includes the SMS-code login page. Talks to AccountKit and SubscriptionManager.'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.requires_arc = true

  s.source_files = 'SocialStory/StoryProfile/**/*.{h,m}'
  s.public_header_files = 'SocialStory/StoryProfile/**/*.h'

  s.frameworks = 'Foundation', 'UIKit'
  s.dependency 'SocialStoryCore'
  s.dependency 'AccountKit'
  s.dependency 'FusionUI'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader'
  }
end
