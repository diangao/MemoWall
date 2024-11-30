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
    var timestamp: Date
    var text: String
    
    init(text: String = "", timestamp: Date = Date()) {
        self.text = text
        self.timestamp = timestamp
    }
}
