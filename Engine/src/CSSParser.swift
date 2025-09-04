import Foundation
import UIKit

// CSS Parser and Styling Engine
public class CSSParser {
    
    // CSS Rule structure
    public struct CSSRule {
        let selector: String
        let properties: [String: String]
        let specificity: Int
        
        func matches(_ node: HTMLParser.DOMNode) -> Bool {
            // Simple selector matching
            let parts = selector.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
            
            for part in parts {
                if part.hasPrefix("#") {
                    // ID selector
                    let id = String(part.dropFirst())
                    return node.attributes["id"] == id
                } else if part.hasPrefix(".") {
                    // Class selector
                    let className = String(part.dropFirst())
                    let classes = node.attributes["class"]?.components(separatedBy: .whitespaces) ?? []
                    return classes.contains(className)
                } else if part.contains("[") {
                    // Attribute selector (simplified)
                    return false // TODO: Implement
                } else {
                    // Tag selector
                    return node.tagName?.lowercased() == part.lowercased()
                }
            }
            
            return false
        }
    }
    
    // Computed style for a node
    public class ComputedStyle {
        var properties: [String: String] = [:]
        
        // Common properties with defaults
        var display: String { properties["display"] ?? "block" }
        var color: UIColor { parseColor(properties["color"] ?? "#000000") }
        var backgroundColor: UIColor { parseColor(properties["background-color"] ?? "transparent") }
        var fontSize: CGFloat { parseSize(properties["font-size"] ?? "16px") }
        var fontWeight: UIFont.Weight { parseFontWeight(properties["font-weight"] ?? "normal") }
        var textAlign: NSTextAlignment { parseTextAlign(properties["text-align"] ?? "left") }
        var margin: UIEdgeInsets { parseInsets(properties["margin"] ?? "0") }
        var padding: UIEdgeInsets { parseInsets(properties["padding"] ?? "0") }
        var border: CGFloat { parseSize(properties["border-width"] ?? "0") }
        var width: CGFloat? { properties["width"].map { parseSize($0) } }
        var height: CGFloat? { properties["height"].map { parseSize($0) } }
        
        private func parseColor(_ value: String) -> UIColor {
            if value == "transparent" { return .clear }
            
            // Handle hex colors
            if value.hasPrefix("#") {
                let hex = String(value.dropFirst())
                var rgb: UInt64 = 0
                Scanner(string: hex).scanHexInt64(&rgb)
                
                if hex.count == 6 {
                    return UIColor(
                        red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
                        green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
                        blue: CGFloat(rgb & 0xFF) / 255.0,
                        alpha: 1.0
                    )
                }
            }
            
            // Handle named colors
            switch value.lowercased() {
            case "black": return .black
            case "white": return .white
            case "red": return .red
            case "green": return .green
            case "blue": return .blue
            case "yellow": return .yellow
            case "gray", "grey": return .gray
            default: return .black
            }
        }
        
        private func parseSize(_ value: String) -> CGFloat {
            if value.hasSuffix("px") {
                return CGFloat(Double(value.dropLast(2)) ?? 0)
            } else if value.hasSuffix("em") {
                return CGFloat(Double(value.dropLast(2)) ?? 0) * 16
            } else if value.hasSuffix("%") {
                return CGFloat(Double(value.dropLast(1)) ?? 0) / 100.0
            } else {
                return CGFloat(Double(value) ?? 0)
            }
        }
        
        private func parseFontWeight(_ value: String) -> UIFont.Weight {
            switch value.lowercased() {
            case "bold", "700": return .bold
            case "light", "300": return .light
            case "thin", "100": return .thin
            case "medium", "500": return .medium
            case "semibold", "600": return .semibold
            case "heavy", "800", "900": return .heavy
            default: return .regular
            }
        }
        
        private func parseTextAlign(_ value: String) -> NSTextAlignment {
            switch value.lowercased() {
            case "center": return .center
            case "right": return .right
            case "justify": return .justified
            default: return .left
            }
        }
        
        private func parseInsets(_ value: String) -> UIEdgeInsets {
            let parts = value.components(separatedBy: .whitespaces).map { parseSize($0) }
            
            switch parts.count {
            case 1:
                let v = parts[0]
                return UIEdgeInsets(top: v, left: v, bottom: v, right: v)
            case 2:
                return UIEdgeInsets(top: parts[0], left: parts[1], bottom: parts[0], right: parts[1])
            case 4:
                return UIEdgeInsets(top: parts[0], left: parts[3], bottom: parts[2], right: parts[1])
            default:
                return .zero
            }
        }
    }
    
    private var rules: [CSSRule] = []
    
    public init() {
        // Add default browser styles
        addDefaultStyles()
    }
    
    // Parse CSS string
    public func parse(_ css: String) {
        var currentSelector = ""
        var currentProperties: [String: String] = [:]
        var inRule = false
        
        let lines = css.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
                continue
            }
            
            if trimmed.contains("{") {
                currentSelector = trimmed.replacingOccurrences(of: "{", with: "").trimmingCharacters(in: .whitespaces)
                inRule = true
                currentProperties = [:]
            } else if trimmed.contains("}") {
                if inRule && !currentSelector.isEmpty {
                    rules.append(CSSRule(
                        selector: currentSelector,
                        properties: currentProperties,
                        specificity: calculateSpecificity(currentSelector)
                    ))
                }
                inRule = false
                currentSelector = ""
            } else if inRule && trimmed.contains(":") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2 {
                    let property = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                    var value = parts[1...].joined(separator: ":")
                        .trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: ";", with: "")
                    currentProperties[property] = value
                }
            }
        }
    }
    
    // Get computed style for a DOM node
    public func getComputedStyle(for node: HTMLParser.DOMNode) -> ComputedStyle {
        let style = ComputedStyle()
        
        // Apply matching rules in order of specificity
        let matchingRules = rules
            .filter { $0.matches(node) }
            .sorted { $0.specificity < $1.specificity }
        
        for rule in matchingRules {
            for (property, value) in rule.properties {
                style.properties[property] = value
            }
        }
        
        // Apply inline styles
        if let inlineStyle = node.attributes["style"] {
            parseInlineStyle(inlineStyle, into: style)
        }
        
        return style
    }
    
    private func parseInlineStyle(_ styleString: String, into style: ComputedStyle) {
        let declarations = styleString.components(separatedBy: ";")
        
        for declaration in declarations {
            let parts = declaration.components(separatedBy: ":")
            if parts.count >= 2 {
                let property = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let value = parts[1...].joined(separator: ":")
                    .trimmingCharacters(in: .whitespaces)
                style.properties[property] = value
            }
        }
    }
    
    private func calculateSpecificity(_ selector: String) -> Int {
        var specificity = 0
        
        // Count IDs (weight: 100)
        specificity += selector.components(separatedBy: "#").count - 1 * 100
        
        // Count classes (weight: 10)
        specificity += selector.components(separatedBy: ".").count - 1 * 10
        
        // Count elements (weight: 1)
        let elements = selector.components(separatedBy: .whitespaces)
        specificity += elements.filter { !$0.hasPrefix("#") && !$0.hasPrefix(".") }.count
        
        return specificity
    }
    
    private func addDefaultStyles() {
        // Default HTML styles
        let defaultCSS = """
        body { margin: 8px; font-family: -apple-system; font-size: 16px; }
        h1 { font-size: 32px; font-weight: bold; margin: 16px 0; }
        h2 { font-size: 24px; font-weight: bold; margin: 14px 0; }
        h3 { font-size: 18px; font-weight: bold; margin: 12px 0; }
        p { margin: 10px 0; }
        a { color: #007AFF; text-decoration: underline; }
        strong, b { font-weight: bold; }
        em, i { font-style: italic; }
        ul, ol { margin: 10px 0; padding-left: 20px; }
        li { margin: 4px 0; }
        blockquote { margin: 10px 20px; color: #666; }
        code { background-color: #f5f5f5; padding: 2px 4px; font-family: monospace; }
        pre { background-color: #f5f5f5; padding: 10px; overflow-x: auto; }
        img { max-width: 100%; height: auto; }
        div { display: block; }
        span { display: inline; }
        """
        
        parse(defaultCSS)
    }
}