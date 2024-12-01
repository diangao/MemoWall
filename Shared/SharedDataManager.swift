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
    
    func initializeModelContainer() async throws {
        if modelContainer == nil {
            do {
                // 首先验证 App Group 权限
                guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) else {
                    logger.error("❌ Failed to get container URL for group: \(self.groupIdentifier)")
                    throw NSError(
                        domain: "SharedDataManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "App Group access denied. Please check entitlements."]
                    )
                }
                
                logger.debug("📂 Container URL: \(containerURL.path)")
                
                // 验证目录权限
                let testFile = containerURL.appendingPathComponent("test.txt")
                do {
                    try "test".write(to: testFile, atomically: true, encoding: .utf8)
                    try FileManager.default.removeItem(at: testFile)
                    logger.debug("✅ Directory write permission verified")
                } catch {
                    logger.error("❌ Directory write test failed: \(error.localizedDescription)")
                    throw NSError(
                        domain: "SharedDataManager",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Directory write permission denied"]
                    )
                }
                
                // 创建 Schema 和 ModelConfiguration
                let schema = Schema([Item.self])
                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    groupContainer: .identifier(groupIdentifier)
                )
                
                // 创建 ModelContainer
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
                
                // 验证数据库访问
                if let context = modelContainer?.mainContext {
                    let item = Item(text: "")
                    context.insert(item)
                    try context.save()
                    context.delete(item)
                    try context.save()
                    logger.debug("✅ Database access verified")
                } else {
                    logger.error("❌ Failed to get context from ModelContainer")
                    throw NSError(
                        domain: "SharedDataManager",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to access database context"]
                    )
                }
                
                logger.info("✅ Successfully initialized ModelContainer")
                
            } catch {
                logger.error("❌ Initialization failed: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    logger.error("Error domain: \(nsError.domain), code: \(nsError.code)")
                    if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                        logger.error("Underlying error: \(underlyingError)")
                    }
                }
                throw error
            }
        }
    }
    
    func getText() async throws -> String {
        try await initializeModelContainer()
        
        guard let context = modelContainer?.mainContext else {
            logger.error("No context available")
            throw NSError(
                domain: "SharedDataManager",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Database context not available"]
            )
        }
        
        do {
            let descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
            let items = try context.fetch(descriptor)
            let text = items.first?.text ?? ""
            logger.debug("Successfully fetched text: \(text.prefix(20))...")
            return text
        } catch {
            logger.error("Failed to fetch text: \(error.localizedDescription)")
            throw error
        }
    }
    
    func setText(_ text: String) async throws {
        try await initializeModelContainer()
        
        guard let context = modelContainer?.mainContext else {
            logger.error("No context available")
            throw NSError(
                domain: "SharedDataManager",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Database context not available"]
            )
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
            logger.debug("Successfully saved text")
        } catch {
            logger.error("Failed to save text: \(error.localizedDescription)")
            throw error
        }
    }
}
