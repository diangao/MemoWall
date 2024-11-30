import SwiftUI

struct MarkdownRenderedView: View {
    let text: String
    var isWidget: Bool
    
    init(text: String, isWidget: Bool = false) {
        self.text = text
        self.isWidget = isWidget
    }
    
    var body: some View {
        if isWidget {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(text.components(separatedBy: .newlines), id: \.self) { line in
                    if !line.isEmpty {
                        Text(line)
                            .font(fontForLine(line))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(text.components(separatedBy: .newlines), id: \.self) { line in
                        if !line.isEmpty {
                            Text(line)
                                .font(fontForLine(line))
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
        }
    }
    
    private func fontForLine(_ line: String) -> Font {
        if line.contains("### ") {
            return .system(.title3, design: .default).weight(.semibold)
        } else if line.contains("## ") {
            return .system(.title2, design: .default).weight(.bold)
        } else if line.contains("# ") {
            return .system(.title, design: .default).weight(.bold)
        } else {
            return .system(.body, design: .default)
        }
    }
}
