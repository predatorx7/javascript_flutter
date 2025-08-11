#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'javascript_darwin'
  s.version          = '0.0.1'
  s.summary          = 'A iOS & macOS implementation of the javascript plugin.'
  s.description      = <<-DESC
  A iOS & macOS implementation of the javascript plugin.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Reclaim Protocol' => 'mushaheed@reclaimprotocol.org' }
  s.source           = { :path => '.' }
  s.source_files = 'javascript_darwin/Sources/javascript_darwin/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.14'
  s.ios.xcconfig = {
    'LIBRARY_SEARCH_PATHS' => '$(TOOLCHAIN_DIR)/usr/lib/swift/$(PLATFORM_NAME)/ $(SDKROOT)/usr/lib/swift',
    'LD_RUNPATH_SEARCH_PATHS' => '/usr/lib/swift',
  }
  s.frameworks = 'JavaScriptCore'
  s.swift_version = '5.0'
  s.resource_bundles = {'javascript_darwin_privacy' => ['javascript_darwin/Sources/javascript_darwin/Resources/PrivacyInfo.xcprivacy']}
end
