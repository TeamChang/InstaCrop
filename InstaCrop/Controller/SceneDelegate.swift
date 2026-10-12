//
//  SceneDelegate.swift
//  InstaCrop
//
//  Created by Timchang Wuyep on 21/12/2023.
//

import UIKit
import AppTrackingTransparency
import UserMessagingPlatform

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
        
        // for progress hud
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.window = self.window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        guard !didRequestConsent else { return }
        didRequestConsent = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
            self.requestGoogleConsent()
        })
    }

    // MARK: - Google User Messaging Platform (consent)

    private var didRequestConsent = false

    // Gather GDPR/UK consent via Google's User Messaging Platform before requesting any ads.
    // AdMob requires this for EEA/UK traffic; requesting ads without it can restrict serving
    // to non-personalized, much lower-paying ads. The ATT prompt follows once this resolves,
    // so the two prompts never overlap.
    private func requestGoogleConsent() {
        let parameters = RequestParameters()

        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            if let error = error {
                print("⚠️ UMP consent info update failed: \(error.localizedDescription)")
                // Fall through anyway so ads aren't permanently blocked by a one-off network error.
                self?.finishConsentGathering()
                return
            }

            ConsentForm.loadAndPresentIfRequired(from: self?.window?.rootViewController) { [weak self] formError in
                if let formError = formError {
                    print("⚠️ UMP consent form failed: \(formError.localizedDescription)")
                }
                self?.finishConsentGathering()
            }
        }
    }

    private func finishConsentGathering() {
        if ConsentInformation.shared.canRequestAds {
            (UIApplication.shared.delegate as? AppDelegate)?.startGoogleMobileAdsSDK()
        }
        requestTrackingAuthorization()
    }

    private func requestTrackingAuthorization() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                    case .authorized:
                        print("enable tracking")
                    case .denied:
                        print("disable tracking")
                    default:
                        print("default tracking")
                }
            }
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

