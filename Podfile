platform :ios, '15.0'
use_frameworks!

workspace 'Workspace/FusionWorkspace'

target 'TestApp' do
  project 'TestApp/TestApp.xcodeproj'

  # Framework modules
  pod 'FusionBase', :path => '.'
  pod 'Utility', :path => '.'
  pod 'FusionCore', :path => '.'
  pod 'FusionUI', :path => '.'
  pod 'CoreService', :path => '.'
  pod 'Enviroment', :path => '.'

  # Social Story Generator: shared core + feature pods
  pod 'AccountKit', :path => '.'
  pod 'SocialStoryCore', :path => '.'
  pod 'StoryGeneration', :path => '.'
  pod 'StoryLibrary', :path => '.'
  pod 'StoryReader', :path => '.'
  pod 'StorySubscription', :path => '.'
  pod 'StoryTemplates', :path => '.'
  pod 'StorySettings', :path => '.'
  pod 'StoryProfile', :path => '.'

  pod 'SDWebImage', '~> 5.0'
  pod 'LookinServer', :configurations => ['Debug']

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['SWIFT_VERSION'] = '5.0'
    end
  end
end
