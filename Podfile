platform :ios, '15.0'
use_frameworks!

workspace 'Workspace/FusionWorkspace'

target 'TestApp' do
  project 'TestApp/TestApp.xcodeproj'

  # Local pods - FusionFramework modules
  pod 'FusionBase', :path => '.'
  pod 'Utility', :path => '.'
  pod 'FusionCore', :path => '.'
  pod 'FusionUI', :path => '.'
  pod 'CoreService', :path => '.'
  pod 'Enviroment', :path => '.'
  
  pod 'SDWebImage', '~> 5.21'
  pod 'AFNetworking', '~> 4.0'
  pod 'FMDB', '~> 2.7'
  pod 'CocoaLumberjack', '~> 3.9'
  pod 'MJRefresh', '~> 3.7'
  pod 'Masonry', '~> 1.1'
  pod 'IQKeyboardManager'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['SWIFT_VERSION'] = '5.0'
    end
  end
end
