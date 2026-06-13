Pod::Spec.new do |s|
  s.name             = 'WebViewKit'
  s.version          = '1.0.0'
  s.summary          = 'WKWebView pool & markdown rendering for SystemThinker'
  s.description      = 'Provides a reusable WKWebView pool (shared process pool, prewarm/recycle) and a local markdown-it + CSS bundle for rendering chat bubbles.'
  s.homepage         = 'https://github.com/alitrip/FusionFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ryou Zhang' => 'zhangryou@gmail.com' }
  s.source           = { :git => 'https://github.com/alitrip/FusionFramework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.requires_arc = true

  s.source_files = 'WebViewKit/WebViewKit/**/*.{h,m}'
  s.public_header_files = 'WebViewKit/WebViewKit/**/*.h'
  s.resource_bundles = {
    'WebViewKitResource' => ['WebViewKit/WebViewKit/Resource.bundle/**/*']
  }

  s.frameworks = 'Foundation', 'UIKit', 'WebKit'
end
