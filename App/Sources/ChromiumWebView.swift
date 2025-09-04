import SwiftUI
import UIKit

struct ChromiumWebView: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    
    func makeUIView(context: Context) -> ChromiumRenderView {
        let renderView = ChromiumRenderView()
        renderView.viewModel = viewModel
        return renderView
    }
    
    func updateUIView(_ uiView: ChromiumRenderView, context: Context) {
        // Update view if needed
    }
}

class ChromiumRenderView: UIView {
    weak var viewModel: BrowserViewModel?
    private var metalLayer: CAMetalLayer?
    private var displayLink: CADisplayLink?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupMetalLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMetalLayer()
    }
    
    private func setupMetalLayer() {
        metalLayer = CAMetalLayer()
        metalLayer?.frame = bounds
        metalLayer?.pixelFormat = .bgra8Unorm
        metalLayer?.framebufferOnly = true
        
        if let metalLayer = metalLayer {
            layer.addSublayer(metalLayer)
        }
        
        // Setup display link for rendering
        displayLink = CADisplayLink(target: self, selector: #selector(render))
        displayLink?.add(to: .current, forMode: .default)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        metalLayer?.frame = bounds
    }
    
    @objc private func render() {
        // This is where the Chromium engine would render frames
        // The actual implementation would get pixel data from the engine
        // and render it to the Metal layer
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Forward touch event to Chromium engine
        ChromiumEngineBridge.shared.sendTouchEvent(
            type: .touchStart,
            x: Float(location.x),
            y: Float(location.y)
        )
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        ChromiumEngineBridge.shared.sendTouchEvent(
            type: .touchMove,
            x: Float(location.x),
            y: Float(location.y)
        )
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        ChromiumEngineBridge.shared.sendTouchEvent(
            type: .touchEnd,
            x: Float(location.x),
            y: Float(location.y)
        )
    }
    
    deinit {
        displayLink?.invalidate()
    }
}