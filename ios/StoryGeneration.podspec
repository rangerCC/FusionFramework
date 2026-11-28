Pod::Spec.new do |s|
  s.name             = 'StoryGeneration'
  s.version          = '1.0.0'
  s.summary          = 'Story generation feature for the Social Story Generator'
  s.description      = 'Form to generate a social story from a scene description, with subscription gating.'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.requires_arc = true

  s.source_files = 'SocialStory/StoryGeneration/**/*.{h,m}'
  s.public_header_files = 'SocialStory/StoryGeneration/**/*.h'

  s.frameworks = 'Foundation', 'UIKit'
  s.dependency 'SocialStoryCore'
  s.dependency 'FusionUI'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader'
  }
end
