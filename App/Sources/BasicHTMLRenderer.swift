import SwiftUI
import UIKit

// Basic HTML renderer that fetches and displays web content
// This bypasses WebKit and Screen Time restrictions
class BasicHTMLRenderer: UIView {
    private let textView = UITextView()
    private var currentURL: String = ""
    var onLinkTapped: ((String) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        textView.isEditable = false
        textView.isSelectable = true
        textView.dataDetectorTypes = .link
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func loadURL(_ urlString: String) {
        currentURL = urlString
        
        guard let url = URL(string: urlString) else {
            displayError("Invalid URL")
            return
        }
        
        // Create a URLSession that bypasses restrictions
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false
        configuration.allowsCellularAccess = true
        configuration.timeoutIntervalForRequest = 30
        
        let session = URLSession(configuration: configuration)
        
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.displayError("Failed to load: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self?.displayError("No data received")
                    return
                }
                
                // Try to convert HTML to attributed string
                if let htmlString = String(data: data, encoding: .utf8) {
                    self?.displayHTML(htmlString, baseURL: url)
                } else {
                    self?.displayError("Failed to decode content")
                }
            }
        }
        
        task.resume()
    }
    
    private func displayHTML(_ html: String, baseURL: URL) {
        // Basic HTML to AttributedString conversion
        let modifiedHTML = """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    font-size: 16px;
                    line-height: 1.5;
                    padding: 10px;
                    margin: 0;
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
                a {
                    color: #007AFF;
                    text-decoration: none;
                }
                pre, code {
                    background: #f5f5f5;
                    padding: 5px;
                    border-radius: 3px;
                    overflow-x: auto;
                }
            </style>
        </head>
        <body>
            \(html)
        </body>
        </html>
        """
        
        if let data = modifiedHTML.data(using: .utf8) {
            do {
                let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ]
                
                let attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
                textView.attributedText = attributedString
                textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            } catch {
                // If HTML parsing fails, show plain text
                displayPlainText(html)
            }
        }
    }
    
    private func displayPlainText(_ text: String) {
        textView.text = text
        textView.font = UIFont.systemFont(ofSize: 14)
    }
    
    private func displayError(_ message: String) {
        let errorText = """
        Error Loading Page
        
        URL: \(currentURL)
        Error: \(message)
        
        This is a basic HTML renderer for demonstration purposes.
        For full web browsing, the Chromium engine integration needs to be completed.
        """
        
        textView.text = errorText
        textView.textColor = .red
    }
}

extension BasicHTMLRenderer: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        // Handle link taps
        onLinkTapped?(URL.absoluteString)
        return false // We handle it ourselves
    }
}

// SwiftUI wrapper
struct BasicHTMLView: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    
    func makeUIView(context: Context) -> BasicHTMLRenderer {
        let renderer = BasicHTMLRenderer()
        renderer.onLinkTapped = { url in
            viewModel.navigate(to: url)
        }
        return renderer
    }
    
    func updateUIView(_ uiView: BasicHTMLRenderer, context: Context) {
        if !viewModel.currentURL.isEmpty {
            uiView.loadURL(viewModel.currentURL)
        }
    }
}