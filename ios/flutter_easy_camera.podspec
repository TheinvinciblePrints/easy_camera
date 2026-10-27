Pod::Spec.new do |s|
  s.name             = 'flutter_easy_camera'
  s.version          = '1.0.0'
  s.summary          = 'Native AVFoundation camera for flutter_easy_camera.'
  s.description      = <<-DESC
Native AVFoundation camera with AI-ready, resized and compressed captures.
                       DESC
  s.homepage         = 'https://github.com/TheinvinciblePrints/easy_camera'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Emmany' => 'emmanydeveloper@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_easy_camera/Sources/flutter_easy_camera/**/*.swift'
  s.resource_bundles = { 'flutter_easy_camera_privacy' => ['flutter_easy_camera/Sources/flutter_easy_camera/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.frameworks = 'AVFoundation', 'ImageIO', 'CoreImage'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
