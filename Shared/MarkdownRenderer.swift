import SwiftUI

struct MarkdownRenderer: View {
    let text: String
    let fontSize: CGFloat
    let isWidget: Bool
    
    init(text: String, fontSize: CGFloat = 14, isWidget: Bool = false) {
        self.text = text
        self.fontSize = fontSize
        self.isWidget = isWidget
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(text.components(separatedBy: .newlines), id: \.self) { line in
                let components = parseLine(line)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    // 渲染文本
                    Text(components.text)
                        .font(components.headingLevel > 0 ? 
                              getHeadingFont(level: components.headingLevel) :
                              .system(size: fontSize))
                    
                    // 渲染待办事项
                    if components.hasTodo {
                        Image(systemName: components.isChecked ? "checkmark.square" : "square")
                            .foregroundColor(isWidget ? .secondary : .primary)
                            .font(.system(size: components.headingLevel > 0 ? 
                                        getHeadingFontSize(level: components.headingLevel) * 0.7 : 
                                        fontSize))
                    }
                }
            }
        }
    }
    
    private struct LineComponents {
        var text: String
        var headingLevel: Int
        var hasTodo: Bool
        var isChecked: Bool
    }
    
    private func parseLine(_ line: String) -> LineComponents {
        var components = LineComponents(text: line, headingLevel: 0, hasTodo: false, isChecked: false)
        var processedText = line
        
        // 1. 首先处理标题
        if processedText.hasPrefix("### ") {
            components.headingLevel = 3
            processedText = String(processedText.dropFirst(4))
        } else if processedText.hasPrefix("## ") {
            components.headingLevel = 2
            processedText = String(processedText.dropFirst(3))
        } else if processedText.hasPrefix("# ") {
            components.headingLevel = 1
            processedText = String(processedText.dropFirst(2))
        }
        
        // 2. 处理待办事项（支持前置和后置）
        processedText = processedText.trimmingCharacters(in: .whitespaces)
        
        // 检查前置待办事项
        if processedText.hasPrefix("[]") {
            components.hasTodo = true
            components.isChecked = false
            processedText = String(processedText.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        } else if processedText.hasPrefix("[x]") {
            components.hasTodo = true
            components.isChecked = true
            processedText = String(processedText.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }
        // 检查后置待办事项
        else if processedText.hasSuffix(" []") {
            components.hasTodo = true
            components.isChecked = false
            processedText = String(processedText.dropLast(3)).trimmingCharacters(in: .whitespaces)
        } else if processedText.hasSuffix(" [x]") {
            components.hasTodo = true
            components.isChecked = true
            processedText = String(processedText.dropLast(4)).trimmingCharacters(in: .whitespaces)
        }
        
        components.text = processedText
        return components
    }
    
    private func getHeadingFontSize(level: Int) -> CGFloat {
        switch level {
        case 1: return fontSize * 2
        case 2: return fontSize * 1.5
        case 3: return fontSize * 1.2
        default: return fontSize
        }
    }
    
    private func getHeadingFont(level: Int) -> Font {
        .system(size: getHeadingFontSize(level: level),
                weight: level == 3 ? .semibold : .bold)
    }
}
