//
//  MapModel.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 14.01.26.
//


import Foundation
import MapKit
import CoreLocation
import SwiftData

@Model
final class MapPoint {
    @Attribute(.unique) var id: String
    var title: String
    var latitude: Double
    var longitude: Double
    var isStartPoint: Bool
    var imageName: String
    var adress: String
    var date: Date?

    var imagePath: String?   // ✅ ლოკალური ფაილის სახელი/path

    init(id: String,
         title: String,
         latitude: Double,
         longitude: Double,
         isStartPoint: Bool,
         imageName: String,
         adress: String,
         lastDate: Date? = nil,
         imagePath: String? = nil) {
        self.id = id
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.isStartPoint = isStartPoint
        self.imageName = imageName
        self.adress = adress
        self.date = lastDate
        self.imagePath = imagePath
    }
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
    let expiresAt: Date
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
struct PlaceStay: Identifiable, Codable {
    let id: String
    let title: String
    let seconds: TimeInterval
}


struct NavigationSession: Codable {
    var isNavigating: Bool
    var destinationLat: Double?
    var destinationLng: Double?
    var targetPlaceId: String?
    var targetRadius: Double
    var encodedPolyline: String?
}


import UIKit

enum ImageStore {
    static func saveJPEG(_ data: Data, fileName: String) throws -> String {
        let url = try documentsURL().appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic])
        return fileName
    }

    static func load(_ fileName: String) -> UIImage? {
        guard let url = try? documentsURL().appendingPathComponent(fileName) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func delete(_ fileName: String) {
        guard let url = try? documentsURL().appendingPathComponent(fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func documentsURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true)
    }
    

    static func url(for fileName: String) -> URL {
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)
        }
    
}
