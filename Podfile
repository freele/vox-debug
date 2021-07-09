# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'Conference' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  pod 'CocoaLumberjack/Swift', '~> 3.5'

  pod 'VoxImplantSDK/CocoaLumberjackLogger', git: 'git@github.com:StreamLayer/voximplant-temporary.git'
  # pod 'VoxImplantSDK', :path => '/Users/kremenets/Dev/makeomatic/StreamLayer/Vox-test-builds/sdk'
  pod 'VoxImplantWebRTC', git: 'git@github.com:StreamLayer/voximplant-temporary.git'
  pod 'VoxImplantSDK', git: 'git@github.com:StreamLayer/voximplant-temporary.git'
  


  pod 'SocketRocket'
  pod 'PromiseKit'
  # pod 'YTVimeoExtractor'
  # pod 'XCDYouTubeKit'
  pod 'XCDYouTubeKit', git: 'git@github.com:iOSDev-Auction/XCDYouTubeKit.git'


end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end
