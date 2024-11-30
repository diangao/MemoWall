#if os(iOS)
import UIKit
#else
import AppKit
#endif
import SwiftUI

#if os(iOS)
struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    var isWidget: Bool
    
    init(text: Binding<String>, isWidget: Bool = false) {
        self._text = text
        self.isWidget = isWidget
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 14)
        textView.isEditable = !isWidget
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.text = text
        context.coordinator.applyMarkdownStyling(textView)
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            let selectedRange = textView.selectedRange
            textView.text = text
            textView.selectedRange = selectedRange
            context.coordinator.applyMarkdownStyling(textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView
        private var isProcessingMarkdown = false
        
        init(_ parent: MarkdownTextView) {
            self.parent = parent
            super.init()
        }
        
        func textViewDidChange(_ textView: UITextView) {
            guard !isProcessingMarkdown else { return }
            
            isProcessingMarkdown = true
            defer { isProcessingMarkdown = false }
            
            // 获取当前行
            let currentLineRange = getCurrentLineRange(textView)
            let currentLine = (textView.text as NSString).substring(with: currentLineRange)
            
            // 处理待办事项和标题的组合
            var newLine = currentLine
            
            // 检查并处理待办事项标记
            if currentLine.contains("[] ") {
                newLine = newLine.replacingOccurrences(of: "[] ", with: "□ ")
            } else if currentLine.contains("[x] ") || currentLine.contains("[X] ") {
                newLine = newLine.replacingOccurrences(of: "[x] ", with: "☑ ", options: .caseInsensitive)
            }
            
            // 如果有任何改变，更新文本
            if newLine != currentLine {
                replaceText(textView, range: currentLineRange, with: newLine)
            }
            
            parent.text = textView.text
            applyMarkdownStyling(textView)
        }
        
        private func getCurrentLineRange(_ textView: UITextView) -> NSRange {
            let cursorPosition = textView.selectedRange.location
            let text = textView.text as NSString
            return text.lineRange(for: NSRange(location: cursorPosition, length: 0))
        }
        
        private func replaceText(_ textView: UITextView, range: NSRange, with newText: String) {
            let cursorPosition = textView.selectedRange.location
            textView.replace(textView.textRange(from: textView.position(from: textView.beginningOfDocument, offset: range.location)!, to: textView.position(from: textView.beginningOfDocument, offset: range.location + range.length)!)!, withText: newText)
            
            // 调整光标位置
            let lengthDifference = range.length - newText.count
            let newPosition = max(range.location, cursorPosition - lengthDifference)
            textView.selectedRange = NSRange(location: newPosition, length: 0)
        }
        
        func applyMarkdownStyling(_ textView: UITextView) {
            let attributedText = NSMutableAttributedString(string: textView.text)
            let fullRange = NSRange(location: 0, length: attributedText.length)
            
            // 重置所有样式
            attributedText.removeAttribute(.font, range: fullRange)
            attributedText.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: fullRange)
            
            let text = textView.text
            let lines = text.components(separatedBy: .newlines)
            var currentLocation = 0
            
            for line in lines {
                guard line.count > 0 else {
                    currentLocation += 1
                    continue
                }
                
                let lineRange = NSRange(location: currentLocation, length: line.count)
                
                // 检查标题标记
                var headingFont: UIFont? = nil
                if line.contains("### ") {
                    headingFont = .systemFont(ofSize: 16.8, weight: .semibold)
                } else if line.contains("## ") {
                    headingFont = .systemFont(ofSize: 21, weight: .bold)
                } else if line.contains("# ") {
                    headingFont = .systemFont(ofSize: 28, weight: .bold)
                }
                
                // 应用样式
                if let font = headingFont {
                    attributedText.addAttribute(.font, value: font, range: lineRange)
                } else {
                    attributedText.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: lineRange)
                }
                
                // 如果是小组件，使用浅色文本
                if parent.isWidget {
                    attributedText.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: lineRange)
                }
                
                currentLocation += line.count + (currentLocation < attributedText.length ? 1 : 0)
            }
            
            textView.attributedText = attributedText
        }
    }
}
#else
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
        
        // 配置滚动视图
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        
        // 配置文本视图
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.font = .systemFont(ofSize: 14)
        textView.isEditable = !isWidget
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        
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
            
            // 处理待办事项和标题的组合
            var newLine = currentLine
            
            // 检查并处理待办事项标记
            if currentLine.contains("[] ") {
                newLine = newLine.replacingOccurrences(of: "[] ", with: "□ ")
            } else if currentLine.contains("[x] ") || currentLine.contains("[X] ") {
                newLine = newLine.replacingOccurrences(of: "[x] ", with: "☑ ", options: .caseInsensitive)
            }
            
            // 如果有任何改变，更新文本
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
                
                // 检查标题标记
                var headingFont: NSFont? = nil
                if line.contains("### ") {
                    headingFont = NSFont.systemFont(ofSize: 16.8, weight: .semibold)
                } else if line.contains("## ") {
                    headingFont = NSFont.systemFont(ofSize: 21, weight: .bold)
                } else if line.contains("# ") {
                    headingFont = NSFont.systemFont(ofSize: 28, weight: .bold)
                }
                
                // 应用样式
                if let font = headingFont {
                    storage.addAttribute(.font, value: font, range: lineRange)
                } else {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: lineRange)
                }
                
                // 如果是小组件，使用浅色文本
                if parent.isWidget {
                    storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: lineRange)
                }
                
                currentLocation += line.count + (currentLocation < storage.length ? 1 : 0)
            }
        }
    }
}
#endif
