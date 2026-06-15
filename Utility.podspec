Pod::Spec.new do |s|
  s.name             = 'Utility'
  s.version          = '1.0.0'
  s.summary          = 'Utility module for FusionFramework'
  s.description      = 'Provides crypto, file handling, JSON utilities, and Lua scripting support'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.requires_arc = true

  s.source_files = 'Utility/Utility/**/*.{h,m,c}'

  # Only the Objective-C API and the Lua C API are public. The embedded C
  # libraries (ZLib, MiniZip, OpenSSL) stay internal so consumers don't need
  # their private headers/search paths to import the Utility module.
  s.public_header_files = 'Utility/Utility/Utility.h',
                          'Utility/Utility/Crypto/*.h',
                          'Utility/Utility/UIColor/*.h',
                          'Utility/Utility/File/*.h',
                          'Utility/Utility/NSURL/*.h',
                          'Utility/Utility/JSON/*.h',
                          'Utility/Utility/Lua/*.h',
                          'Utility/Utility/Lua/lua-5.1.5/src/{lua,luaconf,lualib,lauxlib}.h'

  # Exclude the Lua interpreter front-end (has its own main()) and the
  # standalone luac compiler, plus the lua etc samples.
  s.exclude_files = 'Utility/Utility/Lua/lua-5.1.5/etc/**/*',
                    'Utility/Utility/Lua/lua-5.1.5/src/lua.c',
                    'Utility/Utility/Lua/lua-5.1.5/src/luac.c',
                    'Utility/Utility/Lua/lua-5.1.5/src/print.c'

  s.frameworks = 'Foundation', 'UIKit', 'Security'
  s.libraries = 'z', 'sqlite3'
  s.vendored_libraries = 'Utility/Utility/OpenSSL/libcrypto.a', 'Utility/Utility/OpenSSL/libssl.a'
  s.dependency 'FusionBase'
  s.dependency 'Enviroment'

  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' => 'LUA_USE_IOS',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/FusionBase/FusionBase/CommonHeader ' \
                             '$(PODS_TARGET_SRCROOT)/Utility/Utility/OpenSSL/include ' \
                             '$(PODS_TARGET_SRCROOT)/Utility/Utility/Lua/lua-5.1.5/src ' \
                             '$(PODS_TARGET_SRCROOT)/Utility/Utility/Zip/ZLib ' \
                             '$(PODS_TARGET_SRCROOT)/Utility/Utility/Zip/MiniZip',
    # Lua/ZLib/MiniZip are legitimately non-modular C headers.
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }
end
