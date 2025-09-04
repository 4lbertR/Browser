import Foundation

// HTML Parser - Converts HTML string into a DOM tree
public class HTMLParser {
    
    // DOM Node types
    public enum NodeType {
        case element(String)  // Tag name
        case text(String)     // Text content
        case comment(String)  // HTML comment
        case doctype
    }
    
    // DOM Node structure
    public class DOMNode {
        var type: NodeType
        var attributes: [String: String] = [:]
        var children: [DOMNode] = []
        weak var parent: DOMNode?
        
        init(type: NodeType) {
            self.type = type
        }
        
        func appendChild(_ node: DOMNode) {
            node.parent = self
            children.append(node)
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
    
    // Main parse function
    public func parse() -> DOMNode {
        let root = DOMNode(type: .element("html"))
        
        // Skip DOCTYPE if present
        skipWhitespace()
        if peek(string: "<!DOCTYPE") || peek(string: "<!doctype") {
            skipUntil(">")
            advance()
        }
        
        // Parse the HTML content
        while !isAtEnd() {
            skipWhitespace()
            if isAtEnd() { break }
            
            if let node = parseNode() {
                root.appendChild(node)
            }
        }
        
        return root
    }
    
    private func parseNode() -> DOMNode? {
        skipWhitespace()
        
        if peek(string: "<!--") {
            return parseComment()
        } else if peek(char: "<") {
            return parseElement()
        } else {
            return parseText()
        }
    }
    
    private func parseElement() -> DOMNode? {
        guard consume(char: "<") else { return nil }
        
        // Check for closing tag
        if peek(char: "/") {
            // Skip closing tag
            skipUntil(">")
            advance()
            return nil
        }
        
        // Parse tag name
        let tagName = parseTagName()
        if tagName.isEmpty { return nil }
        
        let node = DOMNode(type: .element(tagName.lowercased()))
        
        // Parse attributes
        skipWhitespace()
        while !isAtEnd() && !peek(char: ">") && !peek(string: "/>") {
            if let (key, value) = parseAttribute() {
                node.attributes[key] = value
            }
            skipWhitespace()
        }
        
        // Self-closing tag
        if consume(string: "/>") {
            return node
        }
        
        // Regular tag
        consume(char: ">")
        
        // Void elements (self-closing in HTML5)
        let voidElements = ["area", "base", "br", "col", "embed", "hr", "img", 
                           "input", "link", "meta", "param", "source", "track", "wbr"]
        if voidElements.contains(tagName.lowercased()) {
            return node
        }
        
        // Parse children
        while !isAtEnd() {
            skipWhitespace()
            
            // Check for closing tag
            if peek(string: "</\(tagName)") || peek(string: "</\(tagName.lowercased())") {
                skipUntil(">")
                advance()
                break
            }
            
            if let child = parseNode() {
                node.appendChild(child)
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
        
        if text.isEmpty { return nil }
        
        // Decode HTML entities
        text = decodeHTMLEntities(text)
        
        return DOMNode(type: .text(text))
    }
    
    private func parseComment() -> DOMNode? {
        guard consume(string: "<!--") else { return nil }
        
        var comment = ""
        while !isAtEnd() && !peek(string: "-->") {
            comment.append(current())
            advance()
        }
        
        consume(string: "-->")
        return DOMNode(type: .comment(comment))
    }
    
    private func parseTagName() -> String {
        var name = ""
        
        while !isAtEnd() {
            let char = current()
            if char.isWhitespace || char == ">" || char == "/" {
                break
            }
            name.append(char)
            advance()
        }
        
        return name
    }
    
    private func parseAttribute() -> (String, String)? {
        skipWhitespace()
        
        // Parse attribute name
        var name = ""
        while !isAtEnd() {
            let char = current()
            if char.isWhitespace || char == "=" || char == ">" || char == "/" {
                break
            }
            name.append(char)
            advance()
        }
        
        if name.isEmpty { return nil }
        
        skipWhitespace()
        
        // Check for value
        if !consume(char: "=") {
            return (name.lowercased(), "")
        }
        
        skipWhitespace()
        
        // Parse attribute value
        var value = ""
        if peek(char: "\"") || peek(char: "'") {
            let quote = current()
            advance()
            
            while !isAtEnd() && current() != quote {
                value.append(current())
                advance()
            }
            advance() // Skip closing quote
        } else {
            // Unquoted attribute value
            while !isAtEnd() {
                let char = current()
                if char.isWhitespace || char == ">" {
                    break
                }
                value.append(char)
                advance()
            }
        }
        
        return (name.lowercased(), decodeHTMLEntities(value))
    }
    
    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        
        let entities = [
            "&lt;": "<",
            "&gt;": ">",
            "&amp;": "&",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&#39;": "'",
            "&#x27;": "'",
            "&#x2F;": "/",
            "&#60;": "<",
            "&#62;": ">"
        ]
        
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        return result
    }
    
    // Helper functions
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
    
    private func consume(string: String) -> Bool {
        if peek(string: string) {
            for _ in string {
                advance()
            }
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
    
    private func skipUntil(_ string: String) {
        while !isAtEnd() && !peek(string: string) {
            advance()
        }
    }
    
    private func isAtEnd() -> Bool {
        return position >= html.endIndex
    }
}