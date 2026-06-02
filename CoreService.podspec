Pod::Spec.new do |s|
  s.name             = 'CoreService'
  s.version          = '1.0.0'
  s.summary          = 'Core services module for FusionFramework'
  s.description      = 'Provides network engine, download manager, and caching services'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'

  s.frameworks = 'Foundation', 'UIKit', 'CFNetwork', 'Security'
  s.libraries = 'z', 'sqlite3'
  # libcurl is built against OpenSSL, so libcrypto/libssl (shipped in the
  # Utility pod) must be linked alongside it to resolve DES_*, MD4_*, etc.
  s.vendored_libraries = 'CoreService/CoreService/Network/libcurl/libcurl.a',
                         'CoreService/CoreService/Network/libcurl/libcares.a',
                         'CoreService/CoreService/Network/libcurl/libnghttp2.a',
                         'Utility/Utility/OpenSSL/libcrypto.a',
                         'Utility/Utility/OpenSSL/libssl.a'

  s.dependency 'FusionCore'
  s.dependency 'FusionBase'
  s.dependency 'Utility'

  shared_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/CoreService/CoreService/Network/libcurl/curl ' \
                             '$(PODS_TARGET_SRCROOT)/CoreService/CoreService/Network/libcurl ' \
                             '$(PODS_TARGET_SRCROOT)/CoreService/CoreService/Network/libares ' \
                             '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader',
    # curl.h / ares.h are non-modular C headers pulled into ObjC public headers.
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }

  # Main sources (ARC). Excludes the prebuilt C libs and the legacy MRC file.
  s.subspec 'Core' do |c|
    c.requires_arc = true
    c.source_files = 'CoreService/CoreService/**/*.{h,m}'
    c.exclude_files = 'CoreService/CoreService/Network/libcurl/**/*',
                      'CoreService/CoreService/Network/libares/**/*',
                      'CoreService/CoreService/Network/NeoNetEngine/NeoReachability.m'
    c.pod_target_xcconfig = shared_xcconfig
    c.dependency 'CoreService/Reachability'
  end

  # NeoReachability is legacy manual-retain/release code; compile without ARC.
  s.subspec 'Reachability' do |r|
    r.requires_arc = false
    r.source_files = 'CoreService/CoreService/Network/NeoNetEngine/NeoReachability.{h,m}'
    r.pod_target_xcconfig = shared_xcconfig
  end
end
