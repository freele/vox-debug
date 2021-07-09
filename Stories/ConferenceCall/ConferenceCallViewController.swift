/*
*  Copyright (c) 2011-2020, Zingaya, Inc. All rights reserved.
*/

import UIKit

final class ConferenceCallViewController:
    UIViewController,
    AudioDeviceAlertSelecting,
    ConferenceObserver,
    SocketObserver
{
    @IBOutlet private weak var backgroundVideoWrapper: UIView!
    @IBOutlet private weak var conferenceView: ConferenceView!
    @IBOutlet private weak var startButton: CallOptionButton!
    @IBOutlet private weak var chooseAudioButton: CallOptionButton!
    @IBOutlet private weak var enableVideoButton: CallOptionButton!
    @IBOutlet private weak var recreateButton: CallOptionButton!
    @IBOutlet private weak var disconnectButton: CallOptionButton!
    @IBOutlet private weak var exitButton: CallOptionButton!
    
    @IBOutlet weak var socketView: UIView! //internal
    var manageConference: ManageConference! // DI
    var leaveConference: LeaveConference! // DI
    var getShareLink: GetShareLink! // DI
    var storyAssembler: StoryAssembler! // DI
    var video: Bool! // DI
    
    private let videoPlayer = BackgroundVideoPlayer(withURL: "dp8PhLsUcFE")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        videoPlayer.willMove(toParent: self)
        addChild(videoPlayer)
        videoPlayer.view.translatesAutoresizingMaskIntoConstraints = false
        videoPlayer.view.frame = backgroundVideoWrapper.frame
        view.addSubview(videoPlayer.view)
        videoPlayer.didMove(toParent: self)
        
        startButton.doInitialSetup(
            with: CallOptionButtonModels.start,
            and: { [weak self] button in
                log("Start call pressed on call screen")
                guard let self = self else { return }
                do {
                    try self.manageConference.startConference()
                } catch (let error) {
                    AlertHelper.showError(message: error.localizedDescription, on: self)
                }
            }
        )
        
        chooseAudioButton.doInitialSetup(
            with: CallOptionButtonModels.chooseAudio,
            and: { [weak self] button in
                log("ChooseAudio pressed")
                self?.showAudioDevicesActionSheet(sourceView: button)
            }
        )
        
        enableVideoButton.doInitialSetup(
            with: CallOptionButtonModels.enableVideo,
            and: { [weak self] button in
                log("Enable video pressed")
                self?.videoPlayer.playVideo()
            }
        )
        
        recreateButton.doInitialSetup(
            with: CallOptionButtonModels.recreate,
            and: { [weak self] button in
                log("Recreate call pressed")
                guard let self = self else { return }
                do {
                    try self.manageConference.recreateConference()
                } catch (let error) {
                    AlertHelper.showError(message: error.localizedDescription, on: self)
                }
            }
        )
        
        disconnectButton.doInitialSetup(
            with: CallOptionButtonModels.disconnect,
            and: { [weak self] button in
                log("Disconnect pressed")
                self?.leaveConference.withoutDisconnecting()
            }
        )
        
        exitButton.doInitialSetup(
            with: CallOptionButtonModels.exit,
            and: { [weak self] button in
                log("Exit pressed")
                button.state = .unavailable
                self?.leaveConference()
                self?.dismiss(animated: true)
            }
        )
        socketView.isHidden = true
        socketView.layer.cornerRadius = 10
        
        manageConference.observeVideoStream(conferenceView)
        manageConference.observeConference(self)
        manageConference.observeSocket(self)
    }
    
    // MARK: - ConferenceObserver -
    func didChangeState(to state: ConferenceState) {
        DispatchQueue.main.async {
            log("didChangeState to \(state)")
            switch state {
            case .connected:
                self.navigationController?.popToViewController(self, animated: true)
            case .reconnecting:
                self.navigationController?.pushViewController(
                    self.storyAssembler.assembleProgress(
                        reason: .reconnecting,
                        onCancel: {
                            self.dismiss(animated: true)
                            self.manageConference = nil
                    }),
                    animated: true
                )
            case .ended(let reason):
                if case .disconnected = reason {
                    self.videoPlayer.playVideo(delay: 0.2)
                    return
                }
                
                var title: String = ""
                var description = ""
                
                if case .failed(let error as ReconnectError) = reason {
                    title = "Reconnect failed"
                    description = error.localizedDescription
                    self.navigationController?.popToViewController(self, animated: true)
                    
                } else if case .failed(let error) = reason {
                    title = "Disconnected"
                    description = "You've been disconnected due to \((error as? ConferenceError)?.localizedDescription ?? "internal error")"
                    
                } else if case .kicked = reason {
                    title = "You've been kicked"
                    description = "The owner of the conference kicked you"
                }
                
                AlertHelper.showAlert(
                    title: title,
                    message: description,
                    actions: [UIAlertAction(title: "Close", style: .default) { _ in
                        self.dismiss(animated: true)
                        self.manageConference = nil
                        }
                    ],
                    on: self
                )
            }
        }
    }
    
    func didAddParticipant(_ participant: ConferenceParticipant) {
        conferenceView.addParticipant(participant)
    }
    
    func didRemoveParticipant(withID id: ParticipantID) {
        conferenceView.removeParticipant(withID: id)
    }
    
    func didUpdateParticipant(_ participant: ConferenceParticipant) {
        conferenceView.updateParticipant(participant)
    }
    
    // MARK: - SocketObserver - 
    func socketConnectedStateChanged(to connected: Bool) {
        socketView.backgroundColor = connected ? .green : #colorLiteral(red: 0.9610000253, green: 0.2939999998, blue: 0.3689999878, alpha: 1)
    }
}
