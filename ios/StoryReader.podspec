Pod::Spec.new do |s|
  s.name             = 'StoryReader'
  s.version          = '1.0.0'
  s.summary          = 'Story reader with text-to-speech'
  s.description      = 'Reads a story with AVSpeechSynthesizer, adjustable rate and font size.'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.requires_arc = true

  s.source_files = 'SocialStory/StoryReader/**/*.{h,m}'
  s.public_header_files = 'SocialStory/StoryReader/**/*.h'

  s.frameworks = 'Foundation', 'UIKit', 'AVFoundation'
  s.dependency 'SocialStoryCore'
  s.dependency 'FusionUI'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader'
  }
end
