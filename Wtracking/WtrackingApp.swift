//
//  WtrackingApp.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 14.01.26.
//

import SwiftUI
import GoogleMaps
import SwiftData


@main
struct WtrackingApp: App {
    init() {
            GMSServices.provideAPIKey("AIzaSyADxKX5-G-flVEhDl8e8La9NeaD4bZ8ckI")
        }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [MapPoint.self, PlaceVisitModel.self])
    }
}

