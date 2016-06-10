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

import Foundation
import WatchConnectivity
#if os(iOS)
  import AVFoundation
#endif

/// A protocol to communicate with interested objects when there is a change in MemoStore.
public protocol MemoStoreObserver {
  
  func memoStore(store: MemoStore, didUpdateMemos memos: [BaseMemo])
  
}

public class MemoStore: NSObject {
  
  // MARK: Memo collection
  
  /// Adds a BaseMemo or any of its subclasses to the collection.
  public func addMemo(memo: BaseMemo) {
    memos[memo.date] = memo
    
    // If the new memo is video memo, nil out the large preview
    // because the Watch doesn't need it and it makes the size 
    // of the payload too large.
    let memoToBroadcast: BaseMemo
    if memo is VideoMemo {
      let videoMemo: VideoMemo = memo.copy() as! VideoMemo
      videoMemo.largePreviewImage = nil
      memoToBroadcast = videoMemo
    } else {
      memoToBroadcast = memo
    }
    
    broadcastAssociatedFileForMemo(memoToBroadcast)
    broadcastStoreUpdate()
  }
  
  /// Removes a BaseMemo or any of its subclasses from the collection.
  public func removeMemo(memo: BaseMemo) {
    memos[memo.date] = nil
    broadcastStoreUpdate()
  }
  
  /// Returns an array of BaseMemo or any of its subclasses sorted by date of creation.
  public func sortedMemos(ordered: NSComparisonResult) -> [BaseMemo] {
    let allMemos = memos.values
    let sorted = allMemos.sort { return $0.date.compare($1.date) == ordered }
    return sorted
  }
  
  // MARK: Life Cycle
  
  private var memos = [NSDate: BaseMemo]()
  private let operationQueue: NSOperationQueue = {
    let queue = NSOperationQueue()
    queue.maxConcurrentOperationCount = 1
    return queue
    } ()
  
  public static let sharedStore = MemoStore()
  override init() {
    super.init()
    activateSessionIfNeeded()
    weak var weakSelf = self
    readLogs { () -> Void in
      weakSelf?.notifyObserversWithUpdateMemos()
    }
  }
  
  // MARK: Private store file read and write handling
  
  /// Read and restore log collection from disk. Upon completion it will notify observers.
  private func readLogs(completion: (() -> Void)) {
    // Read logs from disk in the background.
    weak var weakSelf = self
    operationQueue.addOperationWithBlock { () -> Void in
      guard let weakSelf = weakSelf else { return }
      guard let data = NSData(contentsOfURL: weakSelf.storedLogsURL) else { return }
      guard let unarchived = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? [NSDate: BaseMemo] else { return }
      weakSelf.updateMemosWithMemos(unarchived)
      
      // Notfiy observers on the main thread.
      NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
        completion()
      })
    }
  }
  
  /// Saves log collection to disk.
  private func saveMemos() {
    weak var weakSelf = self
    let memosToSave = memos
    operationQueue.addOperationWithBlock { () -> Void in
      guard let weakSelf = weakSelf else { return }
      let dataRepresentation = NSKeyedArchiver.archivedDataWithRootObject(memosToSave)
      let success = dataRepresentation.writeToURL(weakSelf.storedLogsURL, atomically: true)
      print("Saved collection log: \(success)")
    }
  }
  
  /// Returns the URL to the stored logs in user documents directory.
  private let storedLogsURL: NSURL = {
    var URL: NSURL = NSURL()
    do {
      try URL = NSFileManager.defaultManager().URLForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomain: NSSearchPathDomainMask.UserDomainMask, appropriateForURL: nil, create: true)
      URL = URL.URLByAppendingPathComponent("turbo-memo.plist")
    }
    catch let error {
      print("MemoStore failed to get access to NSSearchPathDomainMask.UserDomainMask: \(error)")
    }
    return URL
    }()
  
  // MARK: Helpers
  
  /// Update the dictionary of memo on self with the given newMemos dictionary. Objects with the same key will be overwritten.
  private func updateMemosWithMemos(newMemos: [NSDate: BaseMemo]) {
    for (key, memo) in newMemos {
      memos[key] = memo
    }
  }
  
  /// An internal (private) helper method to notify observers when there is a change in the store.
  private func notifyObserversWithUpdateMemos() {
    weak var weakSelf = self
    operationQueue.addOperationWithBlock { () -> Void in
      guard let weakSelf = weakSelf else { return }
      let sorted = weakSelf.sortedMemos(NSComparisonResult.OrderedDescending)
      NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
        for (_, observer) in weakSelf.observers {
          observer.memoStore(weakSelf, didUpdateMemos: sorted)
        }
      })
    }
  }
  
  /// Synchronizes the current store with new ones. Deletes extras and requests those that are missing.
  private func synchronizeMemosWithMemos(newMemos: [NSDate: BaseMemo]) {
    weak var weakSelf = self
    operationQueue.addOperationWithBlock { () -> Void in
      guard let weakSelf = weakSelf else { return }
      
      // 1. Find out what's been deleted.
      var deletedMemos = [BaseMemo]()
      for (key, memo) in weakSelf.memos {
        if newMemos[key] == nil {
          deletedMemos.append(memo)
        }
      }
      
      // 2. Remove associated files of those memos that are deleted.
      for memo in deletedMemos {
        do {
          try NSFileManager.defaultManager().removeItemAtURL(memo.URL)
        } catch let error {
          print("Synchronizing: Failed to remove file: \(memo.URL) - Error: \(error)")
        }
      }
      
      // 3. Find out if there are new memos that are missing associated file.
      for (date, memo) in newMemos {
        let fileName = memo.URL.lastPathComponent!
        let fileURL = NSFileManager.defaultManager().userDocumentsDirectory().URLByAppendingPathComponent(fileName)
        let hasFile = NSFileManager.defaultManager().fileExistsAtPath(fileURL.relativePath!)
        
        // If associate file doesn't exist, send a message.
        // Don't need the replyHandler as the file comes back via file transfer.
        if !hasFile {
          print("Synchronizing: Sending request for file: \(fileName)")
          weakSelf.sendSynchronizationRequest(MemoStoreCommunicationKey.SendMemo, dates: [date])
        }
      }
      
      weakSelf.memos.removeAll()
      weakSelf.updateMemosWithMemos(newMemos)
      weakSelf.save()
    }
  }

  // MARK: WatchConnectivity
  
  private enum MemoStoreCommunicationKey: String {
    case Unknwon  = ""
    case Memos    = "memos"
    case AddMemo  = "added-memo"
    case SendMemo = "send-memo"
    case Sync     = "sync"
  }

  private var session: WCSession?
  
  // MARK: Operations
  
  private var observers = [Int: MemoStoreObserver]()
  
  /// Register an observer to get notified when there's a change in the store.
  public func registerObserver(observer: AnyObject) {
    let identifier = ObjectIdentifier(observer).hashValue
    guard let observer = observer as? MemoStoreObserver else { return }
    observers[identifier] = observer
    let sorted = sortedMemos(NSComparisonResult.OrderedDescending)
    observer.memoStore(self, didUpdateMemos: sorted)
  }
  
  /// Unregister an observer.
  public func unregisterObserver(observer: AnyObject) {
    let identifier = ObjectIdentifier(observer ).hashValue
    guard let _ = observer as? MemoStoreObserver else { return }
    observers[identifier] = nil
  }
  
  /// Save memos and broadcast an update notification to interested objects.
  public func save() {
    saveMemos()
    notifyObserversWithUpdateMemos()
  }
}

// MARK: WCSessionDelegate

extension MemoStore: WCSessionDelegate {
  
  /// Activates a session if needed. If there's currently an active session but the Watch is unpaired or Watch app is installed, session is nilled out.
  private func activateSessionIfNeeded() {
    
    // Early termination. There can't be a WCSession.
    if WCSession.isSupported() == false {
      return
    }
    
    // Can a new session be activated?
    let newSession = WCSession.defaultSession()
    newSession.delegate = self
    newSession.activateSession()
    self.session = newSession
    print("A new WCSession activated.")
  }
  
  /// Conveniently checks the state of current WCSession. It activates one if needed, or deactivates the current one if appropriate. Returns a WCSession or nil.
  private func currentActiveSession() -> WCSession? {
    activateSessionIfNeeded()
    return self.session
  }
  
  /// A private helper to broadcast only addition of a memo.
  private func broadcastAssociatedFileForMemo(memo: BaseMemo) {
    guard let session = currentActiveSession() else { return }
    performBroadcastWithSession(session) { (Void) -> Void in
      let data = NSKeyedArchiver.archivedDataWithRootObject(memo)
      let metadata = [MemoStoreCommunicationKey.AddMemo.rawValue: data]
      session.transferFile(memo.URL, metadata: metadata)
      print("Addition of a memo broadcasted via transferFile.")
    }
  }
  
  /// A private helper to broadcast a store update, either because a memo was deleted or to synchronize.
  private func broadcastStoreUpdate() {
    guard let session = currentActiveSession() else { return }
    performBroadcastWithSession(session) { (Void) -> Void in
      
      // Make a copy of the store so that we can modify objects as necessary.
      // If encounter a video memo, nil out the large preview
      // because the Watch doesn't need it and it makes the size
      // of the payload too large.
      var memosToBroadcast = [NSDate: BaseMemo]()
      for (key, memo) in self.memos {
        if let videoMemo = memo as? VideoMemo {
          let copy = videoMemo.copy() as! VideoMemo
          copy.largePreviewImage = nil
          memosToBroadcast[copy.date] = copy
        } else {
          memosToBroadcast[key] = memo
        }
      }
      let data = NSKeyedArchiver.archivedDataWithRootObject(memosToBroadcast)
      session.transferUserInfo([MemoStoreCommunicationKey.Memos.rawValue: data])
      print("Store update broadcasted via transferUserInfo.")
    }
  }
  
  private func sendSynchronizationRequest(request: MemoStoreCommunicationKey, dates: [NSDate]) {
    guard let session = currentActiveSession() else { return }
    performBroadcastWithSession(session, blockToBroadcast: { (Void) -> Void in
      print("Send synchronization request: \(request.rawValue)")
      session.sendMessage([request.rawValue: dates], replyHandler: nil, errorHandler: nil)
    })
  }
  
  /// A private helper to conditionally perform a broadcast via a session.
  private func performBroadcastWithSession(session: WCSession, blockToBroadcast block: (Void -> Void)) {
    #if os(iOS)
      if session.reachable {
        block()
      }
      #else
      block()
    #endif
  }
  
  /** ------------------------- iOS App State For Watch ------------------------ */
  
  public func sessionWatchStateDidChange(session: WCSession) {
    #if os(iOS)
    print("Watch state changed- paired: \(session.paired), installed: \(session.watchAppInstalled)")
    #endif
  }
  
  /** ------------------------- Interactive Messaging ------------------------- */
  
  public func sessionReachabilityDidChange(session: WCSession) {
    #if os(iOS)
      print("Watch reachability changed - isReachable: \(session.reachable)")
      broadcastStoreUpdate()
    #endif
  }
  
  public func session(session: WCSession, didFinishFileTransfer fileTransfer: WCSessionFileTransfer, error: NSError?) {
    print("File transfer finished - error: \(error)")
  }
  
  public func session(session: WCSession, didReceiveFile file: WCSessionFile) {
    print("Received file transfer: \(file.fileURL.lastPathComponent!)")
    print("Received file metadata: \(file.metadata!)")
    
    guard let data = file.metadata?[MemoStoreCommunicationKey.AddMemo.rawValue] as? NSData else { return }
    guard let newMemo = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? BaseMemo else { return }
    
    let URL = file.fileURL
    let destination = NSFileManager.defaultManager().moveItemAtURLToUserDocuments(URL, renameTo: nil)
    print("Moved transfered file to: \(destination!)")
    
    memos[newMemo.date] = newMemo
    save()
  }
  
  public func session(session: WCSession, didReceiveUserInfo userInfo: [String : AnyObject]) {
    print("Received userInfo: \(userInfo)")
    guard let data = userInfo[MemoStoreCommunicationKey.Memos.rawValue] as? NSData else { return }
    guard let dictionary = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? [NSDate: BaseMemo] else { return }
    synchronizeMemosWithMemos(dictionary)
  }
  
  public func session(session: WCSession, didReceiveMessage message: [String : AnyObject]) {
    print("Received message: \(message)")
    for (key, value) in message {
      let request = MemoStoreCommunicationKey(rawValue: key) ?? .Unknwon
      switch request {
      
      // Send specific memos.
      case .SendMemo:
        if let dates = value as? [NSDate] {
          for date in dates {
            if let memo = memos[date] {
              
              // To refactor common code.
              let memoToSend: BaseMemo
              
              // If the requested memo is a video memo, nil out the large preview
              // because the Watch doesn't need it and it makes the size
              // of the payload too large.
              if memo is VideoMemo {
                let copy = memo.copy() as! VideoMemo
                copy.largePreviewImage = nil
                memoToSend = copy
              } else {
                memoToSend = memo
              }
              
              // Send.
              broadcastAssociatedFileForMemo(memoToSend)
            }
          }
        }
      
      // Sync (send) all memos.
      case .Sync:
        broadcastStoreUpdate()
      default:
        print("Received unrecognized request: \(request)")
      }
    }
  }
}