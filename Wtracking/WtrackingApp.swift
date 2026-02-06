//
//  WtrackingApp.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 14.01.26.
//

import SwiftUI
import GoogleMaps


@main
struct WtrackingApp: App {
    init() {
            GMSServices.provideAPIKey("AIzaSyADxKX5-G-flVEhDl8e8La9NeaD4bZ8ckI")
        }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

