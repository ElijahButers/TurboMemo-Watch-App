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

enum InterfaceState {
  case Instantiated
  case Awake
  case Initialized
}

class InterfaceController: WKInterfaceController, MemoStoreObserver {
  
  /// A group that's shown when the controller doesn't have valid content, e.g. there is no voice or video memo.
  /// invalidContentGroup and validContentGroup are mutually exclusive and are not shown at the same time.
  @IBOutlet private var invalidContentGroup: WKInterfaceGroup!
  
  /// A group that's shown when there is content.
  /// invalidContentGroup and validContentGroup are mutually exclusive and are not shown at the same time.
  @IBOutlet private var validContentGroup: WKInterfaceGroup!
  
  /// The interface table where content is shown.
  @IBOutlet private var interfaceTable: WKInterfaceTable!
  
  private let dateFormatter: NSDateFormatter = {
    let dateFormatter = NSDateFormatter()
    dateFormatter.dateFormat = "hh:mma\nMM/dd/yyyy"
    return dateFormatter
    }()
  
  var memos = [BaseMemo]()
  var interfaceState = InterfaceState.Instantiated
  
  override func awakeWithContext(context: AnyObject?) {
    super.awakeWithContext(context)
    interfaceState = .Awake
  }
  
  override func willActivate() {
    super.willActivate()
    MemoStore.sharedStore.registerObserver(self)
  }
  
  override func didDeactivate() {
    super.didDeactivate()
    MemoStore.sharedStore.unregisterObserver(self)
  }
  
  // MARK: Helper
  
  /// The designated helper method to reload and update the entire interface when the data source is updated.
  func reloadInterface() {
    updateVisiblityOfInterfaceContentGroups { () -> Void in
      self.updateInterfaceTableRowCounts({ () -> Void in
        self.updateInterfaceTableData()
      })
    }
  }
  
  /// A helper method to change and update visiblity of WKInterfaceGroup objects based on content.
  func updateVisiblityOfInterfaceContentGroups(completion: () -> Void) {
    let hasContent = (memos.count != 0)
    validContentGroup.setHidden(!hasContent)
    invalidContentGroup.setHidden(hasContent)
    performBlock(completion)
  }
  
  /// A helper method to initialize or update the number of rows in the interface table.
  func updateInterfaceTableRowCounts(completion: () -> Void) {
    switch interfaceState {
    case .Instantiated:
      break
      
    case .Awake:
      fallthrough
      
    case .Initialized:
      interfaceTable.setNumberOfRows(memos.count, withRowType: "MemoRowController")
      interfaceState = InterfaceState.Initialized
    }
    performBlock(completion)
  }
  
  /// A helper method to set and update content of the interface table
  func updateInterfaceTableData() {
    if interfaceState != .Initialized { return }
    for (index, memo) in memos.enumerate() {
      let controller = interfaceTable.rowControllerAtIndex(index) as! MemoRowController
      let dateString = dateFormatter.stringFromDate(memo.date)
      controller.textLabel.setText(dateString)
      
      if let videoMemo = memo as? VideoMemo {
        if let image = videoMemo.smallPreviewImage {
          let imageData = UIImagePNGRepresentation(image)
          controller.previewImage.setImageData(imageData)
        }
      }
    }
  }
  
  // MARK: MemoStoreObserver
  
  func memoStore(store: MemoStore, didUpdateMemos memos: [BaseMemo]) {
    self.memos = memos
    reloadInterface()
  }
  
}
