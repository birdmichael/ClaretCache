//
//  AsyncLayer.swift
//  ClaretCacheDemo
//
//  Created by BirdMichael on 2019/7/30.
//  Copyright © 2019 com.ClaretCache. All rights reserved.
//

#if canImport(UIKit)
import UIKit.UIApplication
#endif

///  The AsyncLayer class is a subclass of CALayer used for render contents asynchronously.
///
///   When the layer need update it's contents, it will ask the delegate
///   for a async display task to render the contents in a background queue.
class AsyncLayer: CALayer {

    /// Whether the render code is executed in background. **Default is true**.
    var displaysAsynchronously = true

    private var sentinel: Sentinel!
    private var scale: CGFloat = 0.0
    private let releaseQueue = DispatchQueue.global(qos: .utility)

    // TODO: 渲染队列
    private let displayQueue: DispatchQueue = {

        return DispatchQueue(label: "dasd")
    }()

    // MARK: Override
    override class func defaultValue(forKey key: String) -> Any? {
        guard key == "displaysAsynchronously" else {
            return true
        }

        return super.defaultValue(forKey: key)
    }

    override init() {
        super.init()
        DispatchQueue.once(token: UUID().uuidString) {
            scale = UIScreen.main.scale
        }
        contentsScale = scale
        sentinel = Sentinel()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    deinit {
        sentinel.increase()
    }

    override func setNeedsLayout() {
        cancelAsyncDisplay()
        super.setNeedsLayout()
    }

    override func display() {
        super.contents = super.contents
        display(displaysAsynchronously)
    }
}

// MARK: Private
extension AsyncLayer {
    final func display(_ async: Bool) {
        guard let delegate = self.delegate as? AsyncLayerDelegate  else { return }

        let task = delegate.newAsyncDisplayTask

        guard task.display != nil else {
            task.willDisplay?(self)
            contents = nil
            task.didDisplay?(self, true)
            return
        }

        if async {
            task.willDisplay?(self)
            let value = sentinel!.value
            let isCancelled = {
                return value != self.sentinel!.value
            }
            let size = bounds.size
            let opaque = isOpaque
            let scale = contentsScale
            var backgroundColor = (opaque && (self.backgroundColor != nil)) ? self.backgroundColor : nil

            if size.width < 1 || size.height < 1 {
                var image = contents
                contents = nil
                if (image != nil) {
                    releaseQueue.async {
                        image = nil
                    }
                    task.didDisplay?(self, true)
                    backgroundColor = nil
                    return
                }
            }

            displayQueue.async {
                 guard !isCancelled() else { return }

                UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
                guard let context = UIGraphicsGetCurrentContext() else { return }

                context.textMatrix = CGAffineTransform.identity
                context.translateBy(x: 0, y: self.bounds.height)
                context.scaleBy(x: 1, y: -1)

                if opaque {
                    context.saveGState()
                    if backgroundColor == nil || backgroundColor!.alpha < 1 {
                        context.setFillColor(UIColor.white.cgColor)
                        context.addRect(CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale))
                        context.fillPath()
                    }

                    if let backgroundColor = backgroundColor {
                        context.setFillColor(backgroundColor)
                        context.addRect(CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale))
                        context.fillPath()
                    }

                    context.restoreGState()
                    backgroundColor = nil
                }

                task.display?(context, size, isCancelled)

                if isCancelled() {
                    UIGraphicsEndImageContext()
                    DispatchQueue.main.async {
                        task.didDisplay?(self, false)
                    }
                    return
                }

                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()

                if isCancelled() {
                    UIGraphicsEndImageContext()
                    DispatchQueue.main.async {
                        task.didDisplay?(self, false)
                    }
                    return
                }

                DispatchQueue.main.async {
                    if isCancelled() {
                        task.didDisplay?(self, false)
                    } else {
                        self.contents = image?.cgImage
                        task.didDisplay?(self, true)
                    }
                }
            }
        } else {
            sentinel.increase()
            task.willDisplay?(self)
            guard let context = UIGraphicsGetCurrentContext() else { return }
            if isOpaque {
                var size = bounds.size
                size.width *= contentsScale
                size.height *= contentsScale
                context.saveGState()

                if backgroundColor == nil || backgroundColor!.alpha < 1 {
                    context.setFillColor(UIColor.white.cgColor)
                    context.addRect(CGRect(origin: .zero, size: size))
                    context.fillPath()
                }
                if let backgroundColor = backgroundColor {
                    context.setFillColor(backgroundColor)
                    context.addRect(CGRect(origin: .zero, size: size))
                    context.fillPath()
                }
                context.restoreGState()
            }

            task.display?(context, bounds.size, {return false })
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            contents = image?.cgImage
            task.didDisplay?(self, true)

        }

    }

    final func cancelAsyncDisplay() {
        sentinel.increase()
    }

}

// MARK: - Delegate

/// The AsyncLayer's delegate protocol
///
///  The delegate of the YYAsyncLayer (typically a UIView)
///  must implements the method in this protocol.
protocol AsyncLayerDelegate: class {

    /// This method is called to return a new display task when the layer's contents need update.
    var newAsyncDisplayTask:  AsyncLayerDisplayTask { get }
}

// MARK: - DisplayTask

/// A display task used by AsyncLayer to render the contents in background queue.
class AsyncLayerDisplayTask {

    /// his block will be called before the asynchronous drawing begins.
    ///
    ///  It will be called on the **main thread**.
    /// - Parameter layer: The layer
    public var willDisplay: ((_ layer:CALayer) -> Void)?

    /// This block is called to draw the layer's contents.
    ///
    ///  This block may be called on main thread or background thread, so is should be **thread-safe**.
    /// - Parameter context: A new bitmap content created by layer.
    /// - Parameter size: The content size (typically same as layer's bound size).
    /// - Parameter isCancelled: If this block returns `YES`, the method should cancel the
    /// drawing process and return as quickly as possible.
    public var display: ((_ context: CGContext, _ size: CGSize, _ isCancelled: (() -> Bool)?) -> Void)?

    /// This block will be called after the asynchronous drawing finished.
    /// It will be called on the main thread.
    ///
    /// - Parameter layer: The layer.
    /// - Parameter finished: If the draw process is cancelled, it's `NO`, otherwise it's `YES`.
    public var didDisplay: ((_ layer: CALayer, _ finished: Bool) -> Void)?
}
