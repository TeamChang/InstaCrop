platform :ios, '15.0'

target 'InstaCrop' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for InstaCrop
  pod 'SVProgressHUD'
  pod 'NewYorkAlert'
  pod 'Google-Mobile-Ads-SDK'

end

# Some pods ship with iOS 12 as their minimum, which current Xcode no longer supports
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
