//
//  Untitled.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 14.01.26.
//


import SwiftUI
import CoreLocation
import GoogleMaps

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var status: CLAuthorizationStatus = .notDetermined
    @Published var heading: CLLocationDirection = 0

    override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = 2
        manager.headingOrientation = .portrait

        status = manager.authorizationStatus
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading > 0
            ? newHeading.trueHeading
            : newHeading.magneticHeading
    }
}




@MainActor
final class MapVM: ObservableObject {

    
    @Published var origin: CLLocationCoordinate2D?
    @Published var destination: CLLocationCoordinate2D?
    @Published var encodedPolyline: String?

    func setUserLocation(_ coordinate: CLLocationCoordinate2D) {
        origin = coordinate
    }

    func setDestination(_ coordinate: CLLocationCoordinate2D) {
        destination = coordinate
    }

    func startRoute() {
        print("🟦 startRoute tapped")
           print("origin:", origin?.latitude ?? -1, origin?.longitude ?? -1)
           print("dest:", destination?.latitude ?? -1, destination?.longitude ?? -1)

           guard let o = origin, let d = destination else {
               print("❌ Missing origin or destination")
               return
           }
           requestRoute(origin: o, destination: d)
    }
    
    func cancelRoute() {
           print("🟥 Route canceled")

           encodedPolyline = nil
           destination = nil
       }

    private func requestRoute(origin: CLLocationCoordinate2D,
                              destination: CLLocationCoordinate2D) {

        DirectionsService.fetchRoutePolyline(origin: origin, destination: destination) { [weak self] polyline in
            DispatchQueue.main.async {
                self?.encodedPolyline = polyline
            }
        }
    }
    
}

