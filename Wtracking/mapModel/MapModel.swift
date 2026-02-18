//
//  MapModel.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 14.01.26.
//


import Foundation
import MapKit
import CoreLocation


struct MapPoint: Identifiable {
    var id: String          // stable id (UUID string or your own)
    let title: String
    let coordinate: CLLocationCoordinate2D
    let systemIcon: String
    let color: UIColor
    let isStartPoint: Bool
}


struct DirectionsResponse: Decodable {
    let status: String
    let error_message: String?
    let routes: [Route]
}

struct Route: Decodable {
    let overview_polyline: Polyline
    let legs: [Leg]
}

struct Polyline: Decodable { let points: String }

struct Leg: Decodable {
    let distance: Distance
    let duration: Duration
    let duration_in_traffic: Duration?
}

struct Distance: Decodable { let text: String; let value: Int }
struct Duration: Decodable { let text: String; let value: Int }


struct RouteInfo {
    let polyline: String
    let durationText: String
    let durationSeconds: Int
    let distanceText: String
    let distanceMeters: CLLocationDistance   
}





struct DrivenRoute: Identifiable, Codable {
    let id: String
    let startedAt: Date
    let finishedAt: Date
    let points: [CodableCoordinate]

    var durationSeconds: Int {
        Int(finishedAt.timeIntervalSince(startedAt))
    }
}

struct CodableCoordinate: Codable {
    let lat: Double
    let lng: Double

    var cl: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }

    init(_ c: CLLocationCoordinate2D) {
        self.lat = c.latitude
        self.lng = c.longitude
    }
}
