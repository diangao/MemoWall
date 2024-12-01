import SwiftUI

struct MarkdownRenderedView: View {
    let text: String
    var isWidget: Bool
    
    init(text: String, isWidget: Bool = false) {
        self.text = text
        self.isWidget = isWidget
    }
    
    var body: some View {
        let lines = text.components(separatedBy: .newlines)
        let content = VStack(alignment: .leading, spacing: isWidget ? 2 : 4) {
            ForEach(Array(zip(lines.indices, lines)), id: \.0) { _, line in
                if !line.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if line.hasPrefix("□ ") || line.hasPrefix("☑ ") {
                            Image(systemName: line.hasPrefix("☑ ") ? "checkmark.square" : "square")
                                .foregroundColor(isWidget ? .secondary : .primary)
                            Text(String(line.dropFirst(2)))
                                .font(.system(.body))
                        } else {
                            Text(parseMarkdownLine(line))
                                .font(fontForLine(line))
                        }
                    }
                    .lineLimit(isWidget ? 1 : nil)
                    .if(!isWidget) { view in
                        view.textSelection(.enabled)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        if isWidget {
            content
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        } else {
            ScrollView {
                content.padding(10)
            }
        }
    }
    
    private func parseMarkdownLine(_ line: String) -> String {
        // 移除 Markdown 标记但保留内容
        var text = line
        if text.hasPrefix("### ") {
            text = String(text.dropFirst(4))
        } else if text.hasPrefix("## ") {
            text = String(text.dropFirst(3))
        } else if text.hasPrefix("# ") {
            text = String(text.dropFirst(2))
        }
        return text
    }
    
    private func fontForLine(_ line: String) -> Font {
        if isWidget {
            if line.hasPrefix("### ") {
                return .system(.subheadline, design: .default).weight(.semibold)
            } else if line.hasPrefix("## ") {
                return .system(.headline, design: .default).weight(.bold)
            } else if line.hasPrefix("# ") {
                return .system(.title3, design: .default).weight(.bold)
            } else {
                return .system(.footnote, design: .default)
            }
        } else {
            if line.hasPrefix("### ") {
                return .system(.title3, design: .default).weight(.semibold)
            } else if line.hasPrefix("## ") {
                return .system(.title2, design: .default).weight(.bold)
            } else if line.hasPrefix("# ") {
                return .system(.title, design: .default).weight(.bold)
            } else {
                return .system(.body, design: .default)
            }
        }
    }
}

// 添加条件修饰符扩展
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
