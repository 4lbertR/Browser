import SwiftUI
import UIKit

// Enhanced Web Rendering View with CSS and JavaScript - Bypasses WebKit and Screen Time
struct WebRenderingView: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    
    class WebContentView: UIView {
        private let renderer = EnhancedWebRenderer()
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
            
            // Use enhanced renderer to load the URL
            renderer.loadURL(url)
            
            // Extract title from HTML (for now, simplified)
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let html = String(data: data, encoding: .utf8) {
                    if let titleRange = html.range(of: "<title>", options: .caseInsensitive),
                       let titleEndRange = html.range(of: "</title>", options: .caseInsensitive) {
                        let title = String(html[titleRange.upperBound..<titleEndRange.lowerBound])
                        DispatchQueue.main.async {
                            viewModel.pageTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                            viewModel.isLoading = false
                        }
                    } else {
                        DispatchQueue.main.async {
                            viewModel.isLoading = false
                        }
                    }
                }
            }.resume()
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