import SwiftUI
import AppKit

struct MarkdownTextView: View {
    @Binding var text: String
    var isWidget: Bool
    @EnvironmentObject private var appDelegate: AppDelegate
    
    init(text: Binding<String>, isWidget: Bool = false) {
        self._text = text
        self.isWidget = isWidget
    }
    
    var body: some View {
        if isWidget {
            MarkdownRenderedView(text: text, isWidget: true)
        } else {
            MacMarkdownTextView(text: $text)
                .environmentObject(appDelegate)
        }
    }
}

// 添加一个自定义的 NSTextStorage 子类
class MarkdownTextStorage: NSTextStorage {
    private var storage = NSMutableAttributedString()
    var fontSize: CGFloat {
        didSet {
            if oldValue != fontSize {
                applyStyles()
            }
        }
    }
    
    init(fontSize: CGFloat) {
        self.fontSize = fontSize
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var string: String {
        return storage.string
    }
    
    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        return storage.attributes(at: location, effectiveRange: range)
    }
    
    override func replaceCharacters(in range: NSRange, with str: String) {
        print("Replacing characters in range: \(range) with string of length: \(str.count)")
        beginEditing()
        storage.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
        endEditing()
        applyStyles()
    }
    
    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        beginEditing()
        storage.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }
    
    private func applyStyles() {
        print("Applying styles with font size: \(fontSize)")
        let text = storage.string
        let fullRange = NSRange(location: 0, length: length)
        
        // 重置所有样式
        beginEditing()
        
        // 设置基础字体和颜色
        let baseFont = NSFont.systemFont(ofSize: fontSize)
        setAttributes([
            .font: baseFont,
            .foregroundColor: NSColor.textColor
        ], range: fullRange)
        
        // 处理每一行
        var currentLocation = 0
        text.enumerateLines { line, _ in
            let lineLength = line.count
            let lineRange = NSRange(location: currentLocation, length: lineLength)
            
            // 处理标题
            if let headerLevel = self.getHeaderLevel(from: line) {
                let headerSize = self.fontSize * (headerLevel == 1 ? 2.0 :
                                               headerLevel == 2 ? 1.5 :
                                               headerLevel == 3 ? 1.2 : 1.0)
                let headerFont = NSFont.boldSystemFont(ofSize: headerSize)
                self.addAttribute(.font, value: headerFont, range: lineRange)
            }
            
            // 处理待办事项
            if line.hasPrefix("□ ") || line.hasPrefix("☑ ") {
                let checkboxRange = NSRange(location: lineRange.location, length: 2)
                self.addAttribute(.foregroundColor, value: NSColor.systemGray, range: checkboxRange)
            }
            
            // 更新位置，加1是为了包含换行符
            currentLocation += lineLength + 1
        }
        
        endEditing()
        
        // 通知布局管理器重新布局
        layoutManagers.forEach { manager in
            manager.ensureLayout(for: manager.textContainers.first!)
        }
    }
    
    private func getHeaderLevel(from line: String) -> Int? {
        // 确保即使前面有空行也能匹配标题
        let pattern = "^[ \t]*(#{1,6})\\s+"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        if let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) {
            let hashRange = match.range(at: 1)
            let hashCount = (line as NSString).substring(with: hashRange).count
            return hashCount
        }
        return nil
    }
    
    func updateFontSize(_ newSize: CGFloat) {
        print("Updating font size from \(fontSize) to \(newSize)")
        fontSize = newSize
    }
}

struct MacMarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    @EnvironmentObject private var appDelegate: AppDelegate
    private var textStorage: MarkdownTextStorage?
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacMarkdownTextView
        weak var textView: NSTextView?
        private var isProcessingMarkdown = false
        private var lineHeaderLevels: [Int: Int] = [:]
        
        init(_ parent: MacMarkdownTextView) {
            self.parent = parent
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
            
            // 获取当前行的前一个状态
            let selectedRange = textView.selectedRange()
            let lastChar = selectedRange.location > 0 ? (text as NSString).substring(with: NSRange(location: selectedRange.location - 1, length: 1)) : ""
            let isNewLine = lastChar == "\n"
            let previousText = selectedRange.location > 1 ? (text as NSString).substring(with: NSRange(location: selectedRange.location - 2, length: 1)) : ""
            
            // 检查当前行是否为空，以及是否是通过删除内容导致的空行
            let isEmptyLine = currentLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let isContentDeleted = isEmptyLine && !isNewLine && previousText != "\n"
            
            if isNewLine {
                // 如果是按回车键插入新行，将当前行的标题级别（如果有）向下移动一行
                if let currentLevel = lineHeaderLevels[currentLineNumber - 1] {
                    lineHeaderLevels[currentLineNumber] = currentLevel
                    lineHeaderLevels.removeValue(forKey: currentLineNumber - 1)
                    
                    // 更新后续行的标题级别
                    var updatedLevels: [Int: Int] = [:]
                    for (line, level) in lineHeaderLevels where line > currentLineNumber {
                        updatedLevels[line + 1] = level
                    }
                    for (line, level) in updatedLevels {
                        lineHeaderLevels[line] = level
                    }
                }
            } else if isContentDeleted {
                // 只有当行是通过删除内容变成空行时，才移除标题级别
                lineHeaderLevels.removeValue(forKey: currentLineNumber)
            }
            
            // 检查标题标记
            let headerInfo = getHeaderInfo(currentLine)
            if headerInfo.isHeader {
                print("Found header level \(headerInfo.level) at line \(currentLineNumber)")
                lineHeaderLevels[currentLineNumber] = headerInfo.level
                
                // 如果输入了空格，则删除标题标记但保持样式
                if lastChar == " " {
                    let hashRange = NSRange(location: currentLineRange.location + headerInfo.hashRange.location,
                                         length: headerInfo.hashRange.length + 1)
                    replaceText(textView, range: hashRange, with: "")
                }
            }
            
            parent.text = textView.string
            applyMarkdownStyling(textView)
            
            print("Current header levels:", self.lineHeaderLevels)
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            // 保持选择状态不变
        }
        
        // Helper functions
        private func getCurrentLineRange(_ textView: NSTextView) -> NSRange {
            let selectedRange = textView.selectedRange()
            return (textView.string as NSString).lineRange(for: NSRange(location: selectedRange.location, length: 0))
        }
        
        private func getLineNumber(for location: Int, in text: String) -> Int {
            let substring = (text as NSString).substring(to: location)
            return substring.components(separatedBy: .newlines).count - 1
        }
        
        private func getHeaderInfo(_ line: String) -> (isHeader: Bool, level: Int, hashRange: NSRange) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            var headerLevel = 0
            
            // 计算连续的 # 数量
            for char in trimmedLine {
                if char == "#" {
                    headerLevel += 1
                } else {
                    break
                }
            }
            
            // 确保 # 后面有空格
            if headerLevel > 0 && headerLevel <= 6 {
                if trimmedLine.count > headerLevel {
                    let nextChar = trimmedLine[trimmedLine.index(trimmedLine.startIndex, offsetBy: headerLevel)]
                    if nextChar == " " {
                        let hashRange = NSRange(location: line.distance(from: line.startIndex, to: line.firstIndex(of: "#") ?? line.startIndex),
                                              length: headerLevel)
                        return (true, headerLevel, hashRange)
                    }
                }
            }
            
            return (false, 0, NSRange())
        }
        
        private func replaceText(_ textView: NSTextView, range: NSRange, with newText: String) {
            let cursorPosition = textView.selectedRange().location
            textView.replaceCharacters(in: range, with: newText)
            
            let lengthDifference = range.length - newText.count
            let newPosition = max(range.location, cursorPosition - lengthDifference)
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        }
        
        private func applyMarkdownStyling(_ textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let text = textView.string
            
            // 重置所有样式
            let fullRange = NSRange(location: 0, length: text.count)
            storage.removeAttribute(.font, range: fullRange)
            storage.removeAttribute(.foregroundColor, range: fullRange)
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: fullRange)
            
            // 遍历所有标题行并应用样式
            var currentLine = 0
            text.enumerateLines { line, _ in
                // 如果这一行有标题级别，应用相应的样式
                if let headerLevel = self.lineHeaderLevels[currentLine] {
                    let lineRange = (text as NSString).lineRange(for: NSRange(location: (text as NSString).range(of: line).location, length: 0))
                    if lineRange.length > 0 {
                        let fontSize = 24 - (headerLevel * 2) // h1: 22, h2: 20, h3: 18, etc.
                        let font = NSFont.boldSystemFont(ofSize: CGFloat(fontSize))
                        storage.addAttribute(.font, value: font, range: lineRange)
                        print("Applied style - Line \(currentLine): '\(line)' with level \(headerLevel)")
                    }
                }
                currentLine += 1
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        
        // 创建文本存储和布局系统
        let storage = MarkdownTextStorage(fontSize: appDelegate.fontSize)
        textStorage = storage
        
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer()
        layoutManager.addTextContainer(textContainer)
        
        // 配置文本容器
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        
        // 创建和配置文本视图
        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        context.coordinator.textView = textView
        textView.delegate = context.coordinator
        
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        scrollView.documentView = textView
        
        // 设置初始文本
        if !text.isEmpty {
            storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: text)
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView,
              let storage = textStorage else { return }
        
        // 更新字体大小
        if storage.fontSize != appDelegate.fontSize {
            print("Updating font size to: \(appDelegate.fontSize)")
            storage.updateFontSize(appDelegate.fontSize)
        }
        
        // 更新文本内容（如果需要）
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
            textView.selectedRanges = selectedRanges
        }
    }
}
