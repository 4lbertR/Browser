import SwiftUI
import UIKit

// Interactive Browser Renderer with Click Support
class InteractiveRenderer: UIView {
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var websocket: URLSessionWebSocketTask?
    private var currentURL: URL?
    private var pageScale: CGFloat = 1.0
    
    // Free interactive rendering service
    // Option 1: Use Browserless.io (free tier available)
    private let browserlessURL = "wss://chrome.browserless.io/"
    
    // Option 2: Deploy your own server (included in repo)
    private let customServerURL = "ws://localhost:8080"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .white
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 3.0
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        
        addSubview(scrollView)
        scrollView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ])
        
        // Add tap gesture for clicks
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        imageView.addGestureRecognizer(tapGesture)
        
        // Add long press for right-click
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        imageView.addGestureRecognizer(longPressGesture)
        
        // Add pan gesture for scrolling
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        imageView.addGestureRecognizer(panGesture)
    }
    
    func loadURL(_ url: URL) {
        currentURL = url
        
        // For now, use clickable overlay approach
        // This creates clickable regions over the screenshot
        loadWithClickableOverlay(url: url)
    }
    
    private func loadWithClickableOverlay(url: URL) {
        // First, get the screenshot
        let screenshotURL = "https://api.apiflash.com/v1/urltoimage?access_key=a4949a0cd7334343b994e736dbe06544&url=\(url.absoluteString)&format=png&width=390&height=844&fresh=true&full_page=false&wait_until=page_loaded"
        
        guard let requestURL = URL(string: screenshotURL) else { return }
        
        URLSession.shared.dataTask(with: requestURL) { [weak self] data, _, _ in
            guard let data = data,
                  let image = UIImage(data: data) else { return }
            
            DispatchQueue.main.async {
                self?.displayImage(image)
                self?.extractClickableElements(from: url)
            }
        }.resume()
    }
    
    private func extractClickableElements(from url: URL) {
        // Get page structure to identify clickable elements
        let structureURL = "https://api.apiflash.com/v1/urltoimage?access_key=a4949a0cd7334343b994e736dbe06544&url=\(url.absoluteString)&format=json&response_type=json&extract_html=true"
        
        // This would return HTML that we can parse for links
        // For now, add common click regions
        addCommonClickRegions(for: url)
    }
    
    private func addCommonClickRegions(for url: URL) {
        // Remove old buttons
        imageView.subviews.forEach { $0.removeFromSuperview() }
        
        // Add invisible buttons over common areas
        if url.host?.contains("google") == true {
            // Add search box button
            addClickRegion(x: 0.1, y: 0.3, width: 0.8, height: 0.08, action: "search")
            
            // Add search button
            addClickRegion(x: 0.35, y: 0.4, width: 0.15, height: 0.06, action: "google_search")
            addClickRegion(x: 0.5, y: 0.4, width: 0.15, height: 0.06, action: "lucky")
        }
        
        // Add common navigation regions
        addClickRegion(x: 0, y: 0, width: 0.15, height: 0.1, action: "back")
        addClickRegion(x: 0.85, y: 0, width: 0.15, height: 0.1, action: "menu")
    }
    
    private func addClickRegion(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, action: String) {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear // Invisible
        button.accessibilityIdentifier = action
        button.addTarget(self, action: #selector(regionTapped(_:)), for: .touchUpInside)
        
        // Position relative to image size
        button.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: imageView.bounds.width * x),
            button.topAnchor.constraint(equalTo: imageView.topAnchor, constant: imageView.bounds.height * y),
            button.widthAnchor.constraint(equalToConstant: imageView.bounds.width * width),
            button.heightAnchor.constraint(equalToConstant: imageView.bounds.height * height)
        ])
        
        // Debug: Show button regions (remove in production)
        #if DEBUG
        button.layer.borderColor = UIColor.red.withAlphaComponent(0.3).cgColor
        button.layer.borderWidth = 1
        #endif
    }
    
    @objc private func regionTapped(_ sender: UIButton) {
        guard let action = sender.accessibilityIdentifier else { return }
        
        switch action {
        case "search":
            showSearchInput()
        case "google_search":
            performSearch()
        case "back":
            goBack()
        default:
            print("Action: \(action)")
        }
    }
    
    private func showSearchInput() {
        // Show keyboard for search input
        let alert = UIAlertController(title: "Search", message: "Enter search query", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Search Google"
        }
        alert.addAction(UIAlertAction(title: "Search", style: .default) { [weak self] _ in
            if let query = alert.textFields?.first?.text {
                let searchURL = URL(string: "https://google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
                self?.loadURL(searchURL)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let window = window,
           let rootVC = window.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    private func performSearch() {
        // Trigger search with current input
        print("Performing search")
    }
    
    private func goBack() {
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateBack"),
            object: nil
        )
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: imageView)
        
        // Calculate relative position (0-1)
        let relativeX = location.x / imageView.bounds.width
        let relativeY = location.y / imageView.bounds.height
        
        print("Tap at: \(relativeX), \(relativeY)")
        
        // Send click to server or handle locally
        handleClick(x: relativeX, y: relativeY)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let location = gesture.location(in: imageView)
        print("Long press at: \(location)")
        
        // Show context menu
        showContextMenu(at: location)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        // Handle page scrolling
        let translation = gesture.translation(in: imageView)
        
        if gesture.state == .changed {
            // Scroll the webpage
            scrollPage(deltaY: translation.y)
            gesture.setTranslation(.zero, in: imageView)
        }
    }
    
    private func handleClick(x: CGFloat, y: CGFloat) {
        // Calculate actual pixel coordinates
        let pixelX = Int(x * 390 * UIScreen.main.scale)
        let pixelY = Int(y * 844 * UIScreen.main.scale)
        
        print("Click at pixels: \(pixelX), \(pixelY)")
        
        // For now, check if click is in a known region
        // In production, send to server for processing
        
        // Google search box region
        if x > 0.1 && x < 0.9 && y > 0.25 && y < 0.35 {
            showSearchInput()
        }
    }
    
    private func scrollPage(deltaY: CGFloat) {
        // Handle scrolling
        print("Scroll: \(deltaY)")
    }
    
    private func showContextMenu(at location: CGPoint) {
        // Show right-click menu
        let menu = UIMenuController.shared
        menu.menuItems = [
            UIMenuItem(title: "Open in New Tab", action: #selector(openInNewTab)),
            UIMenuItem(title: "Copy Link", action: #selector(copyLink))
        ]
        menu.showMenu(from: self, rect: CGRect(origin: location, size: .zero))
    }
    
    @objc private func openInNewTab() {
        print("Open in new tab")
    }
    
    @objc private func copyLink() {
        print("Copy link")
    }
    
    private func displayImage(_ image: UIImage) {
        imageView.image = image
        
        // Update constraints for image size
        let imageSize = image.size
        let scale = bounds.width / imageSize.width
        let scaledHeight = imageSize.height * scale
        
        imageView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: scaledHeight)
        scrollView.contentSize = CGSize(width: bounds.width, height: scaledHeight)
        
        // Update click regions after image loads
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.addCommonClickRegions(for: self?.currentURL ?? URL(string: "https://google.com")!)
        }
    }
}

extension InteractiveRenderer: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

extension InteractiveRenderer: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}