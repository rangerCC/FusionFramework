Pod::Spec.new do |s|
  s.name             = 'FusionBase'
  s.version          = '1.0.0'
  s.summary          = 'Base module for FusionFramework'
  s.description      = 'Provides base message handling and utility extensions for FusionFramework'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.requires_arc = true

  s.source_files = 'FusionBase/FusionBase/**/*.{h,m}'
  s.public_header_files = 'FusionBase/FusionBase/**/*.h'

  s.frameworks = 'Foundation', 'UIKit'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader'
  }
end
