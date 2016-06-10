/*
* Copyright (c) 2015 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import WatchKit

class AudioPlayerInterfaceController: WKInterfaceController {
  
  var player: WKAudioFilePlayer?
  
  override func awakeWithContext(context: AnyObject?) {
    super.awakeWithContext(context)
    
    if let memo = context as? VoiceMemo {
      let asset = WKAudioFileAsset(URL: memo.URL)
      let playerItem = WKAudioFilePlayerItem(asset: asset)
      player = WKAudioFilePlayer(playerItem: playerItem)
    }
  }
  
  override func didAppear() {
    super.didAppear()
    play()
  }
  
  private func play() {
    
    if player?.status == .ReadyToPlay {
      print("WKAudioPlayer is playing.")
      player?.play()
    } else {
      print("WKAudioPlayer failed to play")
    }
  }
  
  
  @IBAction func playButtonTapped() {
  }
  
  @IBAction func pauseButtonTapped() {
  }
  
}
