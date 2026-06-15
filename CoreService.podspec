Pod::Spec.new do |s|
  s.name             = 'CoreService'
  s.version          = '1.0.0'
  s.summary          = 'Core services module for FusionFramework'
  s.description      = 'Provides network actors, download manager, and caching services'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.requires_arc = true

  s.source_files = 'CoreService/CoreService/**/*.{h,m}'
  s.public_header_files = 'CoreService/CoreService/**/*.h'

  s.frameworks = 'Foundation', 'UIKit'

  s.dependency 'FusionCore'
  s.dependency 'FusionBase'
  s.dependency 'Utility'
  s.dependency 'AFNetworking', '~> 4.0'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader'
  }
end
