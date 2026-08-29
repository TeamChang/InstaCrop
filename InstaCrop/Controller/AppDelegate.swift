//
//  AppDelegate.swift
//  InstaCrop
//
//  Created by Timchang Wuyep on 21/12/2023.
//

import UIKit
import GoogleMobileAds

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow? // for progress hud else it'll crash

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // Brand nav bar (Instagram-style pink/magenta from the app icon), configured via
        // UINavigationBarAppearance rather than `window?.rootViewController` here, since
        // `window` isn't populated yet at this point in the UIScene app lifecycle.
        //
        // Using UINavigationBarAppearance (rather than just the legacy backgroundColor/
        // tintColor storyboard properties) ensures the bar stays opaque in its
        // scrollEdgeAppearance state too — otherwise the bar renders transparent at the
        // top of scroll content and the status bar area shows the view's background
        // instead of the brand color.
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(named: "violet")
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        let barButtonAppearance = UIBarButtonItemAppearance(style: .plain)
        barButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
        navBarAppearance.backButtonAppearance = barButtonAppearance

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        // White back-chevron, bar-button-item icons/text, etc.
        UINavigationBar.appearance().tintColor = .white

        GADMobileAds.sharedInstance().start(completionHandler: nil)
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

