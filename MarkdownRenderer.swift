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
                if line.hasPrefix("# ") && !line.hasPrefix("## ") {
                    Text(line.replacingOccurrences(of: "^# ", with: "", options: .regularExpression))
                        .font(.system(size: fontSize * 2, weight: .bold))
                } else if line.hasPrefix("## ") && !line.hasPrefix("### ") {
                    Text(line.replacingOccurrences(of: "^## ", with: "", options: .regularExpression))
                        .font(.system(size: fontSize * 1.5, weight: .bold))
                } else if line.hasPrefix("### ") {
                    Text(line.replacingOccurrences(of: "^### ", with: "", options: .regularExpression))
                        .font(.system(size: fontSize * 1.2, weight: .semibold))
                } else if line.contains("[]") || line.contains("[x]") {
                    HStack(spacing: 4) {
                        Image(systemName: line.contains("[x]") ? "checkmark.square" : "square")
                            .foregroundColor(isWidget ? .secondary : .primary)
                        Text(line.replacingOccurrences(of: "\\[[ x]\\]", with: "", options: .regularExpression)
                            .trimmingCharacters(in: .whitespaces))
                            .font(.system(size: fontSize))
                    }
                } else {
                    Text(line)
                        .font(.system(size: fontSize))
                }
            }
        }
    }
}
