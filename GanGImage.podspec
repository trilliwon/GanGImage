#
# Be sure to run `pod lib lint GanGImage.podspec` to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name                  = 'GanGImage'
  s.version               = '1.0.0'
  s.summary               = 'Decode Animated Images such as WebP, APNG, GIF all source from YYImage'
  s.homepage              = 'https://github.com/trilliwon/GanGImage'
  s.license               = { :type => "Copyright", :text => "Copyright (c) Won. All rights reserved." }
  s.author                = { "won" => "trilliwon@gmail.com" }
  s.platform              = :ios, 12.0
  s.ios.deployment_target = '12.0'
  s.swift_version         = '5.0'
  s.source                = { :git => 'https://github.com/trilliwon/GanGImage.git', :tag => s.version.to_s }
  s.source_files          = 'YYImage/Sources/*.{h, m}'
  s.public_header_files   = 'YYImage/Sources/*.{h}'
  s.frameworks            = 'UIKit', 'CoreFoundation', 'QuartzCore', 'ImageIO', 'Accelerate', 'MobileCoreServices'
  s.vendored_frameworks   = 'WebP.framework', 'WebPDemux.framework', ' WebPMux.framework'
end
