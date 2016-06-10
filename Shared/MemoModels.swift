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

import UIKit

/// Base Memo. The base class for a memo.
@objc(BaseMemo)
public class BaseMemo: NSObject, NSCoding, NSCopying {
  
  public let date: NSDate
  public let filename: String
  public let URL: NSURL
  public init(filename: String, date: NSDate) {
    self.filename = filename
    self.date = date
    
    let userDocuments = NSFileManager.defaultManager().userDocumentsDirectory()
    self.URL = userDocuments.URLByAppendingPathComponent(filename)
    
    super.init()
  }
  
  // MARK: NSCoding
  
  public required init?(coder aDecoder: NSCoder) {
    self.date = aDecoder.decodeObjectForKey("date") as! NSDate
    self.filename = aDecoder.decodeObjectForKey("filename") as! String
    let userDocuments = NSFileManager.defaultManager().userDocumentsDirectory()
    self.URL = userDocuments.URLByAppendingPathComponent(filename)
    
    super.init()
  }
  
  public func encodeWithCoder(aCoder: NSCoder) {
    aCoder.encodeObject(self.date, forKey: "date")
    aCoder.encodeObject(self.filename, forKey: "filename")
  }
  
  public func copyWithZone(zone: NSZone) -> AnyObject {
    let copy = BaseMemo(filename: filename, date: date)
    return copy
  }
  
}

/// A voice memo.
@objc(VoiceMemo)
public class VoiceMemo: BaseMemo {
  public override func copyWithZone(zone: NSZone) -> AnyObject {
    let copy = VoiceMemo(filename: filename, date: date)
    return copy
  }
}

/// A video memo.
@objc(VideoMemo)
public class VideoMemo: BaseMemo {
  
  /// Large preview image for iOS
  public var largePreviewImage: UIImage?
  
  /// Small preview image for watchOS
  public var smallPreviewImage: UIImage?
  
  public required override init(filename: String, date: NSDate) {
    super.init(filename: filename, date: date)
  }
  
  // MARK: NSCoding
  
  public required init?(coder aDecoder: NSCoder) {
    if let largeData = aDecoder.decodeObjectForKey("largePreviewImage") as? NSData {
      let image = UIImage(data: largeData)
      self.largePreviewImage = image
    }
    if let smallData = aDecoder.decodeObjectForKey("smallPreviewImage") as? NSData {
      let image = UIImage(data: smallData)
      self.smallPreviewImage = image
    }
    super.init(coder: aDecoder)
  }
  
  public override func encodeWithCoder(aCoder: NSCoder) {
    if let image = largePreviewImage {
      let data = UIImageJPEGRepresentation(image, 1.0)
      aCoder.encodeObject(data, forKey: "largePreviewImage")
    }
    if let image = smallPreviewImage {
      let data = UIImageJPEGRepresentation(image, 1.0)
      aCoder.encodeObject(data, forKey: "smallPreviewImage")
    }
    super.encodeWithCoder(aCoder)
  }
  
  public override func copyWithZone(zone: NSZone) -> AnyObject {
    let copy = VideoMemo(filename: filename, date: date)
    copy.largePreviewImage = largePreviewImage
    copy.smallPreviewImage = smallPreviewImage
    return copy
  }
  
}