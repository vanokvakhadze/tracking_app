//
//  PlaceData.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 20.02.26.
//

import SwiftData
import SwiftUI

@Model

final class PlaceVisitModel {
    var id: String
    var placeId: String
    var title: String
    var enteredAt: Date
    var exitedAt: Date?
    var seconds: Double?
    var expiresAt: Date

    init(placeId: String, title: String, enteredAt: Date) {
        self.id = UUID().uuidString
        self.placeId = placeId
        self.title = title
        self.enteredAt = enteredAt
        self.exitedAt = nil
        self.seconds = nil
        self.expiresAt = enteredAt.addingTimeInterval(24 * 3600)
    }
}
