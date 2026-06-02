Pod::Spec.new do |s|
  s.name             = 'Enviroment'
  s.version          = '1.0.0'
  s.summary          = 'Environment module for FusionFramework'
  s.description      = 'Provides environment configuration and user defaults management'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.requires_arc = true

  s.source_files = 'Enviroment/Enviroment/**/*.{h,m}'
  s.public_header_files = 'Enviroment/Enviroment/**/*.h'

  s.frameworks = 'Foundation', 'UIKit'
  s.dependency 'FusionBase'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader'
  }
end
