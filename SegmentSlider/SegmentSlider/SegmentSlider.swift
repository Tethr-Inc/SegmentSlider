//
//  SegmentSlider.swift
//  Tethr
//
//  Created by Ian MacCallum on 7/8/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation
import UIKit

extension CGFloat {
	func half() -> CGFloat {
		return self / 2
	}
	
	func toDiameter() -> CGFloat {
		return self * 2
	}
}

extension UIColor {
	class func trackColor() -> UIColor {
		return UIColor(red: 183 / 255, green: 183 / 255, blue: 183 / 255, alpha: 1)
	}
}

@objc public protocol SliderDelegate: class {
	func segmentSlider(_ segmentSlider: SegmentSlider, segmentDidChangeToIndex index: Int)
	@objc optional func numberOfPointsOnSlider(_ segmentSlider: SegmentSlider) -> Int
}

open class SegmentSlider: UIView {
	public weak var delegate: SliderDelegate?
	
	// Data Source
	@IBInspectable public var numberOfPoints: Int = 5 {
		didSet {
			update()
		}
	}
	
	fileprivate var _count: Int {
		return delegate?.numberOfPointsOnSlider?(self) ?? numberOfPoints
	}
	public var currentIndex = 0 {
		didSet {
			if currentIndex != oldValue {
				delegate?.segmentSlider(self, segmentDidChangeToIndex: currentIndex)
			}
		}
	}

	public var minimumTrackTintColor: UIColor? {
		didSet {
			trackingLayer.backgroundColor = minimumTrackTintColor?.cgColor
		}
	}
	public var maximumTrackTintColor: UIColor? {
		didSet {
			backgroundLayer.backgroundColor = maximumTrackTintColor?.cgColor
		}
	}
	
	public var trackHeight: CGFloat = 2 {
		didSet {
			update()
		}
	}
	
	public var thumbRadius: CGFloat = 14 {
		didSet {
			update()
		}
	}
	
	public var circleRadius: CGFloat = 4 {
		didSet {
			update()
		}
	}
	
	fileprivate let backgroundLayer = CALayer()
	fileprivate let maskLayer = CAShapeLayer()
	fileprivate let trackingLayer = CALayer()
	fileprivate let thumbView = UIView()

	

	fileprivate var startPoint: CGPoint?
	
	override open func awakeFromNib() {
		super.awakeFromNib()
		
		configure()
		update()

		let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
		thumbView.addGestureRecognizer(panGesture)
		
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
		addGestureRecognizer(tapGesture)
	}
	
	@objc private func handlePan(_ sender: UIPanGestureRecognizer) {
		let translation = sender.translation(in: self)

		let minCenter = centerForIndex(0).x
		let maxCenter = centerForIndex((_count - 1)).x
		let center = min(max(minCenter, (startPoint?.x ?? 0) + translation.x), maxCenter)

		switch sender.state {
		case .began:
			
			startPoint = thumbView.center
		
		case .changed:
			
			updatePosition(center, animated: false)
			currentIndex = nearestIndexToPoint(center)
		default:
			let index = nearestIndexToPoint(center)
			let newCenter = centerForIndex(index).x

			updatePosition(newCenter, animated: true)
			startPoint = nil
		}
	}
	
	@objc private func handleTap(_ sender: UITapGestureRecognizer) {
		let point = sender.location(in: self)
		let index = nearestIndexToPoint(point.x)
		let center = centerForIndex(index).x
		
		updatePosition(center, animated: true) {
			self.currentIndex = index
		}
	}
	
	private func updatePosition(_ center: CGFloat, animated: Bool, completion: (() -> ())? = nil) {

		var animations: (() -> ())?
		
		animations = {
			self.thumbView.center.x = center
			self.trackingLayer.frame.size.width = center
		}
		
		if animated {
			UIView.animate(withDuration: 0.25, animations: {
				animations?()
			}, completion: { finished in
				completion?()
			})
			
		} else {
			CATransaction.begin()
			CATransaction.setDisableActions(true)
			animations?()
			CATransaction.commit()
			completion?()
		}
	}

	override open func layoutSubviews() {
		super.layoutSubviews()
		update()
	}
	
	override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
		let frame = thumbView.frame.insetBy(dx: -40, dy: -20)
		return frame.contains(point) ? thumbView : self
	}
}



// MARK: - Configuration
extension SegmentSlider {
	// Background
	fileprivate func configure() {
		
		clipsToBounds = false
		layer.masksToBounds = false
		
		backgroundColor = .clear

		// Background
		backgroundLayer.backgroundColor = maximumTrackTintColor?.cgColor ?? UIColor.trackColor().cgColor
		backgroundLayer.masksToBounds = false
		layer.addSublayer(backgroundLayer)
		
		// Track
		trackingLayer.backgroundColor = minimumTrackTintColor?.cgColor ?? tintColor.cgColor
		backgroundLayer.addSublayer(trackingLayer)

		// Mask
		backgroundLayer.mask = maskLayer
		
		// Thumb
		thumbView.backgroundColor = .white
		thumbView.clipsToBounds = false
		thumbView.layer.masksToBounds = false
		
		thumbView.layer.shadowColor = UIColor.black.cgColor
		thumbView.layer.shadowOffset = CGSize(width: 0, height: 1.5)
		thumbView.layer.shadowOpacity = 0.35
		thumbView.layer.shadowRadius = 2
		
		addSubview(thumbView)
	}
}


// MARK: - Updates
extension SegmentSlider {
	
	fileprivate func update() {
		
		// Thumb
		let minCenter = centerForIndex(0)
		let maxCenter = centerForIndex((_count - 1))
		let centerX = minCenter.x + (maxCenter.x - minCenter.x) * percentForIndex(currentIndex)
		
		thumbView.center = CGPoint(x: centerX, y: frame.height.half())
		thumbView.frame.size = CGSize(width: thumbRadius.toDiameter(), height: thumbRadius.toDiameter())


		thumbView.layer.cornerRadius = min(thumbView.frame.width, thumbView.frame.height) / 2
		
		// Background
		backgroundLayer.frame = bounds
		
		// Mask
		maskLayer.frame = bounds
		maskLayer.path = backgroundPath().cgPath
		
		// Track
		trackingLayer.frame = CGRect(x: 0, y: 0, width: thumbView.center.x, height: frame.height)
	}
}


// MARK: - Helpers
extension SegmentSlider {
	
	fileprivate func percentForIndex(_ index: Int) -> CGFloat {
		return CGFloat(index) / CGFloat((_count - 1))
	}
	
	fileprivate func nearestIndexToPoint(_ point: CGFloat) -> Int {
		
		let percent = point / frame.width
		let value = percent * CGFloat((_count - 1))
		let index = Int(round(value))

		return max(min(index, (_count - 1)), 0)
	}
	
	
	fileprivate func centerForIndex(_ index: Int) -> CGPoint {
		let w = frame.width - 2 * circleRadius
		let x = circleRadius + CGFloat(index) * w / CGFloat((_count - 1))
		let y = frame.height / 2
		
		if _count <= 0 {
			return CGPoint.zero
		} else if _count == 1 {
			return CGPoint(x: frame.width / 2, y: y)
		} else {
			return CGPoint(x: x, y: y)
		}
	}

	fileprivate func backgroundPath() -> UIBezierPath {
		let count = _count
		
		func point(_ i: Int) -> Int {
			return i >= count ? (count - 2) - (i - count) : i
		}
		
		let path = UIBezierPath()
		
		let iterations = 2 * (count - 1)
		
		for i in 0..<iterations {
			
			let p = point(i)
			let center = centerForIndex(p)
			let nextP = point((i + 1))
			let nextCenter = centerForIndex(nextP)
			let radius = circleRadius
			let angle = trackHeight / 2 / radius
			let a = sqrt(pow(radius, 2) - pow(trackHeight / 2, 2))
			
			if i == 0 {
				
				path.addArc(withCenter: center, radius: radius, startAngle: angle, endAngle: -angle, clockwise: true)
				path.addLine(to: CGPoint(x: nextCenter.x - a, y: nextCenter.y - trackHeight / 2))
				
			} else if i == (count - 1) {
				
				path.addArc(withCenter: center, radius: radius, startAngle: CGFloat(M_PI) + angle, endAngle: CGFloat(M_PI) - angle, clockwise: true)
				path.addLine(to: CGPoint(x: nextCenter.x + a, y: nextCenter.y + trackHeight / 2))
				
			} else if i < (count - 1) {
				
				path.addArc(withCenter: center, radius: radius, startAngle: CGFloat(M_PI) + angle, endAngle: -angle, clockwise: true)
				path.addLine(to: CGPoint(x: nextCenter.x - a, y: nextCenter.y - trackHeight / 2))
				
			} else if i >= count {
				
				path.addArc(withCenter: center, radius: radius, startAngle: angle, endAngle: CGFloat(M_PI) - angle, clockwise: true)
				path.addLine(to: CGPoint(x: nextCenter.x + a, y: nextCenter.y + trackHeight / 2))
			}
		}
		
		path.close()
		return path
	}
}
