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

import CoreAudio
import AVFoundation
import UIKit

enum AudioMode {
  case Undefined
  case Play
  case Record
}

class AudioViewController: UIViewController, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
  
  var completion: ((output: NSURL?) -> ())?
  var audioFileToPlay: NSURL?
  var mode: AudioMode = .Undefined
  
  /// A boolean indicating whether 'record' or 'play' should be automatically performed when view did appear.
  var shouldStartOnViewDidAppear: Bool = false
  
  deinit {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setActive(false)
    }
    catch {}
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    progressView.progress = 0.0
    saveButton.hidden = true
    updateToMode(.Undefined)
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    
    switch mode {
    case .Play:
      updateToMode(.Play)
      if shouldStartOnViewDidAppear { play() }
      
    case .Record:
      unowned let weakSelf = self
      AVAudioSession.sharedInstance().requestRecordPermission({ (granted: Bool) -> Void in
        if granted {
          weakSelf.updateToMode(.Record)
          if weakSelf.shouldStartOnViewDidAppear { weakSelf.record() }
        } else {
          weakSelf.updateToMode(.Undefined)
          weakSelf.presentAlertControllerForDeniedPermission()
        }
      })
      
    case .Undefined : break
    }
  }
  
  // MARK: Private
  
  @IBOutlet private var cancelButton: UIButton!
  @IBOutlet private var saveButton: UIButton!
  
  @IBOutlet private var playButton: UIButton!
  @IBOutlet private var recordButton: UIButton!
  @IBOutlet private var stopButton: UIButton!
  @IBOutlet private var timeLabel: UILabel!
  @IBOutlet private var progressView: UIProgressView!
  
  private var recorder: AVAudioRecorder?
  private var player: AVAudioPlayer?
  private var timer: NSTimer?
  
  private let recordSettings: Dictionary<String, AnyObject> = {
    var settings = Dictionary<String, AnyObject>()
    settings[AVFormatIDKey] = Int(kAudioFormatMPEG4AAC)
    settings[AVSampleRateKey] = 44100.0
    settings[AVNumberOfChannelsKey] = 2
    return settings
    }()
  
  private let outputURL: NSURL = {
    let helper = MemoFileNameHelper()
    let dateFormatter = helper.dateFormatterForFileName
    let date = NSDate()
    let filename = dateFormatter.stringFromDate(date)
    let output = NSFileManager.defaultManager().userTemporaryDirectory().URLByAppendingPathComponent("\(filename).m4a")
    return output
    }()
  
  private let timeFormatter: NSNumberFormatter = {
    let formatter = NSNumberFormatter()
    formatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 0
    formatter.minimumIntegerDigits = 2
    formatter.maximumIntegerDigits = 2
    return formatter
    }()
  
  /// Present an alert controller to notify user that permission is required for recording.
  private func presentAlertControllerForDeniedPermission() {
    let alertController = UIAlertController(title: "Error", message: "Turbo Memo requires your permission for audio recording. Go to Settings and give Turbo Memo access to microphone.", preferredStyle: UIAlertControllerStyle.Alert)
    let cancelAction = UIAlertAction(title: "Dimiss", style: UIAlertActionStyle.Cancel, handler: { (action: UIAlertAction) -> Void in
      self.cancelButtonTapped(nil)
    })
    alertController.addAction(cancelAction)
    presentViewController(alertController, animated: true, completion: nil)
  }
  
  private func formattedTimeFromTime(time: NSTimeInterval) -> String {
    let seconds = Float(time % 60.0)
    let formatted = timeFormatter.stringFromNumber(seconds)!
    return "00:00:\(formatted)"
  }
  
  private func updateToMode(mode: AudioMode) {
    let session = AVAudioSession.sharedInstance()
    
    do {
      switch mode {
      case .Play:
        playButton.hidden = false
        recordButton.hidden = true
        stopButton.hidden = true
        
        do {
          try session.setCategory(AVAudioSessionCategoryPlayback)
          player = try AVAudioPlayer(contentsOfURL: audioFileToPlay!)
          player?.numberOfLoops = 1
          player?.delegate = self
          player?.prepareToPlay()
        } catch let error {
          print("Failed to play audio: \(error)")
          playButton.hidden = true
        }
        
      case .Record:
        playButton.hidden = true
        recordButton.hidden = false
        stopButton.hidden = true
        
        do {
          try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
          recorder = try AVAudioRecorder(URL: outputURL, settings: recordSettings)
          recorder?.delegate = self
          recorder?.prepareToRecord()
        } catch let error {
          print("Failed to record audio: \(error)")
          recordButton.hidden = true
        }
        
      case .Undefined:
        playButton.hidden = true
        recordButton.hidden = true
        stopButton.hidden = true
        break
      }
      
      try session.setActive(true)
    }
    catch {
      
    }
  }
  
  @objc private func updateViewWithTimer(timer: NSTimer) {
    
    var currentTime: NSTimeInterval = 0.0
    var duration: NSTimeInterval = 0.0
    
    switch mode {
    case .Play:
      guard let player = player else { return }
      currentTime = player.currentTime
      duration = player.duration
      
    case .Record:
      guard let recorder = recorder else { return }
      currentTime = recorder.currentTime
      duration = 30.0
      
    case .Undefined:
      break
    }
    
    let progress = Float(currentTime / duration)
    progressView.setProgress(progress, animated: true)
    timeLabel.text = formattedTimeFromTime(currentTime)
  }
  
  /// A helper function to kick off the timer and update UI.
  private func kickOffTimer() {
    timer?.invalidate()
    timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "updateViewWithTimer:", userInfo: nil, repeats: true)
    recorder?.recordForDuration(30.0)
  }
  
  /// A helper function to start playing an audio file and update UI accordingly.
  private func play() {
    playButton.hidden = true
    stopButton.hidden = false
    cancelButton.hidden = true
    player?.play()
    
    kickOffTimer()
  }
  
  /// A helper function to start recording an audio and update UI accordingly.
  private func record() {
    recordButton.hidden = true
    stopButton.hidden = false
    saveButton.hidden = true
    cancelButton.hidden = true
    
    kickOffTimer()
  }
  
  // MARK: IBActions
  
  @IBAction private func recordButtonTapped(sender: UIButton) {
    record()
  }
  
  @IBAction private func stopButtonTapped(sender: UIButton) {
    stopButton.hidden = true
    cancelButton.hidden = false
    
    switch mode {
    case .Play:
      player?.stop()
      playButton.hidden = false
      
    case .Record:
      recorder?.stop()
      recordButton.hidden = false
      saveButton.hidden = false
      
    case .Undefined:
      break
    }
  }
  
  @IBAction private func playbackButtonTapped(sender: UIButton?) {
    play()
  }
  
  @IBAction private func cancelButtonTapped(sender: UIButton?) {
    if let completion = completion {
      completion(output: nil)
    }
  }
  
  @IBAction private func saveButtonTapped(sender: UIButton?) {
    if let completion = completion {
      completion(output: outputURL)
    }
  }
  
  // MARK: AVAudioPlayerDelegate
  
  func audioRecorderDidFinishRecording(recorder: AVAudioRecorder, successfully flag: Bool) {
    timer?.invalidate()
  }
  
  func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
    timer?.invalidate()
  }
}