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
    
    private var modelContainer: ModelContainer?
    var sharedModelContainer: ModelContainer? { modelContainer }
    
    private init() {}
    
    func initializeModelContainer() async {
        if modelContainer == nil {
            do {
                let schema = Schema([Item.self])
                let groupId = self.groupIdentifier
                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    groupContainer: .identifier(groupId)
                )
                
                if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) {
                    logger.debug("Container URL: \(containerURL.path)")
                    
                    modelContainer = try ModelContainer(
                        for: schema,
                        configurations: [modelConfiguration]
                    )
                    logger.info("Successfully created ModelContainer")
                    
                    // 验证存储访问
                    if let context = modelContainer?.mainContext {
                        let item = Item(text: "")
                        context.insert(item)
                        try context.save()
                        context.delete(item)
                        try context.save()
                        logger.debug("Successfully verified storage access")
                    }
                } else {
                    logger.error("Failed to get container URL for group: \(groupId)")
                }
            } catch {
                logger.error("Failed to create ModelContainer: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    logger.error("Error domain: \(nsError.domain), code: \(nsError.code)")
                }
            }
        }
    }
    
    func getText() async -> String {
        await initializeModelContainer()
        
        guard let context = modelContainer?.mainContext else {
            logger.error("No context available")
            return ""
        }
        
        do {
            let descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
            let items = try context.fetch(descriptor)
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
    
    func setText(_ text: String) async {
        await initializeModelContainer()
        
        guard let context = modelContainer?.mainContext else {
            logger.error("No context available")
            return
        }
        
        do {
            let descriptor = FetchDescriptor<Item>()
            let items = try context.fetch(descriptor)
            
            if let item = items.first {
                item.text = text
                item.timestamp = Date()
                logger.debug("Updated existing item")
            } else {
                let item = Item(text: text)
                context.insert(item)
                logger.debug("Created new item")
            }
            
            try context.save()
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
}
