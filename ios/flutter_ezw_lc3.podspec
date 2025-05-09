#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_ezw_lc3.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_ezw_lc3'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://www.fzfstudio.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'FZFStudio' => 'whiskee.chen@fzfstudio.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*.{h,m,swift}'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  # 添加liblc3相关库内容
  # - 实现静态库
  s.static_framework = true
  # - 添加liblc3.a库
  s.vendored_libraries = 'Classes/framework/liblc3.dylib'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-force_load $(PODS_TARGET_SRCROOT)/Classes/framework/liblc3.dylib'
  }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_ezw_lc3_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
