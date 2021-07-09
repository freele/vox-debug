/*
 *  Copyright (c) 2011-2020, Zingaya, Inc. All rights reserved.
 */

import UIKit
import VoxImplantSDK

fileprivate let client = VIClient(delegateQueue: DispatchQueue.main)
fileprivate let voximplantService = VoximplantService(client: client)
fileprivate let storyAssembler = StoryAssembler(
    voximplantService,
    voximplantService,
    voximplantService
)

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    private var volumeObserver: NSKeyValueObservation?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = storyAssembler.login
        window?.makeKeyAndVisible()

        volumeObserver = AVAudioSession.sharedInstance().observe(
            \.outputVolume,
            options: [.new, .old]
        ) { session, change in
            log("outputVolume changed from \(String(describing: change.oldValue)) to \(String(describing: change.newValue))")
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil,
            queue: nil
        ) { notification in
            if let volume = notification.userInfo?["AVSystemController_AudioVolumeNotificationParameter"] as? Float,
               let category = notification.userInfo?["AVSystemController_AudioCategoryNotificationParameter"] as? String {
                log("volume changed to: \(volume), with category: \(category)")
            } else {
                log("volume changed to: \(AVAudioSession.sharedInstance().outputVolume)")
            }
        }

        VIClient.setLogLevel(.debug)

        return true
    }
}
