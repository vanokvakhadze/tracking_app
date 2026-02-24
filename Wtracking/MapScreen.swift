//
//  MapScreen.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 24.02.26.
//

import SwiftUI
import GoogleMaps
import SwiftData

struct MapScreen: View {
    @Environment(\.modelContext) private var context
    @StateObject var mapVM = MapVM()

    @State private var showStartAlert = false
    @State private var startAlertWasShown = false

    var body: some View {
        StarterMapView(
            mapVM: mapVM,
            context: context,
            startAlertWasShown: $startAlertWasShown
        )
        .ignoresSafeArea()
        .onAppear {
            // თუ ჯერ არ გვაქვს არცერთი ადგილი → ვაჩვენოთ მხოლოდ ერთხელ
            if mapVM.places.isEmpty && !startAlertWasShown {
                showStartAlert = true
            }
        }
        .alert("მონიშნეთ საწყისი წერტილი", isPresented: $showStartAlert) {
            Button("კარგი") {
                startAlertWasShown = true
            }
        } message: {
            Text("გთხოვთ მონიშნოთ თქვენი ზუსტი ლოკაცია, საიდანაც დაიწყებთ და დაასრულებთ მოძრაობას.")
        }
    }
}




struct StarterMapView: UIViewRepresentable {
    @ObservedObject var mapVM: MapVM
    var context: ModelContext
    @Binding var startAlertWasShown: Bool

    func makeCoordinator() -> StartingMap { StartingMap(self) }

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(latitude: 41.7151, longitude: 44.8271, zoom: 12)
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) { }
}



final class StartingMap: NSObject, GMSMapViewDelegate {
    private let parent: StarterMapView
    private var markersById: [String: GMSMarker] = [:]

    init(_ parent: StarterMapView) {
        self.parent = parent
    }

    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        reverseGeocode(coordinate) { [weak self] address in
            guard let self else { return }

            Task { @MainActor in
                self.savePoint(
                    coordinate: coordinate,
                    address: address ?? "",
                    mapView: mapView
                )
            }
        }
    }

    @MainActor
    private func savePoint(coordinate: CLLocationCoordinate2D, address: String, mapView: GMSMapView) {

        let isFirst = parent.mapVM.places.isEmpty

        let point = MapPoint(
            id: UUID().uuidString,
            title: isFirst ? "Start Point" : "Place \(parent.mapVM.places.count + 1)",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            isStartPoint: isFirst,
            imageName: isFirst ? "start" : "pin",
            adress: address,
            lastDate: Date()
        )

        parent.context.insert(point)

        do {
            try parent.context.save()
        } catch {
            print("❌ SwiftData save error:", error)
            return
        }

        // თუ places-ს შენ თვითონ აკონტროლებ:
        parent.mapVM.places.append(point)

        addMarker(on: mapView, place: point)
    }

    // ✅ Create marker
    private func addMarker(on mapView: GMSMapView, place: MapPoint) {
        let marker = GMSMarker(position: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
        marker.title = place.title
        marker.snippet = place.adress
        marker.map = mapView
        markersById[place.id] = marker
    }

    func syncPlaceMarkers(on mapView: GMSMapView, places: [MapPoint]) {
        let ids = Set(places.map { $0.id })
        for (id, marker) in markersById where !ids.contains(id) {
            marker.map = nil
            markersById.removeValue(forKey: id)
        }
        // add new
        for p in places where markersById[p.id] == nil {
            addMarker(on: mapView, place: p)
        }
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let geocoder = GMSGeocoder()
        geocoder.reverseGeocodeCoordinate(coordinate) { response, error in
            if let error { print("geocode error:", error); completion(nil); return }
            let result = response?.firstResult()
            let lines = result?.lines ?? []
            completion(lines.joined(separator: ", "))
        }
    }
}
