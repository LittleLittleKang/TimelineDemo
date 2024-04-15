//
//  ViewController.swift
//  TimelineDemo
//
//  Created by Kevin Tan on 2024/4/2.
//

import UIKit

class ViewController: UIViewController {

    var timelineView: AZTimelineView!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        view.backgroundColor = .darkGray
        
        let timelineView = AZTimelineView(frame: CGRect(x: 0, y: 200, width: self.view.frame.width, height: 100))
        self.view.addSubview(timelineView)
        
        let timeRange1 = AZTimelineView.TimeRange(start: 2, end: 4)
        let timeRange2 = AZTimelineView.TimeRange(start: 20, end: 100)
        timelineView.timeRanges = [timeRange1, timeRange2]
    }
}

// MARK: - AZTimelineView
class AZTimelineView: UIView {
    
    // 时间段颜色
    var rangeColor = UIColor.red
    
    // 视频时间段
    var timeRanges: [TimeRange]? {
        didSet {
            collectionView.reloadData()
        }
    }
    
    private var collectionView: UICollectionView!
    // 缩放
    private var zoom = 1.0
    private var zoomMin = 0.8
    private var zoomMax = 2.0
    // cell大小
    private var originalCellWidth = 50.0
    private var cellWidth: CGFloat { originalCellWidth * zoom }
    // 级别 (cell对应的时间段)
    private var level: Level = .l60
    // 当前播放点对应的标记
    private var mark: UIView!
    // 初始偏移量 (一开始mark的偏移量)
    private var originalContentOffset: Double {
        frame.width / 2.0
    }
    // 零点前后的cell数量 (用于展示前后一天的时间段)
    static let extraCellCount = 4
    // 零点前的偏移量 (UI尺寸)
    private var beforZeroContentOffset: Double {
        cellWidth * (Double(AZTimelineView.extraCellCount / 2) + 0.5)   // 前面cell数量+半cell
    }
    // 零点前的偏移量 (分钟数)
    private var beforZeroMinuteOffset: Double {
        beforZeroContentOffset / cellWidth * Double(level.rawValue)
    }
    // 当前时间点 (从00:00开始按分钟偏移量)
    private var minuteOffset: Double = 0.0
    
    
    init() {
        super.init(frame: CGRect.zero)
        self.initialize()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.initialize()
    }
    
    required init!(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.initialize()
    }
    
    deinit {
        self.collectionView.delegate = nil
        print("\(#file), \(#function)")
    }
    
    private func initialize() {
        
        self.backgroundColor = .white
        
        // 捏合手势
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        addGestureRecognizer(pinchGesture)
        
        // 双击手势
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapGesture(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapGesture)
        
        // 三击手势
        let thriceTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleThriceTapGesture(_:)))
        thriceTapGesture.numberOfTapsRequired = 3
        addGestureRecognizer(thriceTapGesture)
        
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets.zero
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0.0
        
        self.collectionView?.removeFromSuperview()
        self.collectionView = UICollectionView(frame: self.bounds, collectionViewLayout: layout)
        self.collectionView.showsHorizontalScrollIndicator = false
        self.collectionView.backgroundColor = .clear
        self.collectionView.decelerationRate = UIScrollView.DecelerationRate.fast
        self.collectionView.autoresizingMask = [UIView.AutoresizingMask.flexibleWidth, UIView.AutoresizingMask.flexibleHeight]
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.collectionView.register( AZTimelineCollectionViewCell.self, forCellWithReuseIdentifier: NSStringFromClass(AZTimelineCollectionViewCell.self))
        self.collectionView.contentInsetAdjustmentBehavior = .never
        self.addSubview(self.collectionView)
        
        // 当前点
        mark = UIView(frame: CGRectMake(originalContentOffset, 0, 1, frame.height))
        mark.backgroundColor = .blue
        addSubview(mark)
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        // 更新当前时间点
        minuteOffset = fetchMinuteOffset()
    }
    
    // 捏合手势的回调方法
    private var initialXDistance: CGFloat?
    @objc func handlePinchGesture(_ gestureRecognizer: UIPinchGestureRecognizer) {
        
        guard gestureRecognizer.numberOfTouches == 2 else {
            collectionView.isUserInteractionEnabled = true
            return
        }
        
        let point1 = gestureRecognizer.location(ofTouch: 0, in: gestureRecognizer.view)
        let point2 = gestureRecognizer.location(ofTouch: 1, in: gestureRecognizer.view)

        let currentXDistance = abs(point1.x - point2.x)

        if gestureRecognizer.state == .began {
            initialXDistance = currentXDistance
            collectionView.isUserInteractionEnabled = false
        } else if gestureRecognizer.state == .changed, let initialXDistance = initialXDistance {
            
            // 计算X方向上的缩放比例
            let scaleX = currentXDistance / initialXDistance
            
            let scale = zoom + (scaleX - 1.0) / 50.0
            
//            print(scaleX, scale)
            
            if scale < zoomMin || scale > zoomMax {
                if scale > zoomMax, level == Level.minValue {
                    return
                }else if scale < zoomMin, level == Level.maxValue {
                    return
                }
                level = scale < zoomMin ? level.forward() : level.backward()
                scaleSize(1)
            }else {
                scaleSize(scale)
            }
            
        }else {
            collectionView.isUserInteractionEnabled = true
        }
    }
    
    // 双击手势的回调方法
    @objc func handleDoubleTapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        
        guard gestureRecognizer.numberOfTapsRequired == 2 else {
            return
        }
        
        // 连跳两级
        level = level.backward()
        level = level.backward()
        scaleSize(1)
    }
    
    // 三击手势的回调方法
    @objc func handleThriceTapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        
        guard gestureRecognizer.numberOfTapsRequired == 3 else {
            return
        }
        
        // 回到初始状态
        level = .l60
        scaleSize(1)
    }
    
    private func scaleSize(_ scale: CGFloat) {
                
        self.zoom = scale
        self.collectionView.reloadData()
        // 调整offset
        scaleContentOffset()
    }
    
    private func scaleContentOffset() {
                
        let offsetY = collectionView.contentOffset.y
        let offsetX = fetchContentOffset(minuteOffset: minuteOffset)
//        print(collectionView.contentOffset.x, offsetX)
        collectionView.setContentOffset(CGPoint(x: offsetX, y: offsetY), animated: false)
    }
    
    // 获取当前时间点 (从00:00开始按分钟偏移量)
    private func fetchMinuteOffset() -> Double {
        
        // 当前时间线对应offset
        let offset = collectionView.contentOffset.x - beforZeroContentOffset + originalContentOffset
        // 当前时间线对应cell数量
        let cellCount = offset / cellWidth
        // 每个cell对应分钟数
        let minutesPerCell = Double(level.rawValue)
        
        return cellCount * minutesPerCell
    }
    
    // 获取时间点对应的 content offset
    private func fetchContentOffset(minuteOffset: Double) -> Double {
        
        // 每个cell对应分钟数
        let minutesPerCell = Double(level.rawValue)
        // 有多少个cell
        var cellCount = minuteOffset / minutesPerCell
        // 补偿零点前的长度
        cellCount += beforZeroContentOffset / cellWidth
        // 减去时间轴初始位置
        cellCount -= originalContentOffset / cellWidth
        // 容错
        cellCount = cellCount < 0 ? 0 : cellCount
        
        return cellCount * cellWidth
    }
        
    // 当前cell里包含的时间段s
    private func timeRangesInCell(row: Int) -> [TimeRange]? {
        
        // 当前cell的边界时间段
        let borderTimeRange = borderTimeRangeInCell(row: row)
        // 找出所有在originalRange内的时间段
        let timeRanges = intersectingRanges(with: borderTimeRange)
        
        return timeRanges
    }
    
    // 当前cell的边界时间段
    private func borderTimeRangeInCell(row: Int) -> TimeRange {
        
        let realRow: Double = Double(row - AZTimelineView.extraCellCount / 2) - 0.5 // (AZTimelineView.extraCellCount / 2)是前后多余的cell, 0.5是起始点在cell中间
        let start = Double(level.asMinute()) * realRow
        let end = Double(level.asMinute()) * (realRow + 1)
        // cell的边界范围
        let borderTimeRange = TimeRange(start: Double(start), end: Double(end))
        
        return borderTimeRange
    }

    // 找出所有在originalRange内的时间段
    private func intersectingRanges(with originalRange: TimeRange) -> [TimeRange]? {
        guard let ranges = timeRanges else { return nil }
        var overlappingRanges = [TimeRange]()
        
        for range in ranges {
            // 如果range在originalRange内或者与之部分重叠
            if range.start < originalRange.end && range.end > originalRange.start {
                let overlapStart = max(range.start, originalRange.start)
                let overlapEnd = min(range.end, originalRange.end)
                overlappingRanges.append(TimeRange(start: overlapStart, end: overlapEnd))
            }
        }
        return overlappingRanges.isEmpty ? nil : overlappingRanges
    }
}

extension AZTimelineView {
    
    // 时间轴等级 1分/2分/5分/10分/半小时/一小时/两小时/三小时
    enum Level: Int, CaseIterable {
        case l1 = 1
        case l2 = 2
        case l5 = 5
        case l10 = 10
        case l30 = 30
        case l60 = 60
        case l120 = 120
        case l180 = 180
        
        static var minValue: Level { .l1 }
        
        static var maxValue: Level { .l180 }
        
        func forward() -> Level {
            // 查找当前级别之后的第一个级别
            let allCases = Level.allCases.sorted { $0.rawValue < $1.rawValue }
            if let currentIndex = allCases.firstIndex(of: self), currentIndex + 1 < allCases.count {
                return allCases[currentIndex + 1]
            }
            return .l1
        }
        
        func backward() -> Level {
            // 查找当前级别之前的第一个级别
            let allCases = Level.allCases.sorted { $0.rawValue < $1.rawValue }
            if let currentIndex = allCases.firstIndex(of: self), currentIndex - 1 >= 0 {
                return allCases[currentIndex - 1]
            }
            return .l1
        }
        
        func asMinute() -> Int {
            self.rawValue
        }
        
        func getCellNumber() -> Int {
            let minuteOneDay = 60 * 24
            var cellCount = Int(ceil(Double(minuteOneDay) / Double(self.asMinute())))
            cellCount += AZTimelineView.extraCellCount
            return cellCount
        }
        
        func getTime(row: Int) -> String {
            var realRow = row - AZTimelineView.extraCellCount / 2
            let oneDayCell = getCellNumber() - AZTimelineView.extraCellCount
            realRow = realRow < 0 ? (realRow+oneDayCell) : realRow
            realRow = realRow > oneDayCell ? (realRow-oneDayCell) : realRow
            return String(format: "%02d:%02d", asMinute() * realRow / 60, asMinute() * realRow % 60)
        }
    }
    
    // 时间段 (00:00开始分钟偏移量)
    struct TimeRange {
        var start: Double
        var end: Double
    }

}

// MARK: UICollectionViewDelegateFlowLayout
extension AZTimelineView: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSizeMake(floor(cellWidth), collectionView.frame.height)
    }
}

// MARK: UICollectionViewDataSource
extension AZTimelineView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        level.getCellNumber()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NSStringFromClass(AZTimelineCollectionViewCell.self), for: indexPath) as! AZTimelineCollectionViewCell
        
        // 获取timeRanges
        let timeRanges = timeRangesInCell(row: indexPath.row)
        // 当前cell的边界时间段
        let borderTimeRange = borderTimeRangeInCell(row: indexPath.row)
        // 转换成model的ranges
        var ranges = [Range<Double>]()
        timeRanges?.forEach({ timeRange in
            let start = (timeRange.start - borderTimeRange.start) / Double(level.asMinute())
            let end = (timeRange.end - borderTimeRange.start) / Double(level.asMinute())
            let range = Range<Double>.init(uncheckedBounds: (lower: start, upper: end))
            ranges.append(range)
        })
        
        let model = AZTimelineCollectionViewCell.Model(time: level.getTime(row: indexPath.row), ranges: ranges, rangeColor: rangeColor)
        cell.bind(model)
        
        return cell
    }
}

// MARK: UICollectionViewDelegate
extension AZTimelineView: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

    }
}

extension AZTimelineView: UIScrollViewDelegate {
    
    // 已经结束滑动（仅手动拖拽时调用）
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        minuteOffset = fetchMinuteOffset()
//        print("~~~ minuteOffset: \(minuteOffset)")
    }
    
    // 已经停止减速（仅手动拖拽时调用）
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        minuteOffset = fetchMinuteOffset()
//        print("~~~ minuteOffset: \(minuteOffset)")
    }
}

// MARK: - AZTimelineCollectionViewCell
private class AZTimelineCollectionViewCell: UICollectionViewCell {
    
    var scaleNum = 5
    var marks = [UIView]()
    var timeLabel: UILabel!
    var rangeLayers = [CALayer]()

    init() {
        super.init(frame: CGRect.zero)
        self.initialize()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.initialize()
    }

    required init!(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.initialize()
    }
    
    func bind(_ model: Model) {
        
        backgroundColor = .white// UIColor(red: CGFloat.random(in: 0...1), green: CGFloat.random(in: 0...1), blue: CGFloat.random(in: 0...1), alpha: 1.0)
        timeLabel.text = model.time
        
        // 移除旧的ranges
        rangeLayers.forEach { layer in
            layer.removeFromSuperlayer()
        }
        rangeLayers.removeAll()
        
        // 添加新的ranges
        model.ranges?.forEach({ range in
            let layer = CALayer()
            layer.backgroundColor = model.rangeColor.cgColor
            layer.frame = CGRectMake(range.lowerBound * frame.width, frame.height * 3 / 4, range.upperBound * frame.width, frame.height / 4)
            self.layer.addSublayer(layer)
            rangeLayers.append(layer)
        })
        
        updateUI()
    }
    
    private func initialize() {
        
        self.backgroundColor = .clear
        
        timeLabel = UILabel(frame: CGRectMake(0, 0, frame.width, frame.height / 3))
        timeLabel.font = UIFont.systemFont(ofSize: 12)
        timeLabel.textAlignment = .center
        contentView.addSubview(timeLabel)
        
        addMark()
    }
    
    private func addMark() {

        marks.removeAll()
        for _ in 0...scaleNum {
            let mark = UIView()
            mark.backgroundColor = .black
            marks.append(mark)
            contentView.addSubview(mark)
        }
        
        updateUI()
    }
    
    private func removeMark() {
        
        marks.forEach { $0.removeFromSuperview() }
        marks.removeAll()
    }
    
    private func updateUI() {

        let spacing = frame.width / CGFloat(scaleNum)
        let firstSpacing = spacing / 2.0
        let fullHeight = frame.height / 3.0
        let halfHeight = fullHeight / 2.0
        
        timeLabel.frame = CGRectMake(0, 0, frame.width, fullHeight)
        
        guard marks.count > 0 else { return }
        for index in 0...scaleNum {
            guard index < marks.count else { return }
            let mark = marks[index]
            mark.frame = CGRectMake(index == 0 ? firstSpacing : firstSpacing + spacing * CGFloat(index),
                                    index == Int(scaleNum / 2) ? fullHeight : fullHeight + halfHeight,
                                    1,
                                    index == Int(scaleNum / 2) ? fullHeight : halfHeight)
        }
    }
}

extension AZTimelineCollectionViewCell {
    
    struct Model {
        var time: String
        var ranges: [Range<Double>]?    // 和cell宽度的比例
        var rangeColor = UIColor.red
    }
}
