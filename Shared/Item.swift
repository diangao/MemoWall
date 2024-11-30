//
//  Item.swift
//  MemoWall
//
//  Created by Diyan Gao on 11/14/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    @Attribute(.unique) var id: String
    var timestamp: Date
    var text: String
    
    init(text: String = "", timestamp: Date = Date()) {
        self.id = UUID().uuidString
        self.text = text
        self.timestamp = timestamp
    }
}

// MARK: - Codable
extension Item: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case text
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let text = try container.decode(String.self, forKey: .text)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.init(text: text, timestamp: timestamp)
        self.id = try container.decode(String.self, forKey: .id)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(text, forKey: .text)
    }
}
