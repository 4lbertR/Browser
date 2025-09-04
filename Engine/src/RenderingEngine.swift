import Foundation
import UIKit
import CoreGraphics

// Main rendering engine that combines HTML, CSS, and layout
public class RenderingEngine {
    
    private let htmlParser = HTMLParser(html: "")
    private let cssParser = CSSParser()
    private var rootNode: HTMLParser.DOMNode?
    private var viewport: CGSize = CGSize(width: 375, height: 667)
    
    // Layout box for rendering
    class LayoutBox {
        let node: HTMLParser.DOMNode
        let style: CSSParser.ComputedStyle
        var frame: CGRect = .zero
        var children: [LayoutBox] = []
        
        init(node: HTMLParser.DOMNode, style: CSSParser.ComputedStyle) {
            self.node = node
            self.style = style
        }
    }
    
    public init() {}
    
    // Load and parse HTML content
    public func loadHTML(_ html: String, css: String? = nil) {
        let parser = HTMLParser(html: html)
        rootNode = parser.parse()
        
        // Parse any CSS
        if let css = css {
            cssParser.parse(css)
        }
        
        // Extract embedded styles
        extractEmbeddedStyles(from: rootNode)
    }
    
    // Render to a UIView
    public func render(in containerView: UIView) {
        containerView.subviews.forEach { $0.removeFromSuperview() }
        
        guard let rootNode = rootNode else { return }
        
        // Create layout tree
        let layoutTree = createLayoutTree(rootNode)
        
        // Calculate layout
        calculateLayout(layoutTree, in: CGRect(origin: .zero, size: containerView.bounds.size))
        
        // Render to view
        renderLayoutTree(layoutTree, in: containerView)
    }
    
    // Create layout tree from DOM
    private func createLayoutTree(_ node: HTMLParser.DOMNode) -> LayoutBox? {
        // Skip text nodes with only whitespace
        if case .text(let content) = node.type, content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        
        let style = cssParser.getComputedStyle(for: node)
        
        // Skip nodes with display: none
        if style.display == "none" {
            return nil
        }
        
        let box = LayoutBox(node: node, style: style)
        
        // Add children
        for child in node.children {
            if let childBox = createLayoutTree(child) {
                box.children.append(childBox)
            }
        }
        
        return box
    }
    
    // Calculate layout positions and sizes
    private func calculateLayout(_ box: LayoutBox, in bounds: CGRect) {
        var currentY = bounds.minY + box.style.margin.top + box.style.padding.top
        let contentWidth = bounds.width - box.style.margin.left - box.style.margin.right - 
                          box.style.padding.left - box.style.padding.right
        
        // Set box frame
        box.frame = CGRect(
            x: bounds.minX + box.style.margin.left,
            y: bounds.minY + box.style.margin.top,
            width: box.style.width ?? contentWidth,
            height: 0 // Will be calculated based on content
        )
        
        // Layout children
        var maxChildHeight: CGFloat = 0
        
        for child in box.children {
            let childBounds = CGRect(
                x: box.frame.minX + box.style.padding.left,
                y: currentY,
                width: contentWidth,
                height: bounds.height - currentY
            )
            
            calculateLayout(child, in: childBounds)
            
            // Update position based on display type
            if child.style.display == "block" {
                currentY += child.frame.height + child.style.margin.top + child.style.margin.bottom
                maxChildHeight = max(maxChildHeight, currentY - box.frame.minY)
            } else if child.style.display == "inline" || child.style.display == "inline-block" {
                // Simplified inline layout
                currentY += child.frame.height
                maxChildHeight = max(maxChildHeight, child.frame.height)
            }
        }
        
        // Calculate text height if text node
        if case .text(let content) = box.node.type {
            let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                let font = UIFont.systemFont(ofSize: box.style.fontSize, weight: box.style.fontWeight)
                let size = (text as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font],
                    context: nil
                ).size
                
                box.frame.size.height = size.height + box.style.padding.top + box.style.padding.bottom
                maxChildHeight = box.frame.height
            }
        }
        
        // Set final height
        if box.frame.height == 0 {
            box.frame.size.height = maxChildHeight + box.style.padding.top + box.style.padding.bottom
        }
    }
    
    // Render layout tree to UIView
    private func renderLayoutTree(_ box: LayoutBox, in containerView: UIView) {
        // Create view for this box
        let view = createView(for: box)
        view.frame = box.frame
        containerView.addSubview(view)
        
        // Render children
        for child in box.children {
            renderLayoutTree(child, in: view)
        }
    }
    
    // Create UIView for a layout box
    private func createView(for box: LayoutBox) -> UIView {
        let view = UIView()
        
        // Apply background color
        if box.style.backgroundColor != .clear {
            view.backgroundColor = box.style.backgroundColor
        }
        
        // Apply border
        if box.style.border > 0 {
            view.layer.borderWidth = box.style.border
            view.layer.borderColor = UIColor.black.cgColor
        }
        
        // Handle text nodes
        if case .text(let content) = box.node.type {
            let label = UILabel()
            label.text = content.trimmingCharacters(in: .whitespacesAndNewlines)
            label.font = UIFont.systemFont(ofSize: box.style.fontSize, weight: box.style.fontWeight)
            label.textColor = box.style.color
            label.textAlignment = box.style.textAlign
            label.numberOfLines = 0
            label.frame = CGRect(
                x: box.style.padding.left,
                y: box.style.padding.top,
                width: box.frame.width - box.style.padding.left - box.style.padding.right,
                height: box.frame.height - box.style.padding.top - box.style.padding.bottom
            )
            view.addSubview(label)
        }
        
        // Handle links
        if box.node.tagName == "a", let href = box.node.attributes["href"] {
            view.isUserInteractionEnabled = true
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(linkTapped(_:)))
            view.addGestureRecognizer(tapGesture)
            view.accessibilityIdentifier = href
        }
        
        // Handle images (simplified)
        if box.node.tagName == "img", let src = box.node.attributes["src"] {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.frame = view.bounds
            view.addSubview(imageView)
            
            // Load image asynchronously
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
        
        return view
    }
    
    @objc private func linkTapped(_ gesture: UITapGestureRecognizer) {
        if let href = gesture.view?.accessibilityIdentifier {
            NotificationCenter.default.post(
                name: NSNotification.Name("LinkTapped"),
                object: nil,
                userInfo: ["href": href]
            )
        }
    }
    
    // Extract embedded CSS from <style> tags
    private func extractEmbeddedStyles(from node: HTMLParser.DOMNode?) {
        guard let node = node else { return }
        
        if node.tagName == "style" {
            let css = node.textContent
            cssParser.parse(css)
        }
        
        for child in node.children {
            extractEmbeddedStyles(from: child)
        }
    }
    
    // Get text content from DOM
    public func getTextContent() -> String {
        return rootNode?.textContent ?? ""
    }
    
    // Find elements by tag name
    public func getElementsByTagName(_ tagName: String) -> [HTMLParser.DOMNode] {
        guard let root = rootNode else { return [] }
        return findElements(in: root) { $0.tagName?.lowercased() == tagName.lowercased() }
    }
    
    // Find elements matching a condition
    private func findElements(in node: HTMLParser.DOMNode, matching condition: (HTMLParser.DOMNode) -> Bool) -> [HTMLParser.DOMNode] {
        var results: [HTMLParser.DOMNode] = []
        
        if condition(node) {
            results.append(node)
        }
        
        for child in node.children {
            results.append(contentsOf: findElements(in: child, matching: condition))
        }
        
        return results
    }
}