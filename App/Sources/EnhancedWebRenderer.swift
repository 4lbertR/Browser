import SwiftUI
import UIKit
import JavaScriptCore
import WebKit

// Enhanced Web Rendering Engine with CSS and JavaScript Support
class EnhancedWebRenderer: UIView {
    private let scrollView = UIScrollView()
    private var contentView = UIView()
    private var jsContext: JSContext?
    private var cssStyles: [String: [String: String]] = [:]
    private var documentElements: [DOMElement] = []
    private var currentURL: URL?
    
    // DOM Element representation
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
        
        // Setup console.log
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("[JS Console]:", message)
        }
        jsContext?.setObject(consoleLog, forKeyedSubscript: "consoleLog" as NSString)
        jsContext?.evaluateScript("var console = { log: function(msg) { consoleLog(String(msg)); } };")
        
        // Setup document object
        setupDocumentAPI()
        
        // Setup window object
        setupWindowAPI()
    }
    
    private func setupDocumentAPI() {
        // document.getElementById
        let getElementById: @convention(block) (String) -> JSValue? = { [weak self] id in
            guard let self = self else { return nil }
            if let element = self.findElementById(id, in: self.documentElements) {
                return self.createJSElement(element)
            }
            return nil
        }
        
        // document.getElementsByClassName
        let getElementsByClassName: @convention(block) (String) -> JSValue? = { [weak self] className in
            guard let self = self else { return nil }
            let elements = self.findElementsByClassName(className, in: self.documentElements)
            return self.createJSArray(elements)
        }
        
        // document.getElementsByTagName
        let getElementsByTagName: @convention(block) (String) -> JSValue? = { [weak self] tagName in
            guard let self = self else { return nil }
            let elements = self.findElementsByTagName(tagName.lowercased(), in: self.documentElements)
            return self.createJSArray(elements)
        }
        
        // Create document object
        let document = JSValue(newObjectIn: jsContext)
        document?.setObject(getElementById, forKeyedSubscript: "getElementById" as NSString)
        document?.setObject(getElementsByClassName, forKeyedSubscript: "getElementsByClassName" as NSString)
        document?.setObject(getElementsByTagName, forKeyedSubscript: "getElementsByTagName" as NSString)
        
        jsContext?.setObject(document, forKeyedSubscript: "document" as NSString)
    }
    
    private func setupWindowAPI() {
        // window.alert
        let alert: @convention(block) (String) -> Void = { message in
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .default))
                    rootVC.present(alertController, animated: true)
                }
            }
        }
        
        // window.location
        let location = JSValue(newObjectIn: jsContext)
        location?.setObject(currentURL?.absoluteString ?? "", forKeyedSubscript: "href" as NSString)
        location?.setObject(currentURL?.host ?? "", forKeyedSubscript: "hostname" as NSString)
        location?.setObject(currentURL?.path ?? "", forKeyedSubscript: "pathname" as NSString)
        
        let window = JSValue(newObjectIn: jsContext)
        window?.setObject(alert, forKeyedSubscript: "alert" as NSString)
        window?.setObject(location, forKeyedSubscript: "location" as NSString)
        
        jsContext?.setObject(window, forKeyedSubscript: "window" as NSString)
    }
    
    func loadURL(_ url: URL) {
        currentURL = url
        
        // Clear previous content
        contentView.subviews.forEach { $0.removeFromSuperview() }
        documentElements.removeAll()
        cssStyles.removeAll()
        
        // Fetch content
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                return
            }
            
            DispatchQueue.main.async {
                self.parseAndRenderHTML(html)
            }
        }.resume()
    }
    
    private func parseAndRenderHTML(_ html: String) {
        // Parse HTML into DOM tree
        let rootElement = parseHTML(html)
        documentElements = [rootElement]
        
        // Extract and parse CSS
        extractAndParseCSS(from: html)
        
        // Apply CSS styles
        applyStyles(to: rootElement)
        
        // Render DOM tree
        renderElement(rootElement, in: contentView, yOffset: 0)
        
        // Execute JavaScript
        extractAndExecuteJavaScript(from: html)
    }
    
    private func parseHTML(_ html: String) -> DOMElement {
        let root = DOMElement(tagName: "html")
        
        // Simple HTML parser
        var currentElement = root
        var elementStack: [DOMElement] = [root]
        
        // Regular expression patterns
        let tagPattern = "<([^>]+)>"
        let regex = try? NSRegularExpression(pattern: tagPattern)
        
        var lastIndex = html.startIndex
        regex?.enumerateMatches(in: html, range: NSRange(html.startIndex..., in: html)) { match, _, _ in
            guard let matchRange = match?.range(at: 1),
                  let range = Range(matchRange, in: html) else { return }
            
            let tagContent = String(html[range])
            
            // Extract text before tag
            if lastIndex < html.index(before: range.lowerBound) {
                let textRange = lastIndex..<html.index(before: range.lowerBound)
                let text = String(html[textRange])
                    .replacingOccurrences(of: "&nbsp;", with: " ")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&amp;", with: "&")
                
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    currentElement.textContent += text
                }
            }
            
            if tagContent.hasPrefix("/") {
                // Closing tag
                let tagName = String(tagContent.dropFirst()).split(separator: " ").first ?? ""
                if elementStack.count > 1 {
                    elementStack.removeLast()
                    currentElement = elementStack.last ?? root
                }
            } else if !tagContent.hasPrefix("!") && !tagContent.hasPrefix("?") {
                // Opening tag or self-closing tag
                let parts = tagContent.split(separator: " ", maxSplits: 1)
                let tagName = String(parts.first ?? "").lowercased()
                
                if !["meta", "link", "img", "input", "br", "hr"].contains(tagName) {
                    let newElement = DOMElement(tagName: tagName)
                    
                    // Parse attributes
                    if parts.count > 1 {
                        parseAttributes(String(parts[1]), into: newElement)
                    }
                    
                    currentElement.children.append(newElement)
                    elementStack.append(newElement)
                    currentElement = newElement
                }
            }
            
            lastIndex = html.index(after: range.upperBound)
        }
        
        return root
    }
    
    private func parseAttributes(_ attributeString: String, into element: DOMElement) {
        let pattern = #"(\w+)(?:="([^"]*)"|\='([^']*)'|=(\S+))?"#
        let regex = try? NSRegularExpression(pattern: pattern)
        
        regex?.enumerateMatches(in: attributeString, range: NSRange(attributeString.startIndex..., in: attributeString)) { match, _, _ in
            guard let match = match else { return }
            
            if let nameRange = Range(match.range(at: 1), in: attributeString) {
                let name = String(attributeString[nameRange])
                var value = ""
                
                for i in 2...4 {
                    if let valueRange = Range(match.range(at: i), in: attributeString) {
                        value = String(attributeString[valueRange])
                        break
                    }
                }
                
                element.attributes[name] = value
            }
        }
    }
    
    private func extractAndParseCSS(from html: String) {
        // Extract inline styles from <style> tags
        let stylePattern = "<style[^>]*>([^<]*)</style>"
        let regex = try? NSRegularExpression(pattern: stylePattern, options: .caseInsensitive)
        
        regex?.enumerateMatches(in: html, range: NSRange(html.startIndex..., in: html)) { match, _, _ in
            guard let matchRange = match?.range(at: 1),
                  let range = Range(matchRange, in: html) else { return }
            
            let css = String(html[range])
            parseCSS(css)
        }
        
        // Also extract linked stylesheets (simplified - would need to fetch)
        let linkPattern = #"<link[^>]*rel="stylesheet"[^>]*href="([^"]*)"[^>]*>"#
        let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive)
        
        linkRegex?.enumerateMatches(in: html, range: NSRange(html.startIndex..., in: html)) { match, _, _ in
            guard let matchRange = match?.range(at: 1),
                  let range = Range(matchRange, in: html) else { return }
            
            let href = String(html[range])
            // In a real implementation, fetch and parse external CSS
            print("Found stylesheet:", href)
        }
    }
    
    private func parseCSS(_ css: String) {
        // Simple CSS parser
        let rulePattern = #"([^{]+)\{([^}]+)\}"#
        let regex = try? NSRegularExpression(pattern: rulePattern)
        
        regex?.enumerateMatches(in: css, range: NSRange(css.startIndex..., in: css)) { match, _, _ in
            guard let selectorRange = Range(match?.range(at: 1), in: css),
                  let declarationsRange = Range(match?.range(at: 2), in: css) else { return }
            
            let selector = String(css[selectorRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let declarations = String(css[declarationsRange])
            
            var styles: [String: String] = [:]
            let properties = declarations.split(separator: ";")
            
            for property in properties {
                let parts = property.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                    styles[key] = value
                }
            }
            
            cssStyles[selector] = styles
        }
    }
    
    private func applyStyles(to element: DOMElement) {
        // Apply tag-based styles
        if let tagStyles = cssStyles[element.tagName] {
            element.computedStyle.merge(tagStyles) { _, new in new }
        }
        
        // Apply class-based styles
        if let classes = element.attributes["class"]?.split(separator: " ") {
            for className in classes {
                if let classStyles = cssStyles[".\(className)"] {
                    element.computedStyle.merge(classStyles) { _, new in new }
                }
            }
        }
        
        // Apply ID-based styles
        if let id = element.attributes["id"], let idStyles = cssStyles["#\(id)"] {
            element.computedStyle.merge(idStyles) { _, new in new }
        }
        
        // Apply inline styles
        if let inlineStyle = element.attributes["style"] {
            let properties = inlineStyle.split(separator: ";")
            for property in properties {
                let parts = property.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                    element.computedStyle[key] = value
                }
            }
        }
        
        // Apply to children
        for child in element.children {
            applyStyles(to: child)
        }
    }
    
    private func renderElement(_ element: DOMElement, in parentView: UIView, yOffset: CGFloat) -> CGFloat {
        var currentY = yOffset
        
        // Skip certain elements
        if ["script", "style", "head", "meta", "link"].contains(element.tagName) {
            return currentY
        }
        
        // Create view for element
        let elementView = createView(for: element)
        element.view = elementView
        
        if let elementView = elementView {
            parentView.addSubview(elementView)
            
            // Apply computed styles
            applyStylesToView(element.computedStyle, view: elementView)
            
            // Position view
            let width = parentView.bounds.width - 20
            let height = calculateHeight(for: element, width: width)
            
            elementView.frame = CGRect(x: 10, y: currentY, width: width, height: height)
            currentY += height + 5
        }
        
        // Render children
        if let containerView = elementView ?? parentView {
            var childY: CGFloat = 0
            for child in element.children {
                childY = renderElement(child, in: containerView, yOffset: childY)
            }
            
            // Update container height
            if let elementView = elementView {
                var frame = elementView.frame
                frame.size.height = max(frame.size.height, childY)
                elementView.frame = frame
                currentY = frame.maxY + 5
            }
        }
        
        return currentY
    }
    
    private func createView(for element: DOMElement) -> UIView? {
        switch element.tagName {
        case "div", "section", "article", "main", "aside", "nav", "header", "footer":
            let containerView = UIView()
            containerView.backgroundColor = .clear
            return containerView
            
        case "p", "h1", "h2", "h3", "h4", "h5", "h6", "span", "strong", "em", "b", "i":
            let label = UILabel()
            label.text = element.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
            label.numberOfLines = 0
            
            // Set font based on tag
            switch element.tagName {
            case "h1":
                label.font = UIFont.boldSystemFont(ofSize: 32)
            case "h2":
                label.font = UIFont.boldSystemFont(ofSize: 28)
            case "h3":
                label.font = UIFont.boldSystemFont(ofSize: 24)
            case "h4":
                label.font = UIFont.boldSystemFont(ofSize: 20)
            case "h5":
                label.font = UIFont.boldSystemFont(ofSize: 18)
            case "h6":
                label.font = UIFont.boldSystemFont(ofSize: 16)
            case "strong", "b":
                label.font = UIFont.boldSystemFont(ofSize: 16)
            case "em", "i":
                label.font = UIFont.italicSystemFont(ofSize: 16)
            default:
                label.font = UIFont.systemFont(ofSize: 16)
            }
            
            return label
            
        case "a":
            let button = UIButton(type: .system)
            button.setTitle(element.textContent, for: .normal)
            button.contentHorizontalAlignment = .left
            
            if let href = element.attributes["href"] {
                button.accessibilityIdentifier = href
                button.addTarget(self, action: #selector(linkTapped(_:)), for: .touchUpInside)
            }
            
            return button
            
        case "img":
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            
            if let src = element.attributes["src"],
               let url = URL(string: src) {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            imageView.image = image
                        }
                    }
                }.resume()
            }
            
            return imageView
            
        case "input":
            let textField = UITextField()
            textField.borderStyle = .roundedRect
            textField.placeholder = element.attributes["placeholder"]
            textField.text = element.attributes["value"]
            
            if element.attributes["type"] == "submit" {
                let button = UIButton(type: .system)
                button.setTitle(element.attributes["value"] ?? "Submit", for: .normal)
                button.backgroundColor = .systemBlue
                button.setTitleColor(.white, for: .normal)
                button.layer.cornerRadius = 5
                return button
            }
            
            return textField
            
        case "button":
            let button = UIButton(type: .system)
            button.setTitle(element.textContent, for: .normal)
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 5
            
            if let onclick = element.attributes["onclick"] {
                button.accessibilityLabel = onclick
                button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            }
            
            return button
            
        case "ul", "ol":
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = 4
            
            for (index, child) in element.children.enumerated() {
                if child.tagName == "li" {
                    let label = UILabel()
                    let prefix = element.tagName == "ol" ? "\(index + 1). " : "• "
                    label.text = prefix + child.textContent
                    label.numberOfLines = 0
                    label.font = UIFont.systemFont(ofSize: 14)
                    stackView.addArrangedSubview(label)
                }
            }
            
            return stackView
            
        default:
            if !element.textContent.isEmpty {
                let label = UILabel()
                label.text = element.textContent
                label.numberOfLines = 0
                label.font = UIFont.systemFont(ofSize: 16)
                return label
            }
            return nil
        }
    }
    
    private func applyStylesToView(_ styles: [String: String], view: UIView) {
        for (property, value) in styles {
            switch property {
            case "color":
                if let label = view as? UILabel {
                    label.textColor = parseColor(value)
                } else if let button = view as? UIButton {
                    button.setTitleColor(parseColor(value), for: .normal)
                }
                
            case "background-color", "background":
                view.backgroundColor = parseColor(value)
                
            case "font-size":
                if let label = view as? UILabel,
                   let size = parseSize(value) {
                    label.font = label.font.withSize(size)
                }
                
            case "font-weight":
                if let label = view as? UILabel {
                    if value == "bold" || value == "700" {
                        label.font = UIFont.boldSystemFont(ofSize: label.font.pointSize)
                    }
                }
                
            case "text-align":
                if let label = view as? UILabel {
                    switch value {
                    case "center":
                        label.textAlignment = .center
                    case "right":
                        label.textAlignment = .right
                    default:
                        label.textAlignment = .left
                    }
                }
                
            case "padding":
                if let size = parseSize(value) {
                    view.layoutMargins = UIEdgeInsets(top: size, left: size, bottom: size, right: size)
                }
                
            case "margin":
                // Would need to adjust frame positioning
                break
                
            case "border":
                let parts = value.split(separator: " ")
                if parts.count >= 2 {
                    if let width = parseSize(String(parts[0])) {
                        view.layer.borderWidth = width
                    }
                    if parts.count >= 3 {
                        view.layer.borderColor = parseColor(String(parts[2])).cgColor
                    }
                }
                
            case "border-radius":
                if let radius = parseSize(value) {
                    view.layer.cornerRadius = radius
                }
                
            case "display":
                view.isHidden = value == "none"
                
            default:
                break
            }
        }
    }
    
    private func parseColor(_ value: String) -> UIColor {
        switch value.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "black": return .black
        case "white": return .white
        case "gray", "grey": return .gray
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "transparent": return .clear
        default:
            // Parse hex colors
            if value.hasPrefix("#") {
                let hex = String(value.dropFirst())
                if hex.count == 6 || hex.count == 3 {
                    var rgbValue: UInt64 = 0
                    Scanner(string: hex).scanHexInt64(&rgbValue)
                    
                    if hex.count == 6 {
                        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
                        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
                        let blue = CGFloat(rgbValue & 0x0000FF) / 255.0
                        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
                    } else {
                        let red = CGFloat((rgbValue & 0xF00) >> 8) / 15.0
                        let green = CGFloat((rgbValue & 0x0F0) >> 4) / 15.0
                        let blue = CGFloat(rgbValue & 0x00F) / 15.0
                        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
                    }
                }
            }
            
            // Parse rgb() colors
            if value.hasPrefix("rgb") {
                let pattern = #"(\d+)[,\s]+(\d+)[,\s]+(\d+)"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) {
                    
                    let ranges = [1, 2, 3].compactMap { Range(match.range(at: $0), in: value) }
                    let values = ranges.compactMap { Double(value[$0]) }
                    
                    if values.count == 3 {
                        return UIColor(red: CGFloat(values[0])/255.0,
                                     green: CGFloat(values[1])/255.0,
                                     blue: CGFloat(values[2])/255.0,
                                     alpha: 1.0)
                    }
                }
            }
            
            return .black
        }
    }
    
    private func parseSize(_ value: String) -> CGFloat? {
        let cleanValue = value.replacingOccurrences(of: "px", with: "")
            .replacingOccurrences(of: "pt", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        return Double(cleanValue).map { CGFloat($0) }
    }
    
    private func calculateHeight(for element: DOMElement, width: CGFloat) -> CGFloat {
        if let label = element.view as? UILabel {
            let size = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            return size.height
        }
        
        if element.tagName == "img" {
            return 200 // Default image height
        }
        
        if element.tagName == "input" || element.tagName == "button" {
            return 44
        }
        
        // Default height for containers
        if ["div", "section", "article"].contains(element.tagName) {
            return 0 // Will be adjusted based on children
        }
        
        return 30
    }
    
    private func extractAndExecuteJavaScript(from html: String) {
        // Extract inline scripts
        let scriptPattern = "<script[^>]*>([^<]*)</script>"
        let regex = try? NSRegularExpression(pattern: scriptPattern, options: .caseInsensitive)
        
        regex?.enumerateMatches(in: html, range: NSRange(html.startIndex..., in: html)) { match, _, _ in
            guard let matchRange = match?.range(at: 1),
                  let range = Range(matchRange, in: html) else { return }
            
            let script = String(html[range])
            
            // Execute JavaScript
            if !script.isEmpty {
                jsContext?.evaluateScript(script)
            }
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
    
    @objc private func buttonTapped(_ sender: UIButton) {
        if let onclick = sender.accessibilityLabel {
            jsContext?.evaluateScript(onclick)
        }
    }
    
    // Helper methods for JavaScript
    private func findElementById(_ id: String, in elements: [DOMElement]) -> DOMElement? {
        for element in elements {
            if element.attributes["id"] == id {
                return element
            }
            if let found = findElementById(id, in: element.children) {
                return found
            }
        }
        return nil
    }
    
    private func findElementsByClassName(_ className: String, in elements: [DOMElement]) -> [DOMElement] {
        var results: [DOMElement] = []
        
        for element in elements {
            if let classes = element.attributes["class"]?.split(separator: " "),
               classes.contains(where: { String($0) == className }) {
                results.append(element)
            }
            results += findElementsByClassName(className, in: element.children)
        }
        
        return results
    }
    
    private func findElementsByTagName(_ tagName: String, in elements: [DOMElement]) -> [DOMElement] {
        var results: [DOMElement] = []
        
        for element in elements {
            if element.tagName == tagName {
                results.append(element)
            }
            results += findElementsByTagName(tagName, in: element.children)
        }
        
        return results
    }
    
    private func createJSElement(_ element: DOMElement) -> JSValue? {
        let jsElement = JSValue(newObjectIn: jsContext)
        
        // Add properties
        jsElement?.setObject(element.tagName, forKeyedSubscript: "tagName" as NSString)
        jsElement?.setObject(element.textContent, forKeyedSubscript: "textContent" as NSString)
        jsElement?.setObject(element.attributes["id"] ?? "", forKeyedSubscript: "id" as NSString)
        jsElement?.setObject(element.attributes["class"] ?? "", forKeyedSubscript: "className" as NSString)
        
        // Add innerHTML setter
        let setInnerHTML: @convention(block) (String) -> Void = { [weak self, weak element] html in
            guard let element = element else { return }
            
            DispatchQueue.main.async {
                element.textContent = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                
                if let label = element.view as? UILabel {
                    label.text = element.textContent
                }
            }
        }
        jsElement?.setObject(setInnerHTML, forKeyedSubscript: "setInnerHTML" as NSString)
        
        // Add style property
        let style = JSValue(newObjectIn: jsContext)
        for (key, value) in element.computedStyle {
            style?.setObject(value, forKeyedSubscript: key as NSString)
        }
        jsElement?.setObject(style, forKeyedSubscript: "style" as NSString)
        
        return jsElement
    }
    
    private func createJSArray(_ elements: [DOMElement]) -> JSValue? {
        let array = JSValue(newArrayIn: jsContext)
        
        for (index, element) in elements.enumerated() {
            if let jsElement = createJSElement(element) {
                array?.setObject(jsElement, atIndexedSubscript: index)
            }
        }
        
        return array
    }
}