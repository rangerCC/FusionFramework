Pod::Spec.new do |s|
  s.name             = 'PhotoClean'
  s.version          = '1.0.0'
  s.summary          = 'On-device photo cleaning services for PhotoCleaner'
  s.description      = 'PhotoKit sync, similarity scanning (dHash + Vision FeaturePrint), clustering and deletion actors built on FusionCore'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'PhotoCleaner' => '' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.requires_arc = true

  s.source_files = 'PhotoClean/PhotoClean/**/*.{h,m}'
  s.public_header_files = 'PhotoClean/PhotoClean/**/*.h'

  s.frameworks = 'Foundation', 'UIKit', 'Photos', 'Vision', 'Accelerate'

  s.dependency 'FusionBase'
  s.dependency 'FusionCore'
  s.dependency 'Utility'
  s.dependency 'Enviroment'
  s.dependency 'FMDB', '~> 2.7'
  s.dependency 'CocoaLumberjack', '~> 3.9'

  # Workspace/ holds the Lua-generated TRIPServiceMacro.h / TRIPPageMacro.h
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader ' \
                             '$(PODS_TARGET_SRCROOT)/Workspace'
  }
end
