//
//  BackgroundVideoPlayer.swift
//  Conference
//
//  Created by Alexander Kremenets on 12.01.2021.
//


import Foundation
import UIKit
import AVFoundation
import CoreMedia
import VoxImplant
import PromiseKit
import XCDYouTubeKit

#if os(iOS)
import AVKit
#endif

public class BackgroundVideoPlayer: UIViewController {

    private let playerController = AVPlayerViewController()

    private var player: AVPlayer!

    // url for the youtube video
    var contentVideoIdString: String!
    var video: CancellablePromise<URL>!

    deinit {
        if video?.isPending == true {
            video.cancel()
        }
    }

    public convenience init(withURL url: String) {
        self.init()
        self.contentVideoIdString = url
        self.resolveVideo()
        self.processVideoResolution()
    }

    private func resolveVideo() {
        if self.video != nil && self.video.isPending {
            self.video.cancel()
            self.video = nil
        }

        self.video = Promise { seal in
            XCDYouTubeClient.default().getVideoWithIdentifier(self.contentVideoIdString, completionHandler: { video, error in
                if let error = error {
                    log("An error occured on video get: \(error.localizedDescription)")
                }
                seal.resolve(
                    video?.streamURLs[XCDYouTubeVideoQualityHTTPLiveStreaming]
                        ?? video?.streamURLs[XCDYouTubeVideoQuality.HD720.rawValue],
                    error)
            })
        }.asCancellable()
    }

    public func deactivate() {
        player?.pause()
    }

    private func processVideoResolution() {
        video.done {
            if self.player == nil {
                self.loopVideo(in: AVPlayer(url: $0))
            } else {
                self.playVideo()
            }
        }.catch { [weak self] err in
            if err.isCancelled || self == nil {
                return
            }
            let alert = UIAlertController(title: "Video Failure", message: err.localizedDescription, preferredStyle: .alert)
            let dismiss = UIAlertAction(title: "ok", style: .cancel, handler: nil)
            let retry = UIAlertAction(title: "retry", style: .default) { [weak self] _ in
                self?.resolveVideo()
                self?.processVideoResolution()
            }

            alert.addAction(retry)
            alert.addAction(dismiss)

            self?.present(alert, animated: true, completion: nil)
        }
    }

    public func setNewStreamURL(withURL url: String) {
        self.contentVideoIdString = url
        self.player = nil
        self.resolveVideo()
        self.processVideoResolution()
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        playerController.showsPlaybackControls = false
        playerController.videoGravity = .resizeAspect

        playerController.willMove(toParent: self)

        addChild(playerController)
        playerController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerController.view)
        playerController.didMove(toParent: self)
    }

    private func loopVideo(in avplayer: AVPlayer) {
        log("loopVideo")
        player = avplayer

        playerController.player = player

        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = true
        playVideo()
    }

    public func playVideo(delay: Double = 0) {
        log("playVideo")
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay) {
            do {
                try AVAudioSession.sharedInstance().setCategory(
                    .playback,
                    mode: .moviePlayback,
                    options: .mixWithOthers
                )
                try AVAudioSession.sharedInstance().setActive(true)
            } catch (let error) {
                fatalError(error.localizedDescription)
            }
            self.player.play()
        }
    }

    public func pauseVideo() {
        log("pauseVideo")
        player?.pause()
    }
}
