import SwiftUI
import GoogleMaps
import CoreLocation


struct GoogleMapView: UIViewRepresentable {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var mapVM: MapVM
    @Binding var routePolylineEncoded: String?
    @Binding var isNavigating: Bool
    @Binding var focusPlaceId: String?
    @Binding var shouldCenter: Bool





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
        mapView.settings.compassButton = true
        mapView.settings.myLocationButton = false   
        mapView.settings.scrollGestures = true
        mapView.settings.zoomGestures = true
        mapView.settings.rotateGestures = true
        mapView.settings.tiltGestures = true
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

        context.coordinator.syncPlaceMarkers(
            on: mapView,
            places: mapVM.places,
            selectedId: mapVM.selectedPlace?.id
        )

        if context.coordinator.lastPolyline != routePolylineEncoded {
            context.coordinator.drawRoute(on: mapView, encodedPolyline: routePolylineEncoded)
        }
        
        if shouldCenter, let user = locationManager.location?.coordinate {
            context.coordinator.centerOnUser(mapView, user: user, heading: locationManager.heading, isNavigating: isNavigating)
            DispatchQueue.main.async { self.shouldCenter = false }
        }

        guard let user = locationManager.location?.coordinate else { return }

        if isNavigating {
            context.coordinator.followUserIfNeeded(
                on: mapView,
                user: user,
                heading: locationManager.heading,
                isNavigating: true
            )

            context.coordinator.updateUserMarker(
                on: mapView,
                coordinate: user,
                heading: locationManager.heading,
                isNavigating: true
            )

            context.coordinator.updateRouteProgress(user: user)

        } else {
            context.coordinator.focusIfNeeded(
                on: mapView,
                placeId: focusPlaceId,
                places: mapVM.places
            )

            context.coordinator.updateUserMarker(
                on: mapView,
                coordinate: user,
                heading: locationManager.heading,
                isNavigating: false
            )
        }
    }

}





enum DirectionsService {

    static func fetchRoute(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        completion: @escaping (RouteInfo?) -> Void
    ) {
        let key = "AIzaSyBVxXerW3VER0l3aZmc30dnulT843eAEKQ"

        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/directions/json")!
        components.queryItems = [
            .init(name: "origin", value: "\(origin.latitude),\(origin.longitude)"),
            .init(name: "destination", value: "\(destination.latitude),\(destination.longitude)"),
            .init(name: "mode", value: "driving"),
            .init(name: "alternatives", value: "true"),
            .init(name: "departure_time", value: "now"),
            .init(name: "traffic_model", value: "best_guess"),
            .init(name: "language", value: "en"),
            .init(name: "units", value: "metric"),
            .init(name: "region", value: "ge"),
            .init(name: "key", value: key)
        ]

        guard let url = components.url else {
            print("❌ Directions: bad URL")
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
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

                guard decoded.status == "OK" else {
                    print("❌ Directions status:", decoded.status)
                    print("❌ Directions error_message:", decoded.error_message ?? "nil")
                    completion(nil)
                    return
                }

                guard let route = decoded.routes.first,
                      let leg = route.legs.first else {
                    completion(nil)
                    return
                }

                let duration = leg.duration_in_traffic ?? leg.duration

                completion(RouteInfo(
                    polyline: route.overview_polyline.points,
                    durationText: duration.text,
                    durationSeconds: duration.value,
                    distanceText: leg.distance.text,
                    distanceMeters: CLLocationDistance(leg.distance.value)
                ))

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
    private var routePath: GMSPath?
    private var traveledPolyline: GMSPolyline?
    private var remainingPolyline: GMSPolyline?
    private var lastFocusedPlaceId: String?
    private var isFollowingUser = true



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

        for id in oldIds.subtracting(newIds) {
            if let marker = markersById[id] {
                marker.map = nil
                placeByMarkerId.removeValue(forKey: ObjectIdentifier(marker))
            }
            markersById.removeValue(forKey: id)
        }

        for place in places {

            let isSelected = (place.id == selectedId)

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
            marker.zIndex = isSelected ? 1000 : 0
            marker.map = mapView

            placeByMarkerId[ObjectIdentifier(marker)] = place
        }
    }


    func drawRoute(on mapView: GMSMapView, encodedPolyline: String?) {
        lastPolyline = encodedPolyline

        traveledPolyline?.map = nil
        remainingPolyline?.map = nil
        routePath = nil
        lastRouteBounds = nil

        guard let encodedPolyline,
              let path = GMSPath(fromEncodedPath: encodedPolyline),
              path.count() > 1 else { return }

        routePath = path

        let remaining = GMSPolyline(path: path)
        remaining.strokeWidth = 6
        remaining.geodesic = true
        remaining.map = mapView
        remainingPolyline = remaining

        let traveled = GMSPolyline(path: GMSMutablePath())
        traveled.strokeWidth = 6
        traveled.geodesic = true
        traveled.map = mapView
        traveledPolyline = traveled

        let bounds = GMSCoordinateBounds(path: path)
        lastRouteBounds = bounds
        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 90))
    }
    
    func updateRouteProgress(user: CLLocationCoordinate2D) {
        guard let path = routePath else { return }

        let count = Int(path.count())
        guard count > 1 else { return }

        var bestIndex = 0
        var bestDist = CLLocationDistance.greatestFiniteMagnitude

        for i in 0..<count {
            let c = path.coordinate(at: UInt(i))
            let d = CLLocation(latitude: user.latitude, longitude: user.longitude)
                .distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
            if d < bestDist {
                bestDist = d
                bestIndex = i
            }
        }

        let traveled = GMSMutablePath()
        if bestIndex > 0 {
            for i in 0...bestIndex {
                traveled.add(path.coordinate(at: UInt(i)))
            }
        }

        let remaining = GMSMutablePath()
        for i in bestIndex..<count {
            remaining.add(path.coordinate(at: UInt(i)))
        }

        traveledPolyline?.path = traveled
        remainingPolyline?.path = remaining

        let remainingMeters = pathDistanceMeters(remaining)
        DispatchQueue.main.async {
            self.parent.mapVM.updateRemaining(distanceMeters: remainingMeters)
        }
    }

    
    func isOffRoute(user: CLLocationCoordinate2D, thresholdMeters: Double = 40) -> Bool {
        guard let path = routePath else { return false }

        var bestDist = CLLocationDistance.greatestFiniteMagnitude
        for i in 0..<path.count() {
            let c = path.coordinate(at: i)
            let d = CLLocation(latitude: user.latitude, longitude: user.longitude)
                .distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
            bestDist = min(bestDist, d)
        }
        return bestDist > thresholdMeters
    }
    
    func centerOnUser(_ mapView: GMSMapView,
                      user: CLLocationCoordinate2D,
                      heading: CLLocationDirection,
                      isNavigating: Bool) {

        isFollowingUser = true  // ✅ re-enable follow mode

        let camera = GMSCameraPosition(
            target: user,
            zoom: isNavigating ? 17 : 15,
            bearing: isNavigating ? heading : 0,
            viewingAngle: isNavigating ? 45 : 0
        )
        mapView.animate(with: GMSCameraUpdate.setCamera(camera))
    }




    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        if let place = placeByMarkerId[ObjectIdentifier(marker)] {
                DispatchQueue.main.async {
                    self.parent.mapVM.selectedPlace = place
                }
                return true
            }

            return false
    }
    
    func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
        if gesture {
            isFollowingUser = false   // user dragged/zoomed => stop auto-follow
        }
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

        userMarker?.rotation = heading
        userMarker?.isFlat = true
    }
    
    private func pathDistanceMeters(_ path: GMSPath?) -> CLLocationDistance {
        guard let path, path.count() > 1 else { return 0 }

        var total: CLLocationDistance = 0
        let n = Int(path.count())

        for i in 0..<(n - 1) {
            let a = path.coordinate(at: UInt(i))
            let b = path.coordinate(at: UInt(i + 1))

            total += CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
        }
        return total
    }


    func focusSelectedPlaceIfNeeded(on mapView: GMSMapView, selected: MapPoint?, isNavigating: Bool) {
        guard !isNavigating else { return }
        guard let selected else { return }
        guard selected.id != lastFocusedPlaceId else { return }

        lastFocusedPlaceId = selected.id
        mapView.animate(with: GMSCameraUpdate.setTarget(selected.coordinate, zoom: 14))
    }
    
    func followUserIfNeeded(on mapView: GMSMapView,
                            user: CLLocationCoordinate2D,
                            heading: CLLocationDirection,
                            isNavigating: Bool) {
        guard isNavigating, isFollowingUser else { return }

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
