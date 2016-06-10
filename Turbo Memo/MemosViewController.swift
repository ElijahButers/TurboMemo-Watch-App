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

import AVFoundation
import AVKit
import MobileCoreServices
import UIKit

class MemosViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MemoStoreObserver {
  
  static let MemoCellIdentifier = "MemoCellIdentifier"
  
  var memos = [BaseMemo]()
  
  let dateFormatter: NSDateFormatter = {
    let formatter = NSDateFormatter()
    formatter.dateStyle = .LongStyle
    formatter.timeStyle = .ShortStyle
    return formatter
    }()
  
  // MARK: View Life Cycle
  
  deinit {
    MemoStore.sharedStore.unregisterObserver(self)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Turbo Memo"
    tableView.contentInset = UIEdgeInsets(top: -36, left: 0, bottom: 0, right: 0)
    MemoStore.sharedStore.registerObserver(self)
  }
  
  override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    setTableViewBackgroundImageView()
  }
  
  // MARK: MemoStoreObserver
  
  func memoStore(store: MemoStore, didUpdateMemos memos: [BaseMemo]) {
    self.memos = memos
    tableView.reloadData()
    setTableViewBackgroundImageView()
  }
  
  // MARK: IBActions
  
  @IBAction private func addMemoButtonTapped(sender: UIButton) {
    
    // Create an action sheet.
    let controller = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
    
    // Cancel button.
    let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil)
    controller.addAction(cancelAction)
    
    // Add audio button.
    weak var weakSelf = self
    let audioAction = UIAlertAction(title: "Audio", style: UIAlertActionStyle.Default, handler: { (let action: UIAlertAction) -> Void in
      weakSelf?.presentAudioRecorderController()
    })
    controller.addAction(audioAction)
    
    // Add video button if possible.
    let videoAction = UIAlertAction(title: "Video", style: UIAlertActionStyle.Default) { (let action: UIAlertAction) -> Void in
        weakSelf?.presentCameraControllerForSourceType(UIImagePickerControllerSourceType.PhotoLibrary)
    }
    controller.addAction(videoAction)
    
    // Present it.
    presentViewController(controller, animated: true, completion: nil)
  }
  
  // MARK: UITableViewDelegate
  
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return memos.count
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier(MemosViewController.MemoCellIdentifier, forIndexPath: indexPath) as! MemoCell
    let memo: BaseMemo = memos[indexPath.row]
    cell.timeLabel.text = dateFormatter.stringFromDate(memo.date)
    if let videoMemo = memo as? VideoMemo {
      cell.previewImageView.image = videoMemo.largePreviewImage
    } else {
      cell.previewImageView.image = UIImage(named: "voice-icon")
    }
    return cell
  }
  
  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    let memo = memos[indexPath.row]
    if let videoMemo = memo as? VideoMemo {
      playVideoAtURL(videoMemo.URL)
    } else if let voiceMemo = memo as? VoiceMemo {
      playAudioAtURL(voiceMemo.URL)
    }
    tableView.deselectRowAtIndexPath(indexPath, animated: true)
  }
  
  override func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
    return UITableViewCellEditingStyle.Delete
  }
  
  override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    let index = indexPath.row
    let memoToDelete = memos[index]
    memos.removeAtIndex(index)
    let store = MemoStore.sharedStore
    store.removeMemo(memoToDelete)
    store.save()
    
    do {
      try NSFileManager.defaultManager().removeItemAtURL(memoToDelete.URL)
    }
    catch {
      print("Failed to delete \(memoToDelete.URL) from disk.")
    }
  }
  
  // MARK: Helpers
  
  private func setTableViewBackgroundImageView() {
    
    // If there 'are' memos, make sure table view background view is clear and return.
    if memos.isEmpty == false {
      tableView.backgroundView = nil
      return
    }
    
    // Otherwise, display the onboarding image in background.
    let imageView: UIImageView
    if let backgroundView = tableView.backgroundView as? UIImageView {
      imageView = backgroundView
    } else {
      let image = UIImage(named: "onboarding")
      imageView = UIImageView(image: image)
    }
    
    let isWider = (CGRectGetWidth(tableView.bounds) > CGRectGetHeight(tableView.bounds))
    imageView.contentMode = isWider ? .Right : .ScaleAspectFill
    imageView.frame = tableView.bounds
    tableView.backgroundView = imageView
  }
  
  /// Create an snapshot of a movie at a given URL and return UIImage.
  private func snapshotFromMovieAtURL(movieURL: NSURL) -> UIImage {
    let asset = AVAsset(URL: movieURL)
    let generator: AVAssetImageGenerator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    let time: CMTime = CMTimeMake(1, 60)
    do {
      let imageRef: CGImageRef = try generator.copyCGImageAtTime(time, actualTime: nil)
      let snapshot = UIImage(CGImage: imageRef)
      return snapshot
    }
    catch {}
    return UIImage()
  }
  
  private func resizeImage(image: UIImage) -> UIImage {
    let scale = 80.0 / image.size.width
    let size  = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let rect  = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
    
    UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
    image.drawInRect(rect)
    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return resizedImage
  }
  
  /// Plays back a movie item using AVPlayerViewController that's presented modally.
  private func playVideoAtURL(URL: NSURL) {
    let controller = AVPlayerViewController()
    controller.player = AVPlayer(URL: URL)
    presentViewController(controller, animated: true) { () -> Void in
      controller.player?.play()
    }
  }
  
  //// A helper method to configure and display image picker controller based on the source type.
  func presentCameraControllerForSourceType(sourceType: UIImagePickerControllerSourceType) {
    let controller = UIImagePickerController()
    controller.delegate = self
    controller.sourceType = sourceType
    controller.mediaTypes = [String(kUTTypeMovie)]
    controller.view.tintColor = UIColor.themeTintColor()
    presentViewController(controller, animated: true, completion: nil)
  }
  
  //// A helper method to configure and display audio recorder controller.
  func presentAudioRecorderController() {
    let controller = storyboard?.instantiateViewControllerWithIdentifier("AudioViewController") as! AudioViewController
    unowned let weakSelf = self
    controller.completion = { (output: NSURL?) in
      weakSelf.dismissViewControllerAnimated(true, completion: nil)
      guard let memoURL = output else { return }
      guard let destination = NSFileManager.defaultManager().moveItemAtURLToUserDocuments(memoURL, renameTo: nil) else { return }
      let memo = VoiceMemo(filename: destination.lastPathComponent!, date: NSDate())
      MemoStore.sharedStore.addMemo(memo)
      MemoStore.sharedStore.save()
    }
    controller.mode = AudioMode.Record
    presentViewController(controller, animated: true, completion: nil)
  }
  
  //// A helper method to configure and display audio player controller.
  func playAudioAtURL(URL:NSURL) {
    let controller = storyboard?.instantiateViewControllerWithIdentifier("AudioViewController") as! AudioViewController
    unowned let weakSelf = self
    controller.completion = { (output: NSURL?) in
      weakSelf.dismissViewControllerAnimated(true, completion: nil)
    }
    controller.audioFileToPlay = URL
    controller.mode = AudioMode.Play
    controller.shouldStartOnViewDidAppear = true
    presentViewController(controller, animated: true, completion: nil)
  }
  
  /// A convenient helper method to present a UIAlertViewController with a generic statement that a story was not found.
  func presentDismissOnlyAlertControllerWithMessage(message: String) {
    let controller = UIAlertController(title: "Error", message: message, preferredStyle: UIAlertControllerStyle.Alert)
    controller.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Cancel, handler: nil))
    presentViewController(controller, animated: true, completion: nil)
  }
  
  // MARK: UIImagePickerControllerDelegate
  
  func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
    
    // What did user pick? Is it a movie or is it an image?
    let mediaType = info[UIImagePickerControllerMediaType] as! String
    if mediaType == String(kUTTypeMovie) {
      let assetURL = info[UIImagePickerControllerMediaURL] as! NSURL
      
      // Save the video to user documents directory.
      let helper = MemoFileNameHelper()
      let dateFormatter = helper.dateFormatterForFileName
      let date = NSDate()
      let filename = dateFormatter.stringFromDate(date).stringByAppendingString(".mov")
      
      if let destination = NSFileManager.defaultManager().moveItemAtURLToUserDocuments(assetURL, renameTo: filename) {
        let memo = VideoMemo(filename: filename, date: NSDate())
        
        let largePreview = snapshotFromMovieAtURL(destination)
        memo.largePreviewImage = largePreview
        
        let smallPreview = resizeImage(largePreview)
        memo.smallPreviewImage = smallPreview
        
        let store = MemoStore.sharedStore
        store.addMemo(memo)
        store.save()
      } else {
        presentDismissOnlyAlertControllerWithMessage("Oops! Couldn't save the video file.")
      }
    }
    picker.dismissViewControllerAnimated(false, completion: nil)
  }
  
}
