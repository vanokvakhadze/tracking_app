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
            
            let smoothUser = context.coordinator.smooth(user, alpha: 0.25)
            context.coordinator.updateUserMarker(on: mapView,
                                                 coordinate: smoothUser,
                                                 heading: locationManager.heading,
                                                 isNavigating: true)

           

            if isNavigating, let user = locationManager.location?.coordinate {
                context.coordinator.updateRouteProgress(on: mapView, user: user)
            }

        } else {
            
            let smoothUser = context.coordinator.smooth(user, alpha: 0.25)

            context.coordinator.focusIfNeeded(
                on: mapView,
                placeId: focusPlaceId,
                places: mapVM.places
            )

            context.coordinator.updateUserMarker(on: mapView,
                                                 coordinate: smoothUser,
                                                 heading: locationManager.heading,
                                                 isNavigating: false)
            
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
    private var lastSelectedId: String?
    private var iconCache: [String: UIImage] = [:]
    private var lastRerouteAt: Date?
    private let rerouteCooldown: TimeInterval = 8
    private var lastUserUpdateAt: CFTimeInterval = CACurrentMediaTime()
    private var destinationCoord: CLLocationCoordinate2D?
    private var isRerouting = false
    private var smoothedUser: CLLocationCoordinate2D?
    var didInitialSetup = false
    private var destinationMarker: GMSMarker?
    var lastPolyline: String?
    private var displayLink: CADisplayLink?
    private var animFrom: CLLocationCoordinate2D?
    private var animTo: CLLocationCoordinate2D?
    private var animStart: CFTimeInterval = 0
    private var animDuration: CFTimeInterval = 0.8

    init(_ parent: GoogleMapView) {
        self.parent = parent
    }
    
    
    private func startSmoothMove(to coordinate: CLLocationCoordinate2D) {
        let now = CACurrentMediaTime()

        if animTo == nil {
            animFrom = coordinate
            animTo = coordinate
            animStart = now
            animDuration = 0.2
            startDisplayLinkIfNeeded()
            return
        }

        animFrom = currentAnimatedCoordinate(now: now) ?? animTo
        animTo = coordinate

        // duration = დრო რეალურ update-ებს შორის (ეს კლავს “სტეპებს”)
        let dt = max(now - animStart, 0.15)
        animStart = now
        animDuration = min(max(dt, 0.25), 2.5)

        startDisplayLinkIfNeeded()
    }

    private func startDisplayLinkIfNeeded() {
        if displayLink != nil { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        guard let c = currentAnimatedCoordinate(now: now) else { return }

        // აქ უბრალოდ marker გადაადგილდება
        userMarker?.position = c

        // თუ გინდა camera-ც იგივე coordinate-ს მიყვეს, აქვე გააკეთე (parent/mapView reference თუ გაქვს)
    }

    private func currentAnimatedCoordinate(now: CFTimeInterval) -> CLLocationCoordinate2D? {
        guard let from = animFrom, let to = animTo else { return nil }
        let t = min(max((now - animStart) / animDuration, 0), 1)

        // Linear interpolation lat/lng-ზე (საკმარისია ქალაქში)
        let lat = from.latitude + (to.latitude - from.latitude) * t
        let lng = from.longitude + (to.longitude - from.longitude) * t
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
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
    
    func syncPlaceMarkers(on mapView: GMSMapView, places: [MapPoint], selectedId: String?) {
        let newIds = Set(places.map(\.id))
        let oldIds = Set(markersById.keys)

        for id in oldIds.subtracting(newIds) {
            markersById[id]?.map = nil
            markersById.removeValue(forKey: id)
        }

        for place in places {

            let isSelected = (place.id == selectedId)

            let cacheKey = "\(place.id)|\(isSelected)"   // ✅ უკეთესი key (უნიკალური)

            let icon: UIImage? = {
                if let cached = iconCache[cacheKey] { return cached }

                let baseImage: UIImage? = {
                    if let path = place.imagePath {
                        let url = ImageStore.url(for: path)
                        return UIImage(contentsOfFile: url.path)
                    } else {
                        return UIImage(named: place.imageName)
                    }
                }()

                guard let baseImage else { return  .checkmark }   // ✅ ახლა შეიძლება nil

                let img = UIImage.mapIcon(
                    baseImage: baseImage,
                    baseSize: 26,
                    selectedSize: 32,
                    backgroundColor: .systemBlue,
                    padding: 6,
                    isSelected: isSelected
                )

                iconCache[cacheKey] = img
                return img
            }()

            let marker = markersById[place.id] ?? {
                let m = GMSMarker()
                markersById[place.id] = m
                m.map = mapView
                return m
            }()

            marker.position = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            marker.title = place.title

            if marker.icon !== icon {
                marker.icon = icon
            }

            marker.zIndex = isSelected ? 1000 : 0
        }

        lastSelectedId = selectedId
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

      
        destinationCoord = path.coordinate(at: UInt(path.count() - 1))

        let remaining = GMSPolyline(path: path)
        remaining.strokeWidth = 6
        remaining.geodesic = true
        remaining.map = mapView
        remainingPolyline = remaining

        let bounds = GMSCoordinateBounds(path: path)
        lastRouteBounds = bounds
        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 90))
    }


    func updateRouteProgress(on mapView: GMSMapView, user: CLLocationCoordinate2D) {
        guard let path = routePath else { return }

        if isOffRoute(user: user, thresholdMeters: 45) {
            reroute(from: user, on: mapView)
            return
        }

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

        let remaining = GMSMutablePath()
        for i in bestIndex..<count {
            remaining.add(path.coordinate(at: UInt(i)))
        }

        remainingPolyline?.path = remaining

        // ✅ distance update
        let remainingMeters = pathDistanceMeters(remaining)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            parent.mapVM.updateRemaining(distanceMeters: remainingMeters)
        }
    }

    private func reroute(from user: CLLocationCoordinate2D, on mapView: GMSMapView) {
        guard !isRerouting else { return }
        if let last = lastRerouteAt, Date().timeIntervalSince(last) < rerouteCooldown { return }
        lastRerouteAt = Date()

        guard let dest = destinationCoord else { return }

        isRerouting = true

        DirectionsService.fetchRoute(origin: user, destination: dest) { [weak self] info in
            guard let self, let info else { return }
            DispatchQueue.main.async {
                self.isRerouting = false

                self.parent.routePolylineEncoded = info.polyline

                self.drawRoute(on: mapView, encodedPolyline: info.polyline)

                self.parent.mapVM.initialRouteDistanceMeters = info.distanceMeters
                self.parent.mapVM.initialRouteDurationSeconds = info.durationSeconds

                self.parent.mapVM.remainingDistanceText = info.distanceText
                self.parent.mapVM.remainingETAText = info.durationText
            }
        }
    }
    private func tailStartIndex(for path: GMSPath, endIndex: Int, tailMeters: CLLocationDistance) -> Int {
        guard endIndex > 0 else { return 0 }

        var meters: CLLocationDistance = 0
        var i = endIndex

        while i > 0 && meters < tailMeters {
            let a = path.coordinate(at: UInt(i))
            let b = path.coordinate(at: UInt(i - 1))
            meters += CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            i -= 1
        }

        return max(0, i)
    }

    
    func isOffRoute(user: CLLocationCoordinate2D, thresholdMeters: Double = 45) -> Bool {
        guard let path = routePath else { return false }
        // ✅ checks distance to path (segments), not only vertices
        let onPath = GMSGeometryIsLocationOnPathTolerance(user, path, true, thresholdMeters)
        return !onPath
    }
    
    func centerOnUser(_ mapView: GMSMapView,
                      user: CLLocationCoordinate2D,
                      heading: CLLocationDirection,
                      isNavigating: Bool) {

        isFollowingUser = true  

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
            isFollowingUser = false   
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
            m.isFlat = true
            m.map = mapView
            userMarker = m
            lastUserUpdateAt = CACurrentMediaTime()
            return
        }

        let now = CACurrentMediaTime()
        let dt = now - lastUserUpdateAt
        lastUserUpdateAt = now
 

        let duration = min(max(dt, 0.15), 2.5)

        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))

        startSmoothMove(to: coordinate)
        userMarker?.rotation = heading
        userMarker?.icon = icon

        CATransaction.commit()
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
        mapView.animate(with: GMSCameraUpdate.setTarget(CLLocationCoordinate2D(latitude: selected.latitude, longitude: selected.longitude), zoom: 14))
    }
    
    func followUserIfNeeded(on mapView: GMSMapView,
                            user: CLLocationCoordinate2D,
                            heading: CLLocationDirection,
                            isNavigating: Bool) {
        guard isNavigating, isFollowingUser else { return }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.35)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))

        let camera = GMSCameraPosition(
            target: user,
            zoom: 17,
            bearing: heading,
            viewingAngle: 45
        )
        mapView.animate(with: GMSCameraUpdate.setCamera(camera))

        CATransaction.commit()
    }
    
     func smooth(_ new: CLLocationCoordinate2D, alpha: Double = 0.25) -> CLLocationCoordinate2D {
        guard let s = smoothedUser else {
            smoothedUser = new
            return new
        }
        let lat = s.latitude + (new.latitude - s.latitude) * alpha
        let lon = s.longitude + (new.longitude - s.longitude) * alpha
        let out = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        smoothedUser = out
        return out
    }

    
    
    func focusIfNeeded(on mapView: GMSMapView, placeId: String?, places: [MapPoint]) {
        guard let placeId, placeId != lastFocusedId else { return }
        guard let p = places.first(where: { $0.id == placeId }) else { return }

        lastFocusedId = placeId

        mapView.animate(with: GMSCameraUpdate.setTarget(CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude), zoom: 14))
    }
}
