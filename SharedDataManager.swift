//
//  SharedDataManager1.swift
//  MemoWall
//
//  Created by Diyan Gao on 11/30/24.
//

import Foundation
import SwiftData

class SharedDataManager {
    static let shared = SharedDataManager()
    
    private let groupIdentifier = "group.diangao.MemoWall"
    
    var sharedModelContainer: ModelContainer? = {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.diangao.MemoWall") else {
            print("Failed to get App Group container URL")
            return nil
        }
        
        // 创建一个固定的存储 URL
        let storageURL = groupURL.appending(path: "shared.store")
        
        // 配置 schema 和 model
        let schema = Schema([Item.self])
        let modelConfiguration = ModelConfiguration(schema: schema, url: storageURL)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("Successfully created ModelContainer at: \(storageURL.path)")
            return container
        } catch {
            print("Error creating shared ModelContainer: \(error)")
            return nil
        }
    }()
    
    private init() {}
    
    func saveText(_ text: String) {
        guard let container = sharedModelContainer else {
            print("Error: ModelContainer not available")
            return
        }
        let context = ModelContext(container)
        
        // 获取或创建 Item
        let fetchDescriptor = FetchDescriptor<Item>()
        do {
            let items = try context.fetch(fetchDescriptor)
            let item: Item
            if let existingItem = items.first {
                item = existingItem
                item.text = text
            } else {
                item = Item(text: text)
                context.insert(item)
            }
            try context.save()
            print("Successfully saved text")
        } catch {
            print("Error saving text: \(error)")
        }
    }
    
    func getText() -> String {
        guard let container = sharedModelContainer else {
            print("Error: ModelContainer not available")
            return ""
        }
        let context = ModelContext(container)
        
        let fetchDescriptor = FetchDescriptor<Item>()
        do {
            let items = try context.fetch(fetchDescriptor)
            return items.first?.text ?? ""
        } catch {
            print("Error fetching text: \(error)")
            return ""
        }
    }
}
