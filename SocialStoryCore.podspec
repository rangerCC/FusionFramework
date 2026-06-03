Pod::Spec.new do |s|
  s.name             = 'SocialStoryCore'
  s.version          = '1.0.0'
  s.summary          = 'Shared core for the Social Story Generator app'
  s.description      = 'Data model, Core Data store, story API client, theme, base page controller and the StoreKit 2 subscription manager.'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.requires_arc = true
  s.swift_version = '5.0'

  s.source_files = 'SocialStory/SocialStoryCore/**/*.{h,m,swift}'
  s.public_header_files = 'SocialStory/SocialStoryCore/**/*.h'

  s.resource_bundles = {
    'SocialStoryCoreResources' => ['SocialStory/SocialStoryCore/Model/SocialStory.xcdatamodeld']
  }

  s.frameworks = 'Foundation', 'UIKit', 'CoreData', 'StoreKit'

  s.dependency 'FusionBase'
  s.dependency 'FusionCore'
  s.dependency 'FusionUI'
  s.dependency 'CoreService'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader'
  }
end
