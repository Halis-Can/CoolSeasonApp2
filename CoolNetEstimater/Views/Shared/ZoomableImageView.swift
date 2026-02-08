//
//  ZoomableImageView.swift
//  CoolNetEstimater
//

import SwiftUI

#if os(iOS)
import UIKit

struct ZoomableImageView: UIViewRepresentable {
	let image: UIImage
	let minZoomScale: CGFloat
	let maxZoomScale: CGFloat
	
	init(image: UIImage, minZoomScale: CGFloat = 1.0, maxZoomScale: CGFloat = 4.0) {
		self.image = image
		self.minZoomScale = minZoomScale
		self.maxZoomScale = maxZoomScale
	}
	
	func makeUIView(context: Context) -> UIScrollView {
		let scrollView = UIScrollView()
		scrollView.backgroundColor = .black
		scrollView.minimumZoomScale = minZoomScale
		scrollView.maximumZoomScale = maxZoomScale
		scrollView.delegate = context.coordinator
		scrollView.showsVerticalScrollIndicator = false
		scrollView.showsHorizontalScrollIndicator = false
		scrollView.bouncesZoom = true
		
		let imageView = UIImageView(image: image)
		imageView.contentMode = .scaleAspectFit
		imageView.isUserInteractionEnabled = true
		imageView.frame = scrollView.bounds
		imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		scrollView.addSubview(imageView)
		context.coordinator.imageView = imageView
		
		// Double-tap to zoom
		let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
		doubleTap.numberOfTapsRequired = 2
		scrollView.addGestureRecognizer(doubleTap)
		
		return scrollView
	}
	
	func updateUIView(_ uiView: UIScrollView, context: Context) {
		// Center content if smaller than scrollView
		centerImage(in: uiView, imageView: context.coordinator.imageView)
	}
	
	func makeCoordinator() -> Coordinator {
		Coordinator()
	}
	
	private func centerImage(in scrollView: UIScrollView, imageView: UIImageView?) {
		guard let imageView else { return }
		let scrollSize = scrollView.bounds.size
		let imageSize = imageView.frame.size
		let verticalPadding = imageSize.height < scrollSize.height ? (scrollSize.height - imageSize.height) / 2 : 0
		let horizontalPadding = imageSize.width < scrollSize.width ? (scrollSize.width - imageSize.width) / 2 : 0
		scrollView.contentInset = UIEdgeInsets(top: verticalPadding, left: horizontalPadding, bottom: verticalPadding, right: horizontalPadding)
	}
	
	final class Coordinator: NSObject, UIScrollViewDelegate {
		weak var imageView: UIImageView?
		
		func viewForZooming(in scrollView: UIScrollView) -> UIView? {
			imageView
		}
		
		func scrollViewDidZoom(_ scrollView: UIScrollView) {
			// Re-center while zooming
			if let imageView = imageView {
				let scrollSize = scrollView.bounds.size
				let imageSize = imageView.frame.size
				let vPadding = imageSize.height < scrollSize.height ? (scrollSize.height - imageSize.height) / 2 : 0
				let hPadding = imageSize.width < scrollSize.width ? (scrollSize.width - imageSize.width) / 2 : 0
				scrollView.contentInset = UIEdgeInsets(top: vPadding, left: hPadding, bottom: vPadding, right: hPadding)
			}
		}
		
		@objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
			guard let scrollView = gesture.view as? UIScrollView else { return }
			let newScale: CGFloat = (abs(scrollView.zoomScale - scrollView.minimumZoomScale) < 0.01) ? min(scrollView.maximumZoomScale, 2.0) : scrollView.minimumZoomScale
			let pointInView = gesture.location(in: imageView)
			
			// Zoom to a rect centered at tap point
			let scrollSize = scrollView.bounds.size
			let width = scrollSize.width / newScale
			let height = scrollSize.height / newScale
			let zoomRect = CGRect(x: pointInView.x - (width / 2), y: pointInView.y - (height / 2), width: width, height: height)
			scrollView.zoom(to: zoomRect, animated: true)
		}
	}
}

#elseif os(macOS)
import AppKit

struct ZoomableImageView_macOS: NSViewRepresentable {
	let image: NSImage
	let minZoomScale: CGFloat
	let maxZoomScale: CGFloat
	
	init(image: NSImage, minZoomScale: CGFloat = 1.0, maxZoomScale: CGFloat = 4.0) {
		self.image = image
		self.minZoomScale = minZoomScale
		self.maxZoomScale = maxZoomScale
	}
	
	func makeNSView(context: Context) -> NSScrollView {
		let scrollView = NSScrollView()
		scrollView.backgroundColor = .black
		scrollView.hasVerticalScroller = true
		scrollView.hasHorizontalScroller = true
		scrollView.autohidesScrollers = true
		scrollView.borderType = .noBorder
		scrollView.wantsLayer = true
		scrollView.layer?.backgroundColor = NSColor.black.cgColor
		
		let imageView = NSImageView()
		imageView.image = image
		imageView.imageScaling = .scaleProportionallyUpOrDown
		imageView.imageAlignment = .alignCenter
		
		scrollView.documentView = imageView
		context.coordinator.imageView = imageView
		context.coordinator.scrollView = scrollView
		
		// Set initial zoom
		scrollView.magnification = minZoomScale
		
		// Double-click to zoom
		let doubleClick = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleClick(_:)))
		doubleClick.numberOfClicksRequired = 2
		scrollView.addGestureRecognizer(doubleClick)
		
		return scrollView
	}
	
	func updateNSView(_ nsView: NSScrollView, context: Context) {
		// Update if needed
	}
	
	func makeCoordinator() -> Coordinator {
		Coordinator(minZoom: minZoomScale, maxZoom: maxZoomScale)
	}
	
	final class Coordinator: NSObject {
		weak var imageView: NSImageView?
		weak var scrollView: NSScrollView?
		let minZoom: CGFloat
		let maxZoom: CGFloat
		var isZoomed: Bool = false
		
		init(minZoom: CGFloat, maxZoom: CGFloat) {
			self.minZoom = minZoom
			self.maxZoom = maxZoom
		}
		
		@objc func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
			guard let scrollView = scrollView else { return }
			let newMagnification: CGFloat = isZoomed ? minZoom : min(maxZoom, 2.0)
			scrollView.animator().magnification = newMagnification
			isZoomed = !isZoomed
		}
	}
}
#endif



