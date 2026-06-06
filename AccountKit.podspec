Pod::Spec.new do |s|
  s.name             = 'AccountKit'
  s.version          = '1.0.0'
  s.summary          = 'User account & authentication core for the Social Story app'
  s.description      = 'Account state, session persistence (Keychain), and a swappable login service protocol (SMS code login). Pure logic, no UI; backend-agnostic via SSAccountService.'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.requires_arc = true
  s.swift_version = '5.0'

  s.source_files = 'AccountKit/AccountKit/**/*.{h,m,swift}'
  s.public_header_files = 'AccountKit/AccountKit/**/*.h'

  s.frameworks = 'Foundation', 'Security'

  s.dependency 'FusionBase'
end
