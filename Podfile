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

  # AFNetworking 4.0.1 redundantly imports the private system header
  # <netinet6/in6.h>, which Xcode 26.4+ rejects under use_frameworks! with
  # "Use of private header from outside its module". <netinet/in.h> already
  # provides what's needed, so strip the offending imports.
  ['AFNetworkReachabilityManager.m', 'AFHTTPSessionManager.m'].each do |file|
    path = File.join(installer.sandbox.root, 'AFNetworking', 'AFNetworking', file)
    next unless File.exist?(path)
    text = File.read(path)
    patched = text.gsub(/^\s*#import\s+<netinet6\/in6\.h>\s*\n/, '')
    if patched != text
      File.chmod(0644, path)
      File.write(path, patched)
    end
  end
end
