//
//  TableViewWrapper.swift
//  RAMReel
//
//  Created by Mikhail Stepkin on 4/9/15.
//  Copyright (c) 2015 Ramotion. All rights reserved.
//

import UIKit

protocol WrapperProtocol : class {
    
    var numberOfCells: Int { get }
    
    func createCell(UICollectionView, NSIndexPath) -> UICollectionViewCell
    
    func cellAttributes(rect: CGRect) -> [UICollectionViewLayoutAttributes]
    
}

public class CollectionViewWrapper
    <
    DataType,
    CellClass: UICollectionViewCell
    where
    CellClass: ConfigurableCell,
    DataType == CellClass.DataType
>: NSObject, FlowDataDestination, WrapperProtocol {
    
    var data: [DataType] = [] {
        didSet {
            updateOffset()
        }
    }
    
    public func processData(data: [DataType]) {
        self.data = data
    }
    
    let collectionView: UICollectionView
    let cellId: String
    
    let dataSource       = CollectionViewDataSource()
    let collectionLayout = RAMCollectionViewLayout()
    let scrollDelegate: ScrollViewDelegate
    
    let rotationWrapper = NotificationCallbackWrapper(name: UIDeviceOrientationDidChangeNotification, object: UIDevice.currentDevice())
    let keyboardWrapper = NotificationCallbackWrapper(name: UIKeyboardWillChangeFrameNotification)
    
    public init(collectionView: UICollectionView, cellId: String) {
        self.collectionView = collectionView
        self.cellId         = cellId
        self.scrollDelegate = ScrollViewDelegate(itemHeight: collectionLayout.itemHeight)
        
        super.init()
        
        collectionView.registerClass(CellClass.self, forCellWithReuseIdentifier: cellId)
        
        dataSource.wrapper        = self
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = collectionLayout
        collectionView.bounces    = false
        
        let scrollView = collectionView as UIScrollView
        scrollView.delegate = scrollDelegate
        
        rotationWrapper.callback = updateOffset
        keyboardWrapper.callback = adjustScroll
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func createCell(cv: UICollectionView, _ ip: NSIndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCellWithReuseIdentifier(cellId, forIndexPath: ip) as! CellClass
        
        let row  = ip.row
        let dat  = self.data[row]
        
        cell.configureCell(dat)
        
        return cell as UICollectionViewCell
    }
    
    var numberOfCells:Int {
        return data.count
    }
    
    public func cellAttributes(rect: CGRect) -> [UICollectionViewLayoutAttributes] {
        let layout     = collectionView.collectionViewLayout
        if
            let returns    = layout.layoutAttributesForElementsInRect(rect),
            let attributes = returns as? [UICollectionViewLayoutAttributes]
        {
            return attributes
        }
    
        return []
    }
    
    // MARK: — Update & Adjust
    
    func updateOffset() {
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        
        let number = collectionView.numberOfItemsInSection(0)
        if number > 0 {
            let inset      = collectionView.contentInset.top
            let item       = CGFloat(number/2)
            let itemHeight = collectionLayout.itemHeight
            let offset     = CGPoint(x: 0, y: item * itemHeight - inset)
            
            collectionView.contentOffset = offset
            
            scrollDelegate.adjustScroll(collectionView)
        }
    }
    
    func adjustScroll() {
        scrollDelegate.adjustScroll(collectionView)
    }
    
}

class CollectionViewDataSource: NSObject, UICollectionViewDataSource {
    
    weak var wrapper: WrapperProtocol!
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let number = self.wrapper.numberOfCells
        
        return number
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = self.wrapper.createCell(collectionView, indexPath)
        
        return cell
    }
    
}

class ScrollViewDelegate: NSObject, UIScrollViewDelegate {
    
    let itemHeight: CGFloat
    init (itemHeight: CGFloat) {
        self.itemHeight = itemHeight
    
        super.init()
    }
    
    func adjustScroll(scrollView: UIScrollView) {
        let inset           = scrollView.contentInset.top
        let currentOffsetY  = scrollView.contentOffset.y + inset
        let itemIndex       = Int(round(currentOffsetY/itemHeight))
        let adjestedOffsetY = CGFloat(itemIndex) * itemHeight - inset
        
        let topBorder   : CGFloat = 0                        // Zero offset means that we really have inset size padding at top
        let bottomBorder: CGFloat = scrollView.bounds.height // Max offset is scrollView height without vertical insets
        
        UIView.animateWithDuration(0.1) {
            let newOffset = CGPoint(x: 0, y: adjestedOffsetY)
            scrollView.contentOffset = newOffset
        }
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        adjustScroll(scrollView)
    }
    
    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            adjustScroll(scrollView)
        }
    }
    
}

class NotificationCallbackWrapper: NSObject {
    
    func callItBack() {
        callback?()
    }
    
    typealias VoidToVoid = () -> ()
    var callback: VoidToVoid?
    
    init(name: String, object: AnyObject? = nil) {
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: Selector("callItBack"),
            name: name,
            object: object
        )
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
}