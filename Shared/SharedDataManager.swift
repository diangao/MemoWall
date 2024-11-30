//
//  SharedDataManager.swift
//  MemoWall
//
//  Created by Diyan Gao on 11/30/24.
//

import Foundation
import SwiftData
import OSLog

@MainActor
class SharedDataManager {
    static let shared = SharedDataManager()
    private let groupIdentifier = "group.diangao.MemoWall"
    private let logger = Logger(subsystem: "group.diangao.MemoWall", category: "SharedDataManager")
    
    private var _sharedModelContainer: ModelContainer?
    
    var sharedModelContainer: ModelContainer? {
        if _sharedModelContainer == nil {
            do {
                let schema = Schema([Item.self])
                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    groupContainer: .identifier(groupIdentifier)
                )
                
                let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
                logger.debug("Container URL: \(containerURL?.path ?? "nil")")
                
                _sharedModelContainer = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
                logger.info("Successfully created ModelContainer")
                
                // 尝试立即保存一个空项目来验证存储
                let context = _sharedModelContainer?.mainContext
                let item = Item(text: "")
                context?.insert(item)
                try context?.save()
                context?.delete(item)
                try context?.save()
                logger.debug("Successfully verified storage access")
            } catch {
                logger.error("Failed to create ModelContainer: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    logger.error("Error domain: \(nsError.domain), code: \(nsError.code)")
                }
            }
        }
        return _sharedModelContainer
    }
    
    func getText() -> String {
        guard let container = sharedModelContainer else {
            logger.error("ModelContainer not available")
            return ""
        }
        
        let descriptor = FetchDescriptor<Item>()
        do {
            let items = try container.mainContext.fetch(descriptor)
            let text = items.first?.text ?? ""
            logger.debug("Successfully fetched text: \(text.prefix(20))...")
            return text
        } catch {
            logger.error("Failed to fetch text: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                logger.error("Error domain: \(nsError.domain), code: \(nsError.code)")
            }
            return ""
        }
    }
    
    func setText(_ text: String) {
        guard let container = sharedModelContainer else {
            logger.error("ModelContainer not available")
            return
        }
        
        let descriptor = FetchDescriptor<Item>()
        do {
            let items = try container.mainContext.fetch(descriptor)
            if let item = items.first {
                item.text = text
                item.timestamp = Date()
                logger.debug("Updated existing item")
            } else {
                let item = Item(text: text)
                container.mainContext.insert(item)
                logger.debug("Created new item")
            }
            
            try container.mainContext.save()
            logger.info("Successfully saved text")
        } catch {
            logger.error("Failed to save text: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                logger.error("Error domain: \(nsError.domain), code: \(nsError.code)")
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                    logger.error("Underlying error: \(underlyingError.localizedDescription)")
                }
            }
        }
    }
    
    private init() {}
}
