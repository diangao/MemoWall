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
    private let logger = Logger(subsystem: "group.diangao.MemoWall", category: "SharedDataManager")
    
    private var modelContainer: ModelContainer?
    var sharedModelContainer: ModelContainer? { modelContainer }
    
    private init() {}
    
    @MainActor
    func initializeModelContainer() async throws {
        if modelContainer == nil {
            do {
                // 使用内存存储配置
                let schema = Schema([Item.self])
                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true  // 使用内存存储
                )
                
                // 创建 ModelContainer
                do {
                    modelContainer = try ModelContainer(
                        for: schema,
                        configurations: [modelConfiguration]
                    )
                    logger.info("✅ Successfully initialized ModelContainer")
                    
                    // 从 UserDefaults 恢复数据
                    await loadFromUserDefaults()
                    
                } catch {
                    logger.error("❌ Failed to create ModelContainer: \(error.localizedDescription)")
                    throw NSError(
                        domain: "SharedDataManager",
                        code: -2,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to create ModelContainer",
                            "NSLocalFailureReason": error.localizedDescription,
                            NSUnderlyingErrorKey: error
                        ]
                    )
                }
            } catch {
                logger.error("❌ Initialization failed: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    logger.error("Error domain: \(nsError.domain), code: \(nsError.code)")
                    if let reason = nsError.userInfo["NSLocalFailureReason"] as? String {
                        logger.error("Failure reason: \(reason)")
                    }
                    if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                        logger.error("Underlying error: \(underlyingError)")
                    }
                }
                throw error
            }
        }
    }
    
    // 获取 UserDefaults
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.diangao.MemoWall")
    }
    
    // 保存数据到 UserDefaults
    @MainActor
    func saveToUserDefaults() async {
        guard let context = modelContainer?.mainContext else { return }
        do {
            let items = try context.fetch(FetchDescriptor<Item>())
            if let lastItem = items.last {
                sharedDefaults?.set(lastItem.text, forKey: "MemoWallText")
                logger.debug("✅ Saved text to UserDefaults")
            }
        } catch {
            logger.error("❌ Failed to save to UserDefaults: \(error.localizedDescription)")
        }
    }
    
    // 从 UserDefaults 加载数据
    @MainActor
    private func loadFromUserDefaults() async {
        guard let context = modelContainer?.mainContext,
              let text = sharedDefaults?.string(forKey: "MemoWallText") else { return }
        
        do {
            let item = Item(text: text)
            context.insert(item)
            try context.save()
            logger.debug("✅ Loaded text from UserDefaults")
        } catch {
            logger.error("❌ Failed to load from UserDefaults: \(error.localizedDescription)")
        }
    }
    
    var container: ModelContainer? {
        modelContainer
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
            await saveToUserDefaults()
        } catch {
            logger.error("Failed to save text: \(error.localizedDescription)")
            throw error
        }
    }
}
