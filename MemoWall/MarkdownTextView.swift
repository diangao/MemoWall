import SwiftUI
import AppKit

struct MarkdownTextView: View {
    @Binding var text: String
    var isWidget: Bool
    
    init(text: Binding<String>, isWidget: Bool = false) {
        self._text = text
        self.isWidget = isWidget
    }
    
    var body: some View {
        if isWidget {
            MarkdownRenderedView(text: text, isWidget: true)
        } else {
            MacMarkdownTextView(text: $text)
        }
    }
}

struct MacMarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.font = .systemFont(ofSize: 14)
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.backgroundColor = .white
        textView.drawsBackground = true
        
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        textView.textContainerInset = NSSize(width: 10, height: 10)
        
        textView.string = text
        context.coordinator.applyMarkdownStyling(textView)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.applyMarkdownStyling(textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacMarkdownTextView
        private var isProcessingMarkdown = false
        
        init(_ parent: MacMarkdownTextView) {
            self.parent = parent
            super.init()
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isProcessingMarkdown else { return }
            
            isProcessingMarkdown = true
            defer { isProcessingMarkdown = false }
            
            let currentLineRange = getCurrentLineRange(textView)
            let currentLine = (textView.string as NSString).substring(with: currentLineRange)
            
            var newLine = currentLine
            
            if currentLine.contains("[] ") {
                newLine = newLine.replacingOccurrences(of: "[] ", with: "□ ")
            } else if currentLine.contains("[x] ") || currentLine.contains("[X] ") {
                newLine = newLine.replacingOccurrences(of: "[x] ", with: "☑ ", options: .caseInsensitive)
            }
            
            if newLine != currentLine {
                replaceText(textView, range: currentLineRange, with: newLine)
            }
            
            parent.text = textView.string
            applyMarkdownStyling(textView)
        }
        
        private func getCurrentLineRange(_ textView: NSTextView) -> NSRange {
            let selectedRange = textView.selectedRange()
            return (textView.string as NSString).lineRange(for: NSRange(location: selectedRange.location, length: 0))
        }
        
        private func replaceText(_ textView: NSTextView, range: NSRange, with newText: String) {
            let cursorPosition = textView.selectedRange().location
            textView.replaceCharacters(in: range, with: newText)
            
            let lengthDifference = range.length - newText.count
            let newPosition = max(range.location, cursorPosition - lengthDifference)
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        }
        
        // 解析行中的待办事项标记
        private func getTodoInfo(_ line: String) -> (hasTodo: Bool, todoRange: NSRange, remainingText: String) {
            let pattern = "^\\s*(□|☑)\\s"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return (false, NSRange(location: 0, length: 0), line)
            }
            
            if let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) {
                let todoRange = match.range
                let remainingText = (line as NSString).substring(from: todoRange.location + todoRange.length)
                return (true, todoRange, remainingText)
            }
            
            return (false, NSRange(location: 0, length: 0), line)
        }
        
        // 解析行中的标题标记
        private func getHeaderInfo(_ text: String) -> (isHeader: Bool, level: Int, hashRange: NSRange, contentRange: NSRange) {
            let pattern = "^\\s*(#+)\\s+"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return (false, 0, NSRange(location: 0, length: 0), NSRange(location: 0, length: 0))
            }
            
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
                let hashRange = match.range(at: 1)  // 获取#号的范围
                let fullMatchRange = match.range    // 获取包含空格的完整范围
                let level = hashRange.length        // #的数量就是标题级别
                
                // 计算内容的范围
                let contentStart = fullMatchRange.location + fullMatchRange.length
                let contentLength = text.count - contentStart
                let contentRange = NSRange(location: contentStart, length: contentLength)
                
                return (true, level, hashRange, contentRange)
            }
            
            return (false, 0, NSRange(location: 0, length: 0), NSRange(location: 0, length: 0))
        }
        
        func applyMarkdownStyling(_ textView: NSTextView) {
            let storage = textView.textStorage!
            let fullRange = NSRange(location: 0, length: storage.length)
            
            // 重置所有样式
            storage.removeAttribute(.font, range: fullRange)
            storage.removeAttribute(.foregroundColor, range: fullRange)
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: fullRange)
            storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
            
            let text = storage.string
            let lines = text.components(separatedBy: .newlines)
            var currentLocation = 0
            
            for line in lines {
                let lineLength = line.count
                guard lineLength > 0 else {
                    currentLocation += 1
                    continue
                }
                
                // 先处理待办事项
                let todoInfo = getTodoInfo(line)
                var textToCheck = todoInfo.remainingText
                var headerStartOffset = todoInfo.hasTodo ? todoInfo.todoRange.location + todoInfo.todoRange.length : 0
                
                // 再处理标题
                let headerInfo = getHeaderInfo(textToCheck)
                if headerInfo.isHeader {
                    // 计算实际的标题范围（考虑到待办事项的偏移）
                    let actualHashRange = NSRange(
                        location: currentLocation + headerStartOffset + headerInfo.hashRange.location,
                        length: headerInfo.hashRange.length
                    )
                    
                    // 删除#号和后面的空格
                    let attributedString = NSMutableAttributedString(string: storage.string)
                    let rangeToDelete = NSRange(
                        location: actualHashRange.location,
                        length: headerInfo.contentRange.location - headerInfo.hashRange.location
                    )
                    attributedString.deleteCharacters(in: rangeToDelete)
                    storage.setAttributedString(attributedString)
                    
                    // 更新行的范围（因为删除了字符）
                    lineLength -= rangeToDelete.length
                    
                    // 设置标题样式
                    let fontSize: CGFloat
                    switch headerInfo.level {
                    case 1: fontSize = 28
                    case 2: fontSize = 21
                    case 3: fontSize = 16.8
                    default: fontSize = 14
                    }
                    
                    let titleRange = NSRange(location: currentLocation, length: lineLength)
                    let font = NSFont.systemFont(ofSize: fontSize, weight: headerInfo.level <= 3 ? .bold : .regular)
                    storage.addAttribute(.font, value: font, range: titleRange)
                }
                
                currentLocation += lineLength + (currentLocation < storage.length ? 1 : 0)
            }
        }
    }
}
