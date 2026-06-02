Pod::Spec.new do |s|
  s.name             = 'FusionCore'
  s.version          = '1.0.0'
  s.summary          = 'Core module for FusionFramework'
  s.description      = 'Provides Actor model implementation, message routing, and thread management'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.requires_arc = true

  s.source_files = 'FusionCore/FusionCore/**/*.{h,m}'
  s.public_header_files = 'FusionCore/FusionCore/**/*.h'

  s.frameworks = 'Foundation', 'UIKit'
  s.dependency 'FusionBase'
  s.dependency 'Utility'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader',
    # FusionLuaBridge.h exposes the Lua C API (lua_State*) via <Utility/Utility.h>.
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }
end
