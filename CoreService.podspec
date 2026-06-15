Pod::Spec.new do |s|
  s.name             = 'CoreService'
  s.version          = '1.0.0'
  s.summary          = 'Core services module for FusionFramework'
  s.description      = 'Provides network engine, download manager, and caching services'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'

  s.frameworks = 'Foundation', 'UIKit'

  shared_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader'
  }

  # Main sources (ARC). Excludes the prebuilt C libs and the legacy MRC file.
  s.subspec 'Core' do |c|
    c.requires_arc = true
    c.source_files = 'CoreService/CoreService/**/*.{h,m}'
    c.pod_target_xcconfig = shared_xcconfig
  end
  
end
