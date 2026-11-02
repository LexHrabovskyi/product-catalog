//
//  Item.swift
//  Product catalog
//
//  Created by Lex Hrabovskyi on 2026-11-02.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
