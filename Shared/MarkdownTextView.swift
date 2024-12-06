import AppKit
import SwiftUI

// 共享的辅助函数
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

private func getHeaderInfo(_ text: String) -> (isHeader: Bool, level: Int, hashRange: NSRange, contentRange: NSRange) {
    // 修改正则表达式，使其能匹配标题标记，不管前面是否有 todo 标记
    let pattern = "^\\s*(#{1,6})\\s*"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
        return (false, 0, NSRange(location: 0, length: 0), NSRange(location: 0, length: 0))
    }
    
    if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
        let hashRange = match.range(at: 1)  // 获取#号的范围
        let level = hashRange.length        // #的数量就是标题级别
        
        // 计算内容的范围（从标题标记开始到行尾）
        let contentStart = hashRange.location + hashRange.length
        let contentLength = text.count - contentStart
        let contentRange = NSRange(location: contentStart, length: contentLength)
        
        return (true, level, hashRange, contentRange)
    }
    
    return (false, 0, NSRange(location: 0, length: 0), NSRange(location: 0, length: 0))
}

private func getLineNumber(for location: Int, in text: String) -> Int {
    let substring = (text as NSString).substring(to: location)
    return substring.components(separatedBy: .newlines).count - 1
}

private func getRangeOfLine(at lineNumber: Int, in text: String) -> NSRange {
    let lines = text.components(separatedBy: .newlines)
    var currentLocation = 0
    
    for (index, line) in lines.enumerated() {
        if index == lineNumber {
            return NSRange(location: currentLocation, length: line.count)
        }
        currentLocation += line.count + 1 // +1 for newline character
    }
    
    return NSRange(location: 0, length: 0)
}

// 日期处理辅助函数
private func getDateInfo(_ text: String) -> (hasDate: Bool, dateRange: NSRange, formattedDate: String) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMM d, yyyy"
    let calendar = Calendar.current
    let today = Date()
    
    // 匹配 @today, @tmr, @yesterday，后面必须跟空格
    if let match = text.range(of: "@(today|tmr|yesterday)\\s", options: .regularExpression) {
        let keyword = text[match].dropFirst().trimmingCharacters(in: .whitespaces) // 去掉@和空格
        let date: Date
        switch keyword {
        case "today":
            date = today
        case "tmr":
            date = calendar.date(byAdding: .day, value: 1, to: today)!
        case "yesterday":
            date = calendar.date(byAdding: .day, value: -1, to: today)!
        default:
            return (false, NSRange(location: 0, length: 0), "")
        }
        let nsRange = NSRange(match, in: text)
        return (true, nsRange, dateFormatter.string(from: date))
    }
    
    // 匹配 @dec 18 格式，必须以空格结尾
    let monthPattern = "@(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+(\\d{1,2})\\s"
    if let match = try? NSRegularExpression(pattern: monthPattern, options: [.caseInsensitive])
        .firstMatch(in: text, range: NSRange(location: 0, length: text.count)) {
        let monthStr = (text as NSString).substring(with: match.range(at: 1))
        let dayStr = (text as NSString).substring(with: match.range(at: 2))
        
        if let day = Int(dayStr) {
            var components = calendar.dateComponents([.year], from: today)
            components.day = day
            
            // 设置月份
            let months = ["jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
                         "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12]
            if let month = months[monthStr.lowercased()] {
                components.month = month
                
                if let date = calendar.date(from: components) {
                    return (true, match.range, dateFormatter.string(from: date))
                }
            }
        }
    }
    
    return (false, NSRange(location: 0, length: 0), "")
}

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var isWidget: Bool
    
    init(text: Binding<String>, isWidget: Bool = false) {
        self._text = text
        self.isWidget = isWidget
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        
        // Modern styling for the scroll view
        scrollView.scrollerStyle = .overlay
        scrollView.backgroundColor = .clear
        
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.font = .systemFont(ofSize: 15, weight: .regular)
        textView.isEditable = !isWidget
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        
        // Improved text container settings
        textView.textContainer?.lineFragmentPadding = 12
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        // Add comfortable padding
        textView.textContainerInset = NSSize(width: 16, height: 16)
        
        // Enable smooth text rendering
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        
        // Set default paragraph style for better text layout
        let defaultParagraphStyle = NSMutableParagraphStyle()
        defaultParagraphStyle.lineSpacing = 1.2 // Comfortable line spacing
        defaultParagraphStyle.paragraphSpacing = 8 // Space between paragraphs
        textView.defaultParagraphStyle = defaultParagraphStyle
        
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
        var parent: MarkdownTextView
        private var isProcessingMarkdown = false
        private var lineHeaderLevels: [Int: Int] = [:]
        
        // 统一的字体大小定义
        private enum HeaderStyle {
            static func fontSize(for level: Int) -> CGFloat {
                switch level {
                case 1: return 28  // # 一级标题
                case 2: return 21  // ## 二级标题
                case 3: return 16.8  // ### 三级标题
                default: return 14
                }
            }
        }
        
        init(_ parent: MarkdownTextView) {
            self.parent = parent
            super.init()
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isProcessingMarkdown else { return }
            
            isProcessingMarkdown = true
            defer { isProcessingMarkdown = false }
            
            let text = textView.string
            let currentLineRange = getCurrentLineRange(textView)
            let currentLine = (text as NSString).substring(with: currentLineRange)
            let currentLineNumber = getLineNumber(for: currentLineRange.location, in: text)
            
            print("Processing line \(currentLineNumber): '\(currentLine)'")
            
            // Check if current line is empty
            if currentLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if lineHeaderLevels[currentLineNumber] != nil {
                    print("Removing header level for empty line \(currentLineNumber)")
                    lineHeaderLevels.removeValue(forKey: currentLineNumber)
                    applyMarkdownStyling(textView)
                    return
                }
            }
            
            var newLine = currentLine
            
            // 处理日期快捷输入
            let dateInfo = getDateInfo(newLine)
            if dateInfo.hasDate {
                let dateRange = NSRange(location: currentLineRange.location + dateInfo.dateRange.location,
                                      length: dateInfo.dateRange.length)
                replaceText(textView, range: dateRange, with: dateInfo.formattedDate)
                newLine = (textView.string as NSString).substring(with: currentLineRange)
            }
            
            // 处理待办事项标记
            if currentLine.contains("[] ") {
                newLine = newLine.replacingOccurrences(of: "[] ", with: "□ ")
            } else if currentLine.contains("[x] ") || currentLine.contains("[X] ") {
                newLine = newLine.replacingOccurrences(of: "[x] ", with: "☑ ", options: .caseInsensitive)
            }
            
            // 检查标题标记
            let headerInfo = getHeaderInfo(newLine)
            let isHeader = headerInfo.isHeader
            let headerLevel = headerInfo.level
            
            // 如果是标题行
            if isHeader {
                print("Found header level \(headerLevel) at line \(currentLineNumber)")
                self.lineHeaderLevels[currentLineNumber] = headerLevel
                
                // 如果输入了空格，则删除标题标记但保持样式
                if let lastChar = newLine.last, lastChar == " " {
                    // 计算要删除的范围，包括标题标记和后面的空格
                    let hashRange = NSRange(location: currentLineRange.location + headerInfo.hashRange.location,
                                         length: headerInfo.hashRange.length)
                    let spaceRange = NSRange(location: hashRange.location + hashRange.length,
                                          length: 1)
                    
                    // 先删除空格，再删除标题标记
                    replaceText(textView, range: spaceRange, with: "")
                    replaceText(textView, range: hashRange, with: "")
                    return
                }
            }
            
            if newLine != currentLine {
                replaceText(textView, range: currentLineRange, with: newLine)
            }
            
            parent.text = textView.string
            applyMarkdownStyling(textView)
            
            print("Current header levels:", self.lineHeaderLevels)
        }
        
        private func getCurrentLineRange(_ textView: NSTextView) -> NSRange {
            let selectedRange = textView.selectedRange()
            return (textView.string as NSString).lineRange(for: NSRange(location: selectedRange.location, length: 0))
        }
        
        private func replaceText(_ textView: NSTextView, range: NSRange, with newText: String) {
            let cursorPosition = textView.selectedRange().location
            let selectionLength = textView.selectedRange().length
            
            textView.replaceCharacters(in: range, with: newText)
            
            // 计算新的光标位置
            let newPosition: Int
            if cursorPosition < range.location {
                // 光标在替换范围之前，保持不变
                newPosition = cursorPosition
            } else if cursorPosition <= range.location + range.length {
                // 光标在替换范围内，移动到替换文本之后
                newPosition = range.location + newText.count
            } else {
                // 光标在替换范围之后，根据文本长度差异调整位置
                let lengthDifference = range.length - newText.count
                newPosition = cursorPosition - lengthDifference
            }
            
            // 保持选中状态（如果有的话）
            textView.setSelectedRange(NSRange(location: newPosition, length: selectionLength))
        }
        
        func applyMarkdownStyling(_ textView: NSTextView) {
            let text = textView.string
            let storage = textView.textStorage!
            
            // 重置所有样式
            let fullRange = NSRange(location: 0, length: text.count)
            storage.removeAttribute(.font, range: fullRange)
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: fullRange)
            
            // 遍历所有标题行并应用样式
            for (lineNumber, headerLevel) in self.lineHeaderLevels {
                let lineRange = getRangeOfLine(at: lineNumber, in: text)
                if lineRange.length > 0 {
                    let fontSize = HeaderStyle.fontSize(for: headerLevel)
                    let font = NSFont.boldSystemFont(ofSize: fontSize)
                    storage.addAttribute(.font, value: font, range: lineRange)
                    
                    let line = (text as NSString).substring(with: lineRange)
                    print("Applied style - Line \(lineNumber): '\(line)' with level \(headerLevel)")
                }
            }
            
            // Style todo checkboxes
            text.enumerateLines { line, _ in
                let lineRange = (text as NSString).range(of: line)
                let todoInfo = getTodoInfo(line)
                if todoInfo.hasTodo {
                    // 只为复选框符号设置颜色
                    let checkboxRange = NSRange(location: lineRange.location, length: 1)
                    if line.contains("☑") {
                        storage.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: checkboxRange)
                    } else {
                        storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: checkboxRange)
                    }
                }
            }
        }
    }
}
