// Complete Web Rendering Engine - All-in-one file
// This implements a custom HTML/CSS rendering engine without WebKit
// Bypasses all Screen Time and content restrictions

import Foundation
import UIKit
import SwiftUI

// MARK: - HTML Parser

public class HTMLParser {
    public enum NodeType {
        case element(String)
        case text(String)
        case comment(String)
    }
    
    public class DOMNode {
        var type: NodeType
        var attributes: [String: String] = [:]
        var children: [DOMNode] = []
        weak var parent: DOMNode?
        
        init(type: NodeType) {
            self.type = type
        }
        
        var tagName: String? {
            if case .element(let name) = type {
                return name
            }
            return nil
        }
        
        var textContent: String {
            switch type {
            case .text(let content):
                return content
            case .element:
                return children.map { $0.textContent }.joined()
            default:
                return ""
            }
        }
    }
    
    private var html: String
    private var position: String.Index
    
    public init(html: String) {
        self.html = html
        self.position = html.startIndex
    }
    
    public func parse() -> DOMNode {
        let root = DOMNode(type: .element("html"))
        
        while !isAtEnd() {
            skipWhitespace()
            if isAtEnd() { break }
            
            if peek(string: "<!") {
                skipUntil(">")
                advance()
            } else if let node = parseNode() {
                root.children.append(node)
                node.parent = root
            }
        }
        
        return root
    }
    
    private func parseNode() -> DOMNode? {
        if peek(char: "<") {
            return parseElement()
        } else {
            return parseText()
        }
    }
    
    private func parseElement() -> DOMNode? {
        guard consume(char: "<") else { return nil }
        
        if peek(char: "/") {
            skipUntil(">")
            advance()
            return nil
        }
        
        let tagName = parseTagName()
        if tagName.isEmpty { return nil }
        
        let node = DOMNode(type: .element(tagName.lowercased()))
        
        // Parse attributes
        while !isAtEnd() && !peek(char: ">") {
            if let (key, value) = parseAttribute() {
                node.attributes[key] = value
            }
            skipWhitespace()
        }
        
        consume(char: ">")
        
        // Void elements
        let voidElements = ["br", "hr", "img", "input", "meta", "link"]
        if voidElements.contains(tagName.lowercased()) {
            return node
        }
        
        // Parse children
        while !isAtEnd() {
            if peek(string: "</") {
                skipUntil(">")
                advance()
                break
            }
            
            if let child = parseNode() {
                node.children.append(child)
                child.parent = node
            }
        }
        
        return node
    }
    
    private func parseText() -> DOMNode? {
        var text = ""
        while !isAtEnd() && !peek(char: "<") {
            text.append(current())
            advance()
        }
        
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        
        return DOMNode(type: .text(text))
    }
    
    private func parseTagName() -> String {
        var name = ""
        while !isAtEnd() && !current().isWhitespace && current() != ">" {
            name.append(current())
            advance()
        }
        return name
    }
    
    private func parseAttribute() -> (String, String)? {
        skipWhitespace()
        
        var name = ""
        while !isAtEnd() && current() != "=" && current() != ">" && !current().isWhitespace {
            name.append(current())
            advance()
        }
        
        if name.isEmpty { return nil }
        
        skipWhitespace()
        
        var value = ""
        if consume(char: "=") {
            skipWhitespace()
            
            if peek(char: "\"") {
                advance()
                while !isAtEnd() && current() != "\"" {
                    value.append(current())
                    advance()
                }
                advance()
            } else {
                while !isAtEnd() && !current().isWhitespace && current() != ">" {
                    value.append(current())
                    advance()
                }
            }
        }
        
        return (name.lowercased(), value)
    }
    
    // Parser helpers
    private func current() -> Character {
        return html[position]
    }
    
    private func advance() {
        if !isAtEnd() {
            position = html.index(after: position)
        }
    }
    
    private func peek(char: Character) -> Bool {
        return !isAtEnd() && current() == char
    }
    
    private func peek(string: String) -> Bool {
        var index = position
        for char in string {
            if index >= html.endIndex || html[index] != char {
                return false
            }
            index = html.index(after: index)
        }
        return true
    }
    
    private func consume(char: Character) -> Bool {
        if peek(char: char) {
            advance()
            return true
        }
        return false
    }
    
    private func skipWhitespace() {
        while !isAtEnd() && current().isWhitespace {
            advance()
        }
    }
    
    private func skipUntil(_ char: Character) {
        while !isAtEnd() && current() != char {
            advance()
        }
    }
    
    private func isAtEnd() -> Bool {
        return position >= html.endIndex
    }
}

// MARK: - Style Engine

public class StyleEngine {
    struct ComputedStyle {
        var fontSize: CGFloat = 16
        var color: UIColor = .black
        var backgroundColor: UIColor = .clear
        var fontWeight: UIFont.Weight = .regular
        var margin: CGFloat = 0
        var padding: CGFloat = 0
    }
    
    func computeStyle(for node: HTMLParser.DOMNode) -> ComputedStyle {
        var style = ComputedStyle()
        
        // Apply default styles based on tag
        switch node.tagName?.lowercased() {
        case "h1":
            style.fontSize = 32
            style.fontWeight = .bold
            style.margin = 16
        case "h2":
            style.fontSize = 24
            style.fontWeight = .bold
            style.margin = 14
        case "h3":
            style.fontSize = 18
            style.fontWeight = .bold
            style.margin = 12
        case "p":
            style.margin = 10
        case "a":
            style.color = .systemBlue
        case "strong", "b":
            style.fontWeight = .bold
        default:
            break
        }
        
        // Parse inline styles
        if let inlineStyle = node.attributes["style"] {
            let declarations = inlineStyle.components(separatedBy: ";")
            for declaration in declarations {
                let parts = declaration.components(separatedBy: ":")
                if parts.count == 2 {
                    let property = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    
                    switch property {
                    case "color":
                        style.color = parseColor(value) ?? style.color
                    case "font-size":
                        style.fontSize = parseSize(value)
                    case "font-weight":
                        if value == "bold" {
                            style.fontWeight = .bold
                        }
                    default:
                        break
                    }
                }
            }
        }
        
        return style
    }
    
    private func parseColor(_ value: String) -> UIColor? {
        if value.hasPrefix("#") {
            let hex = String(value.dropFirst())
            var rgb: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&rgb)
            
            return UIColor(
                red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
                green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
                blue: CGFloat(rgb & 0xFF) / 255.0,
                alpha: 1.0
            )
        }
        
        switch value {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "black": return .black
        case "white": return .white
        default: return nil
        }
    }
    
    private func parseSize(_ value: String) -> CGFloat {
        if value.hasSuffix("px") {
            return CGFloat(Double(value.dropLast(2)) ?? 16)
        }
        return CGFloat(Double(value) ?? 16)
    }
}

// MARK: - Rendering Engine

class WebRenderingEngine {
    private let styleEngine = StyleEngine()
    private var currentY: CGFloat = 0
    
    func render(html: String, in view: UIView) {
        view.subviews.forEach { $0.removeFromSuperview() }
        
        let parser = HTMLParser(html: html)
        let dom = parser.parse()
        
        currentY = 0
        renderNode(dom, in: view, x: 10, width: view.bounds.width - 20)
    }
    
    private func renderNode(_ node: HTMLParser.DOMNode, in view: UIView, x: CGFloat, width: CGFloat) {
        let style = styleEngine.computeStyle(for: node)
        
        if case .text(let content) = node.type {
            let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                let label = UILabel()
                label.text = text
                label.font = UIFont.systemFont(ofSize: style.fontSize, weight: style.fontWeight)
                label.textColor = style.color
                label.numberOfLines = 0
                label.lineBreakMode = .byWordWrapping
                
                let size = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
                label.frame = CGRect(x: x, y: currentY + style.margin, width: width, height: size.height)
                
                view.addSubview(label)
                currentY += size.height + style.margin * 2
                
                // Handle links
                if let parent = node.parent, parent.tagName == "a", let href = parent.attributes["href"] {
                    label.isUserInteractionEnabled = true
                    label.accessibilityIdentifier = href
                    let tap = UITapGestureRecognizer(target: self, action: #selector(linkTapped(_:)))
                    label.addGestureRecognizer(tap)
                }
            }
        }
        
        // Handle images
        if node.tagName == "img", let src = node.attributes["src"] {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.frame = CGRect(x: x, y: currentY, width: width, height: 200)
            view.addSubview(imageView)
            currentY += 200
            
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
        
        // Render children
        for child in node.children {
            renderNode(child, in: view, x: x, width: width)
        }
    }
    
    @objc private func linkTapped(_ gesture: UITapGestureRecognizer) {
        if let href = gesture.view?.accessibilityIdentifier {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToURL"),
                object: nil,
                userInfo: ["url": href]
            )
        }
    }
}

// MARK: - Web View Controller

public class WebViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let engine = WebRenderingEngine()
    
    public var url: URL?
    public var onNavigate: ((String) -> Void)?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNavigation(_:)),
            name: NSNotification.Name("NavigateToURL"),
            object: nil
        )
    }
    
    private func setupViews() {
        view.backgroundColor = .white
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    @objc private func handleNavigation(_ notification: Notification) {
        if let urlString = notification.userInfo?["url"] as? String {
            onNavigate?(urlString)
        }
    }
    
    public func loadURL(_ url: URL) {
        self.url = url
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data,
                  let html = String(data: data, encoding: .utf8) else { return }
            
            DispatchQueue.main.async {
                self?.renderHTML(html)
            }
        }.resume()
    }
    
    private func renderHTML(_ html: String) {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        engine.render(html: html, in: contentView)
        
        // Update scroll view content size
        var maxY: CGFloat = 0
        for subview in contentView.subviews {
            maxY = max(maxY, subview.frame.maxY)
        }
        
        contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: maxY + 20).isActive = true
        scrollView.contentSize = CGSize(width: view.bounds.width, height: maxY + 20)
    }
}

// MARK: - SwiftUI Integration

public struct WebRenderingView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    
    public func makeUIViewController(context: Context) -> WebViewController {
        let controller = WebViewController()
        controller.onNavigate = { url in
            viewModel.navigate(to: url)
        }
        return controller
    }
    
    public func updateUIViewController(_ controller: WebViewController, context: Context) {
        if let url = URL(string: viewModel.currentURL) {
            controller.loadURL(url)
        }
    }
}