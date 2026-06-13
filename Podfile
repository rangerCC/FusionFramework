platform :ios, '12.0'
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
  pod 'WebViewKit', :path => '.'

  pod 'AFNetworking', '~> 4.0'
  pod 'FMDB', '~> 2.7'
  pod 'LookinServer', :configurations => ['Debug']
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      config.build_settings['SWIFT_VERSION'] = '5.0'
    end
  end
end
