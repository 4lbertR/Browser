import SwiftUI
import UIKit

// Temporary: BasicHTMLView defined here until build issue is resolved
struct BasicHTMLView: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = UIFont.systemFont(ofSize: 14)
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        if !viewModel.currentURL.isEmpty {
            textView.text = "Loading: \(viewModel.currentURL)\n\nNote: This is a placeholder.\nThe actual web rendering engine is being integrated."
            
            // Fetch and display basic content
            if let url = URL(string: viewModel.currentURL) {
                URLSession.shared.dataTask(with: url) { data, response, error in
                    DispatchQueue.main.async {
                        if let data = data, let html = String(data: data, encoding: .utf8) {
                            // Extract title if possible
                            if let titleRange = html.range(of: "<title>"),
                               let titleEndRange = html.range(of: "</title>", range: titleRange.upperBound..<html.endIndex) {
                                let title = String(html[titleRange.upperBound..<titleEndRange.lowerBound])
                                viewModel.pageTitle = title
                            }
                            
                            // Show basic text content
                            let strippedHTML = html
                                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                                .replacingOccurrences(of: "&[^;]+;", with: " ", options: .regularExpression)
                                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                            
                            textView.text = "URL: \(viewModel.currentURL)\n\nContent:\n\(String(strippedHTML.prefix(2000)))"
                        } else if let error = error {
                            textView.text = "Error loading \(viewModel.currentURL):\n\(error.localizedDescription)"
                        }
                    }
                }.resume()
            }
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