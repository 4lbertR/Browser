import SwiftUI
import UIKit

// Custom web view using our rendering engine
public class CustomWebViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let renderingEngine = RenderingEngine()
    private var currentURL: URL?
    
    public var onNavigate: ((String) -> Void)?
    public var onLoadingStateChanged: ((Bool) -> Void)?
    public var onTitleChanged: ((String) -> Void)?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupNotifications()
    }
    
    private func setupViews() {
        view.backgroundColor = .white
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Setup content view
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLinkTapped(_:)),
            name: NSNotification.Name("LinkTapped"),
            object: nil
        )
    }
    
    @objc private func handleLinkTapped(_ notification: Notification) {
        if let href = notification.userInfo?["href"] as? String {
            if let currentURL = currentURL {
                // Resolve relative URLs
                if let url = URL(string: href, relativeTo: currentURL) {
                    loadURL(url)
                }
            } else if let url = URL(string: href) {
                loadURL(url)
            }
        }
    }
    
    public func loadURL(_ url: URL) {
        currentURL = url
        onLoadingStateChanged?(true)
        
        // Create URL request without using WebKit
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let session = URLSession(configuration: .default)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.onLoadingStateChanged?(false)
                
                if let error = error {
                    self?.displayError(error.localizedDescription)
                    return
                }
                
                guard let data = data,
                      let html = String(data: data, encoding: .utf8) else {
                    self?.displayError("Failed to load page")
                    return
                }
                
                // Extract CSS if present
                let css = self?.extractCSS(from: html) ?? ""
                
                // Extract title
                if let title = self?.extractTitle(from: html) {
                    self?.onTitleChanged?(title)
                }
                
                // Render the HTML
                self?.renderHTML(html, css: css)
            }
        }
        
        task.resume()
    }
    
    private func renderHTML(_ html: String, css: String) {
        // Clear previous content
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Load and render HTML
        renderingEngine.loadHTML(html, css: css)
        renderingEngine.render(in: contentView)
        
        // Update content size for scrolling
        contentView.layoutIfNeeded()
        
        var maxY: CGFloat = 0
        for subview in contentView.subviews {
            maxY = max(maxY, subview.frame.maxY)
        }
        
        contentView.heightAnchor.constraint(equalToConstant: maxY + 20).isActive = true
        scrollView.contentSize = CGSize(width: view.bounds.width, height: maxY + 20)
    }
    
    private func extractTitle(from html: String) -> String? {
        if let titleRange = html.range(of: "<title>", options: .caseInsensitive),
           let titleEndRange = html.range(of: "</title>", options: .caseInsensitive, range: titleRange.upperBound..<html.endIndex) {
            let title = String(html[titleRange.upperBound..<titleEndRange.lowerBound])
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func extractCSS(from html: String) -> String {
        var css = ""
        
        // Extract from <style> tags
        var searchRange = html.startIndex..<html.endIndex
        while let styleRange = html.range(of: "<style", options: .caseInsensitive, range: searchRange) {
            if let styleEndRange = html.range(of: "</style>", options: .caseInsensitive, range: styleRange.upperBound..<html.endIndex) {
                let styleContent = String(html[styleRange.upperBound..<styleEndRange.lowerBound])
                if let contentStart = styleContent.firstIndex(of: ">") {
                    css += String(styleContent[styleContent.index(after: contentStart)...])
                    css += "\n"
                }
                searchRange = styleEndRange.upperBound..<html.endIndex
            } else {
                break
            }
        }
        
        return css
    }
    
    private func displayError(_ message: String) {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let errorLabel = UILabel()
        errorLabel.text = "Error: \(message)"
        errorLabel.textColor = .red
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(errorLabel)
        
        NSLayoutConstraint.activate([
            errorLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            errorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }
    
    public func goBack() {
        // TODO: Implement history navigation
    }
    
    public func goForward() {
        // TODO: Implement history navigation
    }
    
    public func reload() {
        if let url = currentURL {
            loadURL(url)
        }
    }
}

// SwiftUI wrapper for the custom web view
public struct CustomWebView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    
    public func makeUIViewController(context: Context) -> CustomWebViewController {
        let controller = CustomWebViewController()
        
        controller.onNavigate = { url in
            viewModel.navigate(to: url)
        }
        
        controller.onLoadingStateChanged = { isLoading in
            viewModel.isLoading = isLoading
            viewModel.loadingProgress = isLoading ? 0.5 : 1.0
        }
        
        controller.onTitleChanged = { title in
            viewModel.pageTitle = title
        }
        
        return controller
    }
    
    public func updateUIViewController(_ controller: CustomWebViewController, context: Context) {
        if let url = URL(string: viewModel.currentURL), 
           !viewModel.currentURL.isEmpty {
            controller.loadURL(url)
        }
    }
}