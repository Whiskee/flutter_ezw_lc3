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
  s.source_files = 'Classes/**/*.{h,m,swift,c}'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  # 添加liblc3相关库内容
  # - 实现静态库
  s.static_framework = true
  # - 添加liblc3.a库，支持不同架构
  s.vendored_libraries = 'Classes/framework/liblc3.a'
  
  # 配置架构特定的库路径（如果需要分离的架构文件）
  # s.ios.vendored_libraries = 'Classes/framework/arm64/liblc3.a'
  # s.ios.sim.vendored_libraries = 'Classes/framework/x86_64/liblc3.a'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-force_load $(PODS_TARGET_SRCROOT)/Classes/framework/liblc3.a',
    'GCC_SYMBOLS_PRIVATE_EXTERN' => 'NO',
    'DEAD_CODE_STRIPPING' => 'NO',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Classes"',
  }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_ezw_lc3_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
