/*
*  Copyright (c) 2011-2020, Zingaya, Inc. All rights reserved.
*/

import UIKit

enum CallOptionButtonModels {
    static let start = CallOptionButton.Model(
        image: UIImage(),
        text: "Start"
    )
    static let chooseAudio = CallOptionButton.Model(
        image: UIImage(named: "audioDevice"),
        text: "Audio"
    )
    static let enableVideo = CallOptionButton.Model(
        image: UIImage(),
        text: "Enable"
    )
    static let recreate = CallOptionButton.Model(
        image: UIImage(),
        text: "Recreate"
    )
    static let disconnect = CallOptionButton.Model(
        image: UIImage(),
        text: "Disconnect"
    )
    static let exit = CallOptionButton.Model(
        image: UIImage(named: "exit"),
        imageTint: #colorLiteral(red: 1, green: 0.02352941176, blue: 0.2549019608, alpha: 1),
        text: "Leave"
    )
}
