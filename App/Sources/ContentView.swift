import SwiftUI
import UIKit
import JavaScriptCore

// Browser Configuration
struct BrowserConfig {
    // STEP 1: Get your FREE API key from: https://apiflash.com
    // STEP 2: Replace YOUR_API_KEY_HERE with your actual key
    static let apiflashKey = "YOUR_API_KEY_HERE"
    
    static var isConfigured: Bool {
        return apiflashKey != "YOUR_API_KEY_HERE"
    }
    
    static func getScreenshotURL(for url: URL) -> String? {
        if !isConfigured {
            return nil
        }
        return "https://api.apiflash.com/v1/urltoimage?access_key=\(apiflashKey)&url=\(url.absoluteString)&format=png&width=390&height=844&fresh=true&full_page=false&wait_until=page_loaded"
    }
}

// Remote Renderer - Uses real Chrome on server
class RemoteRenderer: UIView {
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var currentURL: URL?
    
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
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        
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
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    func loadURL(_ url: URL) {
        currentURL = url
        
        // Check if API is configured
        if !BrowserConfig.isConfigured {
            displayPlaceholder(for: url)
            return
        }
        
        // Get screenshot URL from config
        guard let screenshotURL = BrowserConfig.getScreenshotURL(for: url) else {
            displayPlaceholder(for: url)
            return
        }
        
        // For WebSocket connections, handle differently
        if screenshotURL.starts(with: "wss://") || screenshotURL.starts(with: "ws://") {
            // Would connect to WebSocket server here
            displayPlaceholder(for: url)
            return
        }
        
        // Fetch screenshot from API
        fetchScreenshot(from: screenshotURL)
    }
    
    private func fetchScreenshot(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data,
                  let image = UIImage(data: data) else { 
                DispatchQueue.main.async {
                    self?.displayPlaceholder(for: self?.currentURL)
                }
                return 
            }
            
            DispatchQueue.main.async {
                self?.imageView.image = image
                self?.updateScrollViewContentSize()
            }
        }.resume()
    }
    
    private func displayPlaceholder(for url: URL?) {
        // Clear previous subviews
        scrollView.subviews.forEach { $0.removeFromSuperview() }
        imageView.image = nil
        
        // Create a placeholder view with instructions
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16)
        
        label.text = """
        ⚠️ API Key Not Configured
        
        To render websites, please:
        
        1. Go to: apiflash.com
        2. Sign up FREE (takes 30 seconds)
        3. Get your API key
        4. Open Config.swift
        5. Replace YOUR_API_KEY_HERE with your key
        6. Rebuild the app
        
        Free tier includes:
        • 100 screenshots/month
        • Full JavaScript rendering
        • Perfect CSS support
        
        Current URL: \(url?.host ?? "none")
        """
        
        label.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20)
        ])
    }
    
    private func updateScrollViewContentSize() {
        guard let image = imageView.image else { return }
        let imageSize = image.size
        let scale = bounds.width / imageSize.width
        let scaledHeight = imageSize.height * scale
        
        imageView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: scaledHeight)
        scrollView.contentSize = CGSize(width: bounds.width, height: scaledHeight)
    }
}

// Using NSAttributedString HTML renderer - NOT WebKit based
class EnhancedWebRenderer: UIView, UITextViewDelegate {
    private let scrollView = UIScrollView()
    private var contentView = UIView()
    private var jsContext: JSContext?
    private var cssStyles: [String: [String: String]] = [:]
    private var documentElements: [DOMElement] = []
    private var currentURL: URL?
    
    class DOMElement {
        var tagName: String
        var attributes: [String: String] = [:]
        var children: [DOMElement] = []
        var textContent: String = ""
        var computedStyle: [String: String] = [:]
        var view: UIView?
        
        init(tagName: String) {
            self.tagName = tagName.lowercased()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupJavaScriptContext()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupJavaScriptContext()
    }
    
    private func setupView() {
        backgroundColor = .white
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func setupJavaScriptContext() {
        jsContext = JSContext()
        
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("[JS Console]:", message)
        }
        jsContext?.setObject(consoleLog, forKeyedSubscript: "consoleLog" as NSString)
        jsContext?.evaluateScript("var console = { log: function(msg) { consoleLog(String(msg)); } };")
        
        setupDocumentAPI()
        setupWindowAPI()
    }
    
    private func setupDocumentAPI() {
        let getElementById: @convention(block) (String) -> JSValue? = { [weak self] id in
            return nil
        }
        
        let document = JSValue(newObjectIn: jsContext)
        document?.setObject(getElementById, forKeyedSubscript: "getElementById" as NSString)
        jsContext?.setObject(document, forKeyedSubscript: "document" as NSString)
    }
    
    private func setupWindowAPI() {
        let alert: @convention(block) (String) -> Void = { message in
            print("[JS Alert]:", message)
        }
        
        let window = JSValue(newObjectIn: jsContext)
        window?.setObject(alert, forKeyedSubscript: "alert" as NSString)
        jsContext?.setObject(window, forKeyedSubscript: "window" as NSString)
    }
    
    func loadURL(_ url: URL) {
        currentURL = url
        
        // Clear previous content
        contentView.subviews.forEach { $0.removeFromSuperview() }
        documentElements.removeAll()
        cssStyles.removeAll()
        
        // Fetch the HTML
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                return
            }
            
            DispatchQueue.main.async {
                // Use NSAttributedString HTML rendering (NOT WebKit)
                self.renderWithNSAttributedString(html)
            }
        }.resume()
    }
    
    private func renderWithNSAttributedString(_ html: String) {
        // Clean the HTML first
        var cleanHTML = html
        
        // Remove scripts since they won't execute
        cleanHTML = cleanHTML.replacingOccurrences(
            of: "<script[^>]*>.*?</script>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Add viewport for mobile
        if !cleanHTML.contains("viewport") {
            cleanHTML = cleanHTML.replacingOccurrences(
                of: "<head>",
                with: "<head><meta name='viewport' content='width=device-width, initial-scale=1.0'>",
                options: .caseInsensitive
            )
        }
        
        // Create NSAttributedString from HTML
        guard let data = cleanHTML.data(using: .utf8) else { return }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        // Process in background to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let attributedString = try? NSAttributedString(
                data: data,
                options: options,
                documentAttributes: nil
            ) {
                DispatchQueue.main.async {
                    self?.displayAttributedContent(attributedString)
                }
            } else {
                // Fallback to basic rendering
                DispatchQueue.main.async {
                    self?.renderBasicHTML(html)
                }
            }
        }
    }
    
    private func displayAttributedContent(_ attributedString: NSAttributedString) {
        // Clear existing content
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Create a UITextView to display the attributed string
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false // We use our own scroll view
        textView.attributedText = attributedString
        textView.backgroundColor = .white
        textView.dataDetectorTypes = [.link, .phoneNumber]
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        
        // Handle link taps
        textView.isUserInteractionEnabled = true
        textView.delegate = self
        
        // Add to content view
        textView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
        
        // Update content size
        let size = textView.sizeThatFits(CGSize(width: bounds.width - 20, height: CGFloat.greatestFiniteMagnitude))
        contentView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: size.height + 20)
        scrollView.contentSize = CGSize(width: bounds.width, height: size.height + 20)
    }
    
    private func renderBasicHTML(_ html: String) {
        let cleanHTML = html
            .replacingOccurrences(of: "<script[^>]*>.*?</script>", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<style[^>]*>.*?</style>", with: "", options: [.regularExpression, .caseInsensitive])
        
        var yOffset: CGFloat = 10
        
        // Extract and display title
        if let titleMatch = cleanHTML.range(of: "<title>.*?</title>", options: [.regularExpression, .caseInsensitive]) {
            let titleTag = String(cleanHTML[titleMatch])
            let title = titleTag
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let titleLabel = createLabel(text: title, fontSize: 24, bold: true)
            contentView.addSubview(titleLabel)
            titleLabel.frame = CGRect(x: 10, y: yOffset, width: bounds.width - 20, height: 40)
            yOffset += 50
        }
        
        // Extract headings
        for level in 1...6 {
            let pattern = "<h\(level)[^>]*>(.*?)</h\(level)>"
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            regex?.enumerateMatches(in: cleanHTML, range: NSRange(cleanHTML.startIndex..., in: cleanHTML)) { match, _, _ in
                guard let match = match else { return }
                if let range = Range(match.range(at: 1), in: cleanHTML) {
                    let text = String(cleanHTML[range])
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !text.isEmpty {
                        let fontSize = CGFloat(32 - level * 3)
                        let label = createLabel(text: text, fontSize: fontSize, bold: true)
                        contentView.addSubview(label)
                        
                        let size = label.sizeThatFits(CGSize(width: bounds.width - 20, height: .greatestFiniteMagnitude))
                        label.frame = CGRect(x: 10, y: yOffset, width: bounds.width - 20, height: size.height)
                        yOffset += size.height + 10
                    }
                }
            }
        }
        
        // Extract paragraphs
        let pPattern = "<p[^>]*>(.*?)</p>"
        let pRegex = try? NSRegularExpression(pattern: pPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        pRegex?.enumerateMatches(in: cleanHTML, range: NSRange(cleanHTML.startIndex..., in: cleanHTML)) { match, _, _ in
            guard let match = match else { return }
            if let range = Range(match.range(at: 1), in: cleanHTML) {
                let text = String(cleanHTML[range])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&nbsp;", with: " ")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !text.isEmpty {
                    let label = createLabel(text: text, fontSize: 16, bold: false)
                    contentView.addSubview(label)
                    
                    let size = label.sizeThatFits(CGSize(width: bounds.width - 20, height: .greatestFiniteMagnitude))
                    label.frame = CGRect(x: 10, y: yOffset, width: bounds.width - 20, height: size.height)
                    yOffset += size.height + 10
                }
            }
        }
        
        // Extract divs and their content
        let divPattern = "<div[^>]*>(.*?)</div>"
        let divRegex = try? NSRegularExpression(pattern: divPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        divRegex?.enumerateMatches(in: cleanHTML, range: NSRange(cleanHTML.startIndex..., in: cleanHTML)) { match, _, _ in
            guard let match = match else { return }
            if let range = Range(match.range(at: 1), in: cleanHTML) {
                let text = String(cleanHTML[range])
                    .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                    .replacingOccurrences(of: "&[^;]+;", with: " ", options: .regularExpression)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !text.isEmpty && text.count > 10 {
                    let label = createLabel(text: String(text.prefix(500)), fontSize: 14, bold: false)
                    contentView.addSubview(label)
                    
                    let size = label.sizeThatFits(CGSize(width: bounds.width - 20, height: .greatestFiniteMagnitude))
                    label.frame = CGRect(x: 10, y: yOffset, width: bounds.width - 20, height: size.height)
                    yOffset += size.height + 8
                }
            }
        }
        
        // Extract links
        let linkPattern = "<a[^>]*href=[\"']([^\"']*)[\"'][^>]*>(.*?)</a>"
        let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive)
        linkRegex?.enumerateMatches(in: cleanHTML, range: NSRange(cleanHTML.startIndex..., in: cleanHTML)) { match, _, _ in
            guard let match = match else { return }
            if let hrefRange = Range(match.range(at: 1), in: cleanHTML),
               let textRange = Range(match.range(at: 2), in: cleanHTML) {
                let href = String(cleanHTML[hrefRange])
                let linkText = String(cleanHTML[textRange])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !linkText.isEmpty {
                    let button = UIButton(type: .system)
                    button.setTitle(linkText, for: .normal)
                    button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
                    button.contentHorizontalAlignment = .left
                    button.accessibilityIdentifier = href
                    button.addTarget(self, action: #selector(linkTapped(_:)), for: .touchUpInside)
                    
                    contentView.addSubview(button)
                    let size = button.sizeThatFits(CGSize(width: bounds.width - 20, height: 44))
                    button.frame = CGRect(x: 10, y: yOffset, width: min(size.width, bounds.width - 20), height: 30)
                    yOffset += 35
                }
            }
        }
        
        // If we didn't extract much content, just get all text
        if yOffset < 100 {
            let allText = cleanHTML
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "&[^;]+;", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !allText.isEmpty {
                let label = createLabel(text: String(allText.prefix(5000)), fontSize: 14, bold: false)
                contentView.addSubview(label)
                
                let size = label.sizeThatFits(CGSize(width: bounds.width - 20, height: .greatestFiniteMagnitude))
                label.frame = CGRect(x: 10, y: yOffset, width: bounds.width - 20, height: size.height)
                yOffset += size.height + 10
            }
        }
        
        // Update content view height
        contentView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: yOffset + 20)
        scrollView.contentSize = CGSize(width: bounds.width, height: yOffset + 20)
    }
    
    private func createLabel(text: String, fontSize: CGFloat, bold: Bool) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }
    
    @objc private func linkTapped(_ sender: UIButton) {
        if let href = sender.accessibilityIdentifier {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToURL"),
                object: nil,
                userInfo: ["url": href]
            )
        }
    }
    
    // UITextViewDelegate for handling links in NSAttributedString
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToURL"),
            object: nil,
            userInfo: ["url": URL.absoluteString]
        )
        return false // We handle the navigation ourselves
    }
}

// Enhanced Web Rendering View with CSS and JavaScript - Bypasses WebKit and Screen Time
struct WebRenderingView: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    
    class WebContentView: UIView {
        // Use RemoteRenderer for full browser capabilities
        private let renderer = RemoteRenderer()
        private var currentURL: String = ""
        
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
            
            // Setup enhanced renderer
            renderer.translatesAutoresizingMaskIntoConstraints = false
            addSubview(renderer)
            
            NSLayoutConstraint.activate([
                renderer.topAnchor.constraint(equalTo: topAnchor),
                renderer.leadingAnchor.constraint(equalTo: leadingAnchor),
                renderer.trailingAnchor.constraint(equalTo: trailingAnchor),
                renderer.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
        
        func loadURL(_ urlString: String, viewModel: BrowserViewModel) {
            guard currentURL != urlString else { return }
            currentURL = urlString
            
            // Normalize URL
            var normalizedURL = urlString
            if !normalizedURL.hasPrefix("http://") && !normalizedURL.hasPrefix("https://") {
                normalizedURL = "https://" + normalizedURL
            }
            
            guard let url = URL(string: normalizedURL) else {
                showError("Invalid URL")
                return
            }
            
            viewModel.isLoading = true
            
            // Use RemoteRenderer to load the URL
            renderer.loadURL(url)
            
            // Update page title
            viewModel.pageTitle = url.host ?? "Loading..."
            viewModel.isLoading = false
        }
        
        
        private func showError(_ message: String) {
            let errorLabel = UILabel()
            errorLabel.text = "Error: \(message)"
            errorLabel.textColor = .red
            errorLabel.textAlignment = .center
            errorLabel.numberOfLines = 0
            
            renderer.subviews.forEach { $0.removeFromSuperview() }
            renderer.addSubview(errorLabel)
            
            errorLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                errorLabel.centerXAnchor.constraint(equalTo: renderer.centerXAnchor),
                errorLabel.centerYAnchor.constraint(equalTo: renderer.centerYAnchor),
                errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: renderer.leadingAnchor, constant: 20),
                errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: renderer.trailingAnchor, constant: -20)
            ])
        }
    }
    
    func makeUIView(context: Context) -> WebContentView {
        let view = WebContentView()
        
        // Handle navigation
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToURL"),
            object: nil,
            queue: .main
        ) { notification in
            if let url = notification.userInfo?["url"] as? String {
                viewModel.navigate(to: url)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: WebContentView, context: Context) {
        if !viewModel.currentURL.isEmpty {
            uiView.loadURL(viewModel.currentURL, viewModel: viewModel)
        }
    }
}

struct ContentView: View {
    @StateObject private var browserViewModel = BrowserViewModel()
    @State private var urlText: String = ""
    @FocusState private var isURLFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack(spacing: 12) {
                // Back Button
                Button(action: {
                    browserViewModel.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18))
                        .foregroundColor(browserViewModel.canGoBack ? .primary : .gray)
                }
                .disabled(!browserViewModel.canGoBack)
                
                // Forward Button
                Button(action: {
                    browserViewModel.goForward()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18))
                        .foregroundColor(browserViewModel.canGoForward ? .primary : .gray)
                }
                .disabled(!browserViewModel.canGoForward)
                
                // URL Bar
                HStack {
                    Image(systemName: browserViewModel.isSecure ? "lock.fill" : "globe")
                        .font(.system(size: 14))
                        .foregroundColor(browserViewModel.isSecure ? .green : .gray)
                    
                    TextField("Enter URL or search", text: $urlText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($isURLFieldFocused)
                        .onSubmit {
                            browserViewModel.navigate(to: urlText)
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Reload Button
                Button(action: {
                    browserViewModel.reload()
                }) {
                    Image(systemName: browserViewModel.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 16))
                }
                
                // Menu Button
                Menu {
                    Button(action: {
                        browserViewModel.togglePrivateMode()
                    }) {
                        Label(browserViewModel.isPrivateMode ? "Exit Private Mode" : "Private Mode", 
                              systemImage: browserViewModel.isPrivateMode ? "eye" : "eye.slash")
                    }
                    
                    Divider()
                    
                    Button(action: {
                        browserViewModel.clearHistory()
                    }) {
                        Label("Clear History", systemImage: "trash")
                    }
                    
                    Button(action: {
                        browserViewModel.clearCookies()
                    }) {
                        Label("Clear Cookies", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.gray.opacity(0.3)),
                alignment: .bottom
            )
            
            // Progress Bar
            if browserViewModel.isLoading {
                ProgressView(value: browserViewModel.loadingProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 2)
            }
            
            // Web Content View - Using custom rendering engine
            // This bypasses WebKit and Screen Time restrictions
            WebRenderingView(viewModel: browserViewModel)
                .background(browserViewModel.isPrivateMode ? Color.black : Color.white)
            
            // Bottom Tab Bar (optional)
            HStack {
                Spacer()
                
                Button(action: {
                    // Show bookmarks
                }) {
                    Image(systemName: "book")
                        .font(.system(size: 20))
                }
                
                Spacer()
                
                Button(action: {
                    // Show history
                }) {
                    Image(systemName: "clock")
                        .font(.system(size: 20))
                }
                
                Spacer()
                
                Button(action: {
                    // New tab
                    browserViewModel.newTab()
                }) {
                    Image(systemName: "plus.square")
                        .font(.system(size: 20))
                }
                
                Spacer()
                
                Button(action: {
                    // Show tabs
                }) {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 20))
                }
                .overlay(
                    Text("\(browserViewModel.tabCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .offset(x: 12, y: -12),
                    alignment: .topTrailing
                )
                
                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.gray.opacity(0.3)),
                alignment: .top
            )
        }
        .onAppear {
            urlText = browserViewModel.currentURL
        }
        .onChange(of: browserViewModel.currentURL) { newValue in
            urlText = newValue
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}