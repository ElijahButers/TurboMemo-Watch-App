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

extension NSFileManager {
  
  /// Moves a given file to user documents.
  /// Returns the destination URL on success or nil if it fails.
  func moveItemAtURLToUserDocuments(itemURL: NSURL, renameTo rename: String?) -> NSURL? {
    
    let filename: String
    if let renameToName = rename {
      filename = renameToName
    } else {
      filename = itemURL.lastPathComponent!
    }
    
    let destination = userDocumentsDirectory().URLByAppendingPathComponent(filename)
    let fileExists = fileExistsAtPath(destination.relativePath!)
    do {
      if fileExists {
        try replaceItemAtURL(destination, withItemAtURL: itemURL, backupItemName: nil, options: NSFileManagerItemReplacementOptions.UsingNewMetadataOnly, resultingItemURL: nil)
      } else {
        try moveItemAtURL(itemURL, toURL: destination)
      }
      return destination
    }
    catch let error {
      print("Failed to move \(itemURL) to user documents, \(destination): \(error)")
      return nil
    }
  }
  
  /// Returns the user documents directory URL.
  func userDocumentsDirectory() -> NSURL {
    var URL: NSURL = NSURL()
    do {
      try URL = NSFileManager.defaultManager().URLForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomain: NSSearchPathDomainMask.UserDomainMask, appropriateForURL: nil, create: true)
    }
    catch {}
    return URL
  }
  
  /// Returns the user temporary directory URL.
  func userTemporaryDirectory() -> NSURL {
    var URL: NSURL = NSURL()
    do {
      try URL = NSFileManager.defaultManager().URLForDirectory(NSSearchPathDirectory.CachesDirectory, inDomain: NSSearchPathDomainMask.UserDomainMask, appropriateForURL: nil, create: true)
    }
    catch {}
    return URL
  }
  
}