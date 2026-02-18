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
        manager.distanceFilter = 5
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false

        manager.requestAlwaysAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus

        if status == .authorizedAlways {
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
    @Published var places: [MapPoint] = [
        MapPoint(id: "1", title: "Pickup",
                 coordinate: .init(latitude: 41.842989, longitude: 44.624315),
                 systemIcon: "checkmark",
                 color: .white, isStartPoint: true),
        
        //41.845177, 44.619449   1.842989, 44.624315
        //41.845069, 44.619414
        
        MapPoint(id: "2", title: "work2",
                 coordinate: .init(latitude: 41.840083, longitude: 44.662514),
                 systemIcon: "person", color: .white, isStartPoint: false),
        
    
        MapPoint(id: "3", title: "work3",
                 coordinate: .init(latitude: 41.837977, longitude: 44.705020),
                 systemIcon: "car", color: .white, isStartPoint: false),
        
        
        MapPoint(id: "4", title: "work4",
                 coordinate: .init(latitude: 41.942146, longitude: 44.738314),
                 systemIcon: "car", color: .white, isStartPoint: false),
//41.942146, 44.738314
        
        
//        MapPoint(id: "5", title: "work5",
//                 coordinate: .init(latitude: 41.7221, longitude: 44.7356),
//                 systemIcon: "house", color: .white, isStartPoint: false),
//        
//        MapPoint(id: "6", title: "work6",
//                 coordinate: .init(latitude: 41.7281, longitude: 44.8326),
//                 systemIcon: "building", color: .white, isStartPoint: false)
    ]
    @Published var targetPlaceId: String?
    @Published var lastStayPlaceTitle: [String : String] = [:]
    @Published var hasArrived: Bool = false
    
    @Published var selectedIndex: Int = 1
    @Published var selectedPlace: MapPoint? = nil
    @Published var origin: CLLocationCoordinate2D?
    @Published var destination: CLLocationCoordinate2D?
    @Published var encodedPolyline: String?
    @Published var target: CLLocationCoordinate2D?
    @Published var targetRadius: CLLocationDistance = 20
    @Published  var isNavigating = false
    @Published  var showPlaceSlider: Bool = true
    private let resetDistance: CLLocationDistance = 40  // “მეორედ მივიდა” რომ ჩაითვალოს
    @Published var routeDurationText: String?
    @Published var routeDurationSeconds: Int?
    @Published var routeDistanceText: String?
    @Published var isInsideTarget: Bool = false
    @Published var enteredAt: Date?
    @Published var lastStaySeconds: TimeInterval?
    @Published var distanceToTargetMeters: CLLocationDistance?
    @Published var remainingDistanceMeters: CLLocationDistance = 0
    @Published var remainingDistanceText: String = "—"
    @Published var remainingETASeconds: Int?
    @Published var remainingETAText: String = "—"
    @Published var workIsRunning: Bool = false
    @Published var workSecondsTotal: TimeInterval = 0
    @Published var drivenRoutes: [DrivenRoute] = []
    @Published var currentTrack: [CLLocationCoordinate2D] = []
    @Published var isRecording: Bool = false

    private var trackStartedAt: Date?
   
    private var initialRouteDurationSeconds: Int?
    private var initialRouteDistanceMeters: CLLocationDistance?
    private var workStartedAt: Date? = nil
    private var canTriggerArrivalToggle: Bool = true
    

    func startRecordingDrive() {
        currentTrack.removeAll(keepingCapacity: true)
        isRecording = true
        trackStartedAt = Date()

        if let origin {
            currentTrack.append(origin)
        }

        print("🎬 RECORD START")
    }

    init() {
           loadRoutesFromDisk()
       }
    
    func finishRecordingDrive() {
        guard isRecording else { return }
        isRecording = false

        let started = trackStartedAt ?? Date()
        let finished = Date()
        trackStartedAt = nil

        guard currentTrack.count > 1 else {
            print("⚠️ Not enough points to save route")
            currentTrack.removeAll()
            return
        }

        let route = DrivenRoute(
            id: UUID().uuidString,
            startedAt: started,
            finishedAt: finished,
            points: currentTrack.map { CodableCoordinate($0) }
        )

        drivenRoutes.append(route)
        currentTrack.removeAll()

        saveRoutesToDisk()
        print("✅ RECORD SAVED. Total routes:", drivenRoutes.count)
    }
    
    
    private var routesURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("driven_routes.json")
    }

    func loadRoutesFromDisk() {
        do {
            let data = try Data(contentsOf: routesURL)
            drivenRoutes = try JSONDecoder().decode([DrivenRoute].self, from: data)
            print("📦 Loaded routes:", drivenRoutes.count)
        } catch {
            drivenRoutes = []
            print("📦 No saved routes yet")
        }
    }

    func saveRoutesToDisk() {
        do {
            let data = try JSONEncoder().encode(drivenRoutes)
            try data.write(to: routesURL, options: .atomic)
        } catch {
            print("❌ saveRoutesToDisk error:", error)
        }
    }

    private func appendTrackPoint(_ c: CLLocationCoordinate2D) {
        guard let last = currentTrack.last else {
            currentTrack.append(c)
            return
        }

        let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
        let newLoc  = CLLocation(latitude: c.latitude, longitude: c.longitude)

        if newLoc.distance(from: lastLoc) >= 5 {
            currentTrack.append(c)
        }
    }

    
    
    func handleWorkArrival(user: CLLocationCoordinate2D) {
        guard let workPlace = places.first(where: { $0.isStartPoint }) else { return }

        let userLoc = CLLocation(latitude: user.latitude, longitude: user.longitude)
        let placeLoc = CLLocation(latitude: workPlace.coordinate.latitude,
                                  longitude: workPlace.coordinate.longitude)

        let dist = userLoc.distance(from: placeLoc)

        if dist >= resetDistance {
            canTriggerArrivalToggle = true
            return
        }

        guard dist <= targetRadius, canTriggerArrivalToggle else { return }
        canTriggerArrivalToggle = false

        if workIsRunning {
            if let startedAt = workStartedAt {
                workSecondsTotal += Date().timeIntervalSince(startedAt)
            }
            workStartedAt = nil
            workIsRunning = false

            finishRecordingDrive()

            print("🟥 WORK STOP | \(workPlace.title) | total: \(format(workSecondsTotal))")
        } else {
            workStartedAt = Date()
            workIsRunning = true

            startRecordingDrive()
            print("🟩 WORK START | \(workPlace.title) | at: \(workStartedAt!)")
        }
    }

    
    
    
    func setDestination(_ coordinate: CLLocationCoordinate2D) {
        destination = coordinate
    }
    
    func startTrackingPlace(place: MapPoint, radius: CLLocationDistance = 20) {
        guard !place.isStartPoint else { return }

        target = place.coordinate
        targetPlaceId = place.id
        targetRadius = radius

        resetTrackingState()

        if let origin {
            processTargetIfNeeded(user: origin)
        }
    }
    
    func stopTrackingTargetPlace() {
        target = nil
        targetPlaceId = nil
        resetTrackingState()
        distanceToTargetMeters = nil
        lastStayPlaceTitle = [:]
    }
    
    
    
    
    private func resetTrackingState() {
        isInsideTarget = false
        enteredAt = nil
        lastStaySeconds = nil
    }
    
    private func processTargetIfNeeded(user: CLLocationCoordinate2D) {
        guard let target else { return }
        guard let id = targetPlaceId else { return }
        guard let place = places.first(where: { $0.id == id }) else { return }

        if place.isStartPoint { return }

        let userLoc = CLLocation(latitude: user.latitude, longitude: user.longitude)
        let targetLoc = CLLocation(latitude: target.latitude, longitude: target.longitude)

        let dist = userLoc.distance(from: targetLoc)
        let insideNow = dist <= targetRadius

        if insideNow && !isInsideTarget {
            isInsideTarget = true
            enteredAt = Date()
            print("✅ ENTER | \(place.title)")
        }

        if !insideNow && isInsideTarget {
            isInsideTarget = false

            guard let enteredAt else { return }
            let seconds = Date().timeIntervalSince(enteredAt)
            self.enteredAt = nil

            print("🚪 EXIT | \(place.title) | stayed:", format(seconds))
        }
    }

     func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let m = s / 60
        let sec = s % 60
        return m > 0 ? "\(m)m \(sec)s" : ""
    }
    
    func startRoute() {
        guard let o = origin, let d = destination else {
                print("❌ Missing origin or destination")
                return
            }

            requestRoute(origin: o, destination: d)
    }
    
    private func requestRoute(origin: CLLocationCoordinate2D,
                              destination: CLLocationCoordinate2D) {
        
        DirectionsService.fetchRoute(origin: origin, destination: destination) { [weak self] info in
            DispatchQueue.main.async {
                guard let self, let info else { return }
                
                self.encodedPolyline = info.polyline
                self.routeDurationText = info.durationText
                self.routeDurationSeconds = info.durationSeconds
                self.routeDistanceText = info.distanceText
                
                self.initialRouteDurationSeconds = info.durationSeconds
                self.initialRouteDistanceMeters = info.distanceMeters
            }
        }
    }
    
    func updateRemaining(distanceMeters: CLLocationDistance) {
        remainingDistanceMeters = max(distanceMeters, 0)
        
        if distanceMeters >= 1000 {
            remainingDistanceText = String(format: "%.1f km", distanceMeters / 1000)
        } else {
            remainingDistanceText = "\(Int(distanceMeters)) m"
        }
        
        if let totalDist = initialRouteDistanceMeters,
           let totalDur = initialRouteDurationSeconds,
           totalDist > 0 {
            let ratio = min(max(distanceMeters / totalDist, 0), 1)
            let eta = Int(Double(totalDur) * ratio)
            remainingETASeconds = eta
            remainingETAText = formatSeconds(eta)
        }
    }
    
    private func formatSeconds(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        if m >= 60 {
            let h = m / 60
            let mm = m % 60
            return "\(h)h \(mm)m"
        }
        return "\(m)m \(sec)s"
    }
    
    func cancelRoute() {
        encodedPolyline = nil
        destination = nil
        isNavigating = false
        showPlaceSlider = true

        remainingDistanceMeters = 0
        remainingDistanceText = "—"
        remainingETASeconds = nil
        remainingETAText = "—"

        initialRouteDurationSeconds = nil
        initialRouteDistanceMeters = nil

        hasArrived = false
    }
    
    func processLocationUpdate(_ coordinate: CLLocationCoordinate2D) {
        origin = coordinate

        if isRecording {
            appendTrackPoint(coordinate)
        }

        handleWorkArrival(user: coordinate)
        processTargetIfNeeded(user: coordinate)
        checkArrivalAndCancelIfNeeded(user: coordinate)
    }
    
    private func checkArrivalAndCancelIfNeeded(user: CLLocationCoordinate2D) {
        guard let destination else { return }
        guard encodedPolyline != nil else { return }
        guard !hasArrived else { return }
        
        let userLoc = CLLocation(latitude: user.latitude, longitude: user.longitude)
        let destLoc = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        
        let dist = userLoc.distance(from: destLoc)
        
        if dist <= targetRadius {
            hasArrived = true
            print("✅ Arrived within \(Int(targetRadius))m. Auto-cancel route.")
            cancelRoute()
        }
    }
    
    
}

