import SwiftUI
import UIKit

// Custom Web Rendering View - Bypasses WebKit and Screen Time
struct WebRenderingView: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    
    class WebContentView: UIView {
        private let scrollView = UIScrollView()
        private let contentStack = UIStackView()
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
            
            // Setup scroll view
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(scrollView)
            
            // Setup stack view for content
            contentStack.axis = .vertical
            contentStack.spacing = 8
            contentStack.alignment = .leading
            contentStack.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(contentStack)
            
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
                
                contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 10),
                contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 10),
                contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -10),
                contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -20)
            ])
        }
        
        func loadURL(_ urlString: String, viewModel: BrowserViewModel) {
            guard currentURL != urlString else { return }
            currentURL = urlString
            
            // Clear previous content
            contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            guard let url = URL(string: urlString) else {
                showError("Invalid URL")
                return
            }
            
            // Fetch content directly (bypassing WebKit)
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.showError(error.localizedDescription)
                        return
                    }
                    
                    guard let data = data,
                          let html = String(data: data, encoding: .utf8) else {
                        self?.showError("Failed to load content")
                        return
                    }
                    
                    // Update title
                    if let titleRange = html.range(of: "<title>", options: .caseInsensitive),
                       let titleEndRange = html.range(of: "</title>", options: .caseInsensitive) {
                        let title = String(html[titleRange.upperBound..<titleEndRange.lowerBound])
                        viewModel.pageTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    // Parse and display HTML
                    self?.renderHTML(html)
                    viewModel.isLoading = false
                }
            }.resume()
            
            viewModel.isLoading = true
        }
        
        private func renderHTML(_ html: String) {
            // Simple HTML rendering without WebKit
            let parser = SimpleHTMLParser(html: html)
            let elements = parser.parse()
            
            for element in elements {
                switch element.type {
                case .heading(let level, let text):
                    addHeading(text, level: level)
                case .paragraph(let text):
                    addParagraph(text)
                case .link(let text, let href):
                    addLink(text, href: href)
                case .image(let src, let alt):
                    addImage(src, alt: alt)
                case .text(let text):
                    addText(text)
                case .list(let items):
                    addList(items)
                }
            }
        }
        
        private func addHeading(_ text: String, level: Int) {
            let label = UILabel()
            label.text = text
            label.font = UIFont.boldSystemFont(ofSize: CGFloat(32 - level * 4))
            label.numberOfLines = 0
            contentStack.addArrangedSubview(label)
        }
        
        private func addParagraph(_ text: String) {
            let label = UILabel()
            label.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            label.font = UIFont.systemFont(ofSize: 16)
            label.numberOfLines = 0
            contentStack.addArrangedSubview(label)
        }
        
        private func addText(_ text: String) {
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                addParagraph(text)
            }
        }
        
        private func addLink(_ text: String, href: String) {
            let button = UIButton(type: .system)
            button.setTitle(text, for: .normal)
            button.contentHorizontalAlignment = .left
            button.accessibilityIdentifier = href
            button.addTarget(self, action: #selector(linkTapped(_:)), for: .touchUpInside)
            contentStack.addArrangedSubview(button)
        }
        
        private func addImage(_ src: String, alt: String?) {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 200).isActive = true
            contentStack.addArrangedSubview(imageView)
            
            if let url = URL(string: src) {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            imageView.image = image
                        }
                    }
                }.resume()
            }
        }
        
        private func addList(_ items: [String]) {
            for item in items {
                let label = UILabel()
                label.text = "• \(item)"
                label.font = UIFont.systemFont(ofSize: 14)
                label.numberOfLines = 0
                contentStack.addArrangedSubview(label)
            }
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
        
        private func showError(_ message: String) {
            contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            let label = UILabel()
            label.text = "Error: \(message)"
            label.textColor = .red
            label.numberOfLines = 0
            contentStack.addArrangedSubview(label)
        }
    }
    
    // Simple HTML parser
    class SimpleHTMLParser {
        enum ElementType {
            case heading(Int, String)
            case paragraph(String)
            case link(String, String)
            case image(String, String?)
            case text(String)
            case list([String])
        }
        
        struct Element {
            let type: ElementType
        }
        
        private let html: String
        
        init(html: String) {
            self.html = html
        }
        
        func parse() -> [Element] {
            var elements: [Element] = []
            
            // Remove scripts and styles
            var cleanHTML = html
            cleanHTML = cleanHTML.replacingOccurrences(
                of: "<script[^>]*>.*?</script>",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            cleanHTML = cleanHTML.replacingOccurrences(
                of: "<style[^>]*>.*?</style>",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            
            // Extract headings
            for level in 1...6 {
                let pattern = "<h\(level)[^>]*>(.*?)</h\(level)>"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let matches = regex.matches(in: cleanHTML, range: NSRange(cleanHTML.startIndex..., in: cleanHTML))
                    for match in matches {
                        if let range = Range(match.range(at: 1), in: cleanHTML) {
                            let text = String(cleanHTML[range])
                                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                            elements.append(Element(type: .heading(level, text)))
                        }
                    }
                }
            }
            
            // Extract paragraphs
            if let regex = try? NSRegularExpression(pattern: "<p[^>]*>(.*?)</p>", options: .caseInsensitive) {
                let matches = regex.matches(in: cleanHTML, range: NSRange(cleanHTML.startIndex..., in: cleanHTML))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: cleanHTML) {
                        let text = String(cleanHTML[range])
                            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            elements.append(Element(type: .paragraph(text)))
                        }
                    }
                }
            }
            
            // If no structured content found, just get text
            if elements.isEmpty {
                let text = cleanHTML
                    .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                    .replacingOccurrences(of: "&[^;]+;", with: " ", options: .regularExpression)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    elements.append(Element(type: .text(String(text.prefix(5000)))))
                }
            }
            
            return elements
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