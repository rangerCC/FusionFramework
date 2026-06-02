Pod::Spec.new do |s|
  s.name             = 'FusionUI'
  s.version          = '1.0.0'
  s.summary          = 'UI module for FusionFramework'
  s.description      = 'Provides page navigation, view controller management, and transition animations'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.requires_arc = true

  s.source_files = 'FusionUI/FusionUI/**/*.{h,m}'
  s.public_header_files = 'FusionUI/FusionUI/**/*.h'

  s.frameworks = 'Foundation', 'UIKit', 'QuartzCore'
  s.dependency 'FusionBase'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader'
  }
end
