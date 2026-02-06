import SwiftUI
import GoogleMaps
import CoreLocation


struct GoogleMapView: UIViewRepresentable {
    @ObservedObject var locationManager: LocationManager
    let places: [MapPoint]
    @Binding var selectedPlace: MapPoint?
    @Binding var routePolylineEncoded: String?
    @Binding var isNavigating: Bool
    @Binding var focusPlaceId: String?




    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(latitude: 41.7151, longitude: 44.8271, zoom: 10)

        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.settings.compassButton = true
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {

        let allowed = locationManager.status == .authorizedWhenInUse ||
                      locationManager.status == .authorizedAlways

        
        mapView.isMyLocationEnabled = allowed && !isNavigating
        mapView.settings.myLocationButton = allowed && !isNavigating


        if allowed,
           let loc = locationManager.location,
           !context.coordinator.didInitialSetup {

            context.coordinator.didInitialSetup = true

            mapView.animate(to: GMSCameraPosition(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                zoom: 13
            ))
        }

        context.coordinator.syncPlaceMarkers(on: mapView, places: places, selectedId: selectedPlace?.id)


        if context.coordinator.lastPolyline != routePolylineEncoded {
            context.coordinator.drawRoute(on: mapView, encodedPolyline: routePolylineEncoded)
        }
        
        if let user = locationManager.location?.coordinate {

            context.coordinator.followUserIfNeeded(
                on: mapView,
                user: user,
                heading: locationManager.heading,   // ✅ PASS HEADING
                isNavigating: isNavigating
            )
            
            context.coordinator.updateUserMarker(
                    on: mapView,
                    coordinate: user,
                    heading: locationManager.heading,
                    isNavigating: isNavigating
                )
            
            context.coordinator.syncPlaceMarkers(
                on: mapView,
                places: places,
                selectedId: selectedPlace?.id          // ✅ NEW
            )
            
            context.coordinator.focusIfNeeded(
                on: mapView,
                placeId: focusPlaceId,
                places: places
            )
        }

    }

}


struct DirectionsResponse: Decodable {
    let status: String
    let error_message: String?
    let routes: [Route]

    struct Route: Decodable {
        let overview_polyline: OverviewPolyline
    }
    struct OverviewPolyline: Decodable {
        let points: String
    }
}



enum DirectionsService {

    static func fetchRoutePolyline(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        completion: @escaping (String?) -> Void
    ) {
        let key = "AIzaSyBVxXerW3VER0l3aZmc30dnulT843eAEKQ"

        // Use URLComponents to avoid bad URL encoding
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/directions/json")!
        components.queryItems = [
            .init(name: "origin", value: "\(origin.latitude),\(origin.longitude)"),
            .init(name: "destination", value: "\(destination.latitude),\(destination.longitude)"),
            .init(name: "mode", value: "driving"),
            .init(name: "key", value: key)
        ]

        guard let url = components.url else {
            print("❌ Directions: bad URL")
            completion(nil)
            return
        }

        print("➡️ Directions URL:", url.absoluteString)

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error {
                print("❌ Directions network error:", error.localizedDescription)
                completion(nil)
                return
            }

            guard let data else {
                print("❌ Directions: no data")
                completion(nil)
                return
            }

            do {
                let decoded = try JSONDecoder().decode(DirectionsResponse.self, from: data)

                if decoded.status != "OK" {
                    print("❌ Directions status:", decoded.status)
                    print("❌ Directions error_message:", decoded.error_message ?? "nil")
                    completion(nil)
                    return
                }

                let points = decoded.routes.first?.overview_polyline.points
                print("✅ Polyline received:", points?.prefix(40) ?? "nil")
                completion(points)

            } catch {
                print("❌ Directions decode error:", error)
                print("RAW:", String(data: data, encoding: .utf8) ?? "nil")
                completion(nil)
            }
        }.resume()
    }
}




final class Coordinator: NSObject, GMSMapViewDelegate {
    private let parent: GoogleMapView
    private var markersById: [String: GMSMarker] = [:]
    private var userMarker: GMSMarker?
    private var placeByMarkerId: [ObjectIdentifier: MapPoint] = [:]
    private var lastRouteBounds: GMSCoordinateBounds?
    private var lastFocusedId: String?

    var didInitialSetup = false
    private var destinationMarker: GMSMarker?
    private var routePolyline: GMSPolyline?
    var lastPolyline: String?

    init(_ parent: GoogleMapView) {
        self.parent = parent
    }

    func ensureDestinationMarker(on mapView: GMSMapView, destination: CLLocationCoordinate2D) {
        if destinationMarker == nil {
            let marker = GMSMarker(position: destination)
            marker.title = "Destination"
            marker.map = mapView
            destinationMarker = marker
        } else {
            destinationMarker?.position = destination
        }
    }
    
    func syncPlaceMarkers(
        on mapView: GMSMapView,
        places: [MapPoint],
        selectedId: String?
    ) {

        let newIds = Set(places.map(\.id))
        let oldIds = Set(markersById.keys)

        // Remove deleted markers
        for id in oldIds.subtracting(newIds) {
            if let marker = markersById[id] {
                marker.map = nil
                placeByMarkerId.removeValue(forKey: ObjectIdentifier(marker))
            }
            markersById.removeValue(forKey: id)
        }

        // Add / Update markers
        for place in places {

            let isSelected = (place.id == selectedId)

            // ✅ Different size for selected marker
            let icon = UIImage.mapSymbol(
                name: place.systemIcon,
                pointSize: isSelected ? 26 : 20,
                color: place.color,
                backgroundColor: .white,
                padding: isSelected ? 12 : 10
            )

            let marker: GMSMarker

            if let existing = markersById[place.id] {
                marker = existing
            } else {
                marker = GMSMarker()
                markersById[place.id] = marker
            }

            marker.position = place.coordinate
            marker.title = place.title
            marker.icon = icon
            marker.zIndex = isSelected ? 1000 : 0   // ✅ bring selected to front
            marker.map = mapView

            placeByMarkerId[ObjectIdentifier(marker)] = place
        }
    }


    func drawRoute(on mapView: GMSMapView, encodedPolyline: String?) {
        lastPolyline = encodedPolyline

        routePolyline?.map = nil
        lastRouteBounds = nil

        guard let encodedPolyline,
              let path = GMSPath(fromEncodedPath: encodedPolyline) else { return }

        let polyline = GMSPolyline(path: path)
        polyline.strokeWidth = 5
        polyline.geodesic = true
        polyline.map = mapView
        routePolyline = polyline

        let bounds = GMSCoordinateBounds(path: path)
        lastRouteBounds = bounds
        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 90))
    }


    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        if let place = placeByMarkerId[ObjectIdentifier(marker)] {
                DispatchQueue.main.async {
                    self.parent.selectedPlace = place
                }
                return true
            }

            return false
    }
    
    func updateUserMarker(on mapView: GMSMapView,
                          coordinate: CLLocationCoordinate2D,
                          heading: CLLocationDirection,
                          isNavigating: Bool) {

        guard isNavigating else {
            userMarker?.map = nil
            userMarker = nil
            return
        }

        let icon = UIImage.mapSymbol(
            name: "location.north.fill",
            pointSize: 24,
            color: .systemBlue,
            backgroundColor: .white,
            padding: 12            
        )

        if userMarker == nil {
            let m = GMSMarker(position: coordinate)
            m.icon = icon
            m.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            m.map = mapView
            userMarker = m
        } else {
            userMarker?.position = coordinate
            userMarker?.icon = icon
        }

        // ✅ rotate marker (icon rotates, not whole map)
        userMarker?.rotation = heading
        userMarker?.isFlat = true
    }

    
    func followUserIfNeeded(on mapView: GMSMapView, user: CLLocationCoordinate2D, heading: CLLocationDirection, isNavigating: Bool) {
        guard isNavigating else { return }

        let camera = GMSCameraPosition(
            target: user,
            zoom: 17,
            bearing: heading,
            viewingAngle: 45
        )

        mapView.animate(with: GMSCameraUpdate.setCamera(camera))
    }
    
    
    func focusIfNeeded(on mapView: GMSMapView, placeId: String?, places: [MapPoint]) {
        guard let placeId, placeId != lastFocusedId else { return }
        guard let p = places.first(where: { $0.id == placeId }) else { return }

        lastFocusedId = placeId

        mapView.animate(with: GMSCameraUpdate.setTarget(p.coordinate, zoom: 14))
    }
}
