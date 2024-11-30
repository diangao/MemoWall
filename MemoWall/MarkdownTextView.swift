import SwiftUI
import AppKit
import RegexBuilder

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // 配置滚动视图
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        
        // 配置文本视图
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.font = .systemFont(ofSize: 14)
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.backgroundColor = .white
        textView.drawsBackground = true
        
        // 允许自动换行
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        
        // 启用自动布局
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        // 设置文本容器的内边距
        textView.textContainerInset = NSSize(width: 10, height: 10)
        
        // 初始化文本
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
        
        init(_ parent: MarkdownTextView) {
            self.parent = parent
            super.init()
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isProcessingMarkdown else { return }
            
            isProcessingMarkdown = true
            defer { isProcessingMarkdown = false }
            
            // 获取当前行
            let currentLineRange = getCurrentLineRange(textView)
            let currentLine = (textView.string as NSString).substring(with: currentLineRange)
            
            // 处理待办事项，先移除可能的标题标记
            var processedLine = currentLine
            if processedLine.hasPrefix("### ") {
                processedLine = String(processedLine.dropFirst(4))
            } else if processedLine.hasPrefix("## ") {
                processedLine = String(processedLine.dropFirst(3))
            } else if processedLine.hasPrefix("# ") {
                processedLine = String(processedLine.dropFirst(2))
            }
            
            // 检查是否包含待办事项标记
            if processedLine.hasPrefix("[] ") {
                let newLine = currentLine.replacingOccurrences(of: "[] ", with: "□ ")
                replaceText(textView, range: currentLineRange, with: newLine)
            }
            else if processedLine.hasPrefix("[x] ") || processedLine.hasPrefix("[X] ") {
                let newLine = currentLine.replacingOccurrences(of: "[x] ", with: "☑ ", options: .caseInsensitive)
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
            
            // 调整光标位置
            let lengthDifference = range.length - newText.count
            let newPosition = max(range.location, cursorPosition - lengthDifference)
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        }
        
        func applyMarkdownStyling(_ textView: NSTextView) {
            let storage = textView.textStorage!
            let fullRange = NSRange(location: 0, length: storage.length)
            
            // 重置所有样式
            storage.removeAttribute(.font, range: fullRange)
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: fullRange)
            
            let text = storage.string
            let lines = text.components(separatedBy: .newlines)
            var currentLocation = 0
            
            for line in lines {
                guard line.count > 0 else {
                    currentLocation += 1
                    continue
                }
                
                let lineRange = NSRange(location: currentLocation, length: line.count)
                
                // 应用样式
                if line.hasPrefix("### ") {
                    let font = NSFont.systemFont(ofSize: 16.8, weight: .semibold)
                    storage.addAttribute(.font, value: font, range: lineRange)
                } else if line.hasPrefix("## ") {
                    let font = NSFont.systemFont(ofSize: 21, weight: .bold)
                    storage.addAttribute(.font, value: font, range: lineRange)
                } else if line.hasPrefix("# ") {
                    let font = NSFont.systemFont(ofSize: 28, weight: .bold)
                    storage.addAttribute(.font, value: font, range: lineRange)
                } else if line.hasPrefix("□ ") || line.hasPrefix("☑ ") {
                    let font = NSFont.systemFont(ofSize: 14)
                    storage.addAttribute(.font, value: font, range: lineRange)
                } else {
                    let font = NSFont.systemFont(ofSize: 14)
                    storage.addAttribute(.font, value: font, range: lineRange)
                }
                
                currentLocation += line.count + (currentLocation < storage.length ? 1 : 0)
            }
        }
    }
}
