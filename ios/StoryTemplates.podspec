Pod::Spec.new do |s|
  s.name             = 'StoryTemplates'
  s.version          = '1.0.0'
  s.summary          = 'Built-in story templates'
  s.description      = 'A library of common social-story scene templates that fill the generation form.'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.requires_arc = true

  s.source_files = 'SocialStory/StoryTemplates/**/*.{h,m}'
  s.public_header_files = 'SocialStory/StoryTemplates/**/*.h'

  s.resource_bundles = {
    'StoryTemplatesResources' => ['SocialStory/StoryTemplates/Resources/*.plist']
  }

  s.frameworks = 'Foundation', 'UIKit'
  s.dependency 'SocialStoryCore'
  s.dependency 'FusionUI'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader'
  }
end
