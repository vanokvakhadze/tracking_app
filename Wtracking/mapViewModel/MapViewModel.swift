//
//  Untitled.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 14.01.26.
//


import SwiftUI
import CoreLocation
import GoogleMaps
import SwiftData

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    private let manager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var status: CLAuthorizationStatus = .notDetermined
    @Published var heading: CLLocationDirection = 0
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 1
        manager.activityType = .automotiveNavigation
           
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
    @Published var places: [MapPoint] = []
    
    @Published var targetPlaceId: String?
    @Published var activeVisitId: String?
    @Published var hasArrived: Bool = false
    
    @Published var selectedIndex: Int = 1
    @Published var selectedPlace: MapPoint? = nil
    @Published var origin: CLLocationCoordinate2D?
    @Published var destination: CLLocationCoordinate2D?
    @Published var encodedPolyline: String?
    @Published var target: CLLocationCoordinate2D?
    @Published var targetRadius: CLLocationDistance = 80
    @Published  var isNavigating = false
    @Published  var showPlaceSlider: Bool = true
    private let resetDistance: CLLocationDistance = 80
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
    @Published var workSecondsTotal: TimeInterval = 0 {
        didSet {
            UserDefaults.standard.set(workSecondsTotal, forKey: workSecondsKey)
        }
    }
    @Published var drivenRoutes: [DrivenRoute] = []
    @Published var currentTrack: [CLLocationCoordinate2D] = []
    @Published var isRecording: Bool = false {
        didSet {
            UserDefaults.standard.set(isRecording, forKey: recordingKey)
        }
    }
    @Published var stays: [PlaceStay] = []

    private var trackStartedAt: Date?
   
    @Published var initialRouteDurationSeconds: Int?
    @Published var initialRouteDistanceMeters: CLLocationDistance?
    private var canTriggerArrivalToggle: Bool = true
    private var lastProcessAt: Date = .distantPast
    private let minProcessInterval: TimeInterval = 0.7
    private let workSecondsKey = "workSecondsTotalKey"
    private let navSessionKey = "nav_session_v1"
    private let recordingKey = "isRecordingKey"
    private let recordingStartedAtKey = "recordingStartedAtKey"
    private var didLoadOnce = false



    private var workStartedAt: Date? {
        didSet {
            if let d = workStartedAt {
                UserDefaults.standard.set(d, forKey: workStartedKey)
            } else {
                UserDefaults.standard.removeObject(forKey: workStartedKey)
            }
        }
    }
    private let workStartedKey = "workStartedAtKey"

    var workIsRunning: Bool { workStartedAt != nil }
    
    var currentWorkSeconds: TimeInterval {
        if let started = workStartedAt {
            return Date().timeIntervalSince(started)
        } else {
            return workSecondsTotal
        }
    }

    
    func startRecordingDrive() {
        guard !isRecording else { return }
        
        currentTrack.removeAll()
        isRecording = true
        
        trackStartedAt = Date()
        UserDefaults.standard.set(trackStartedAt, forKey: recordingStartedAtKey)
        
        print("🎬 RECORD START")
    }

    init() {
        loadNavigationSession()
        loadRoutesFromDisk()
           
           isRecording = UserDefaults.standard.bool(forKey: recordingKey)
           
           if let savedDate = UserDefaults.standard.object(forKey: recordingStartedAtKey) as? Date {
               trackStartedAt = savedDate
           }
        workSecondsTotal = UserDefaults.standard.double(forKey: workSecondsKey)
        workStartedAt = UserDefaults.standard.object(forKey: workStartedKey) as? Date
    
       }
    
    func finishRecordingDrive() {
        guard isRecording else { return }
        
        isRecording = false
        
        UserDefaults.standard.removeObject(forKey: recordingStartedAtKey)
        
        let started = trackStartedAt ?? Date()
        let finished = Date()
        trackStartedAt = nil
        
        guard currentTrack.count > 1 else {
            currentTrack.removeAll()
            return
        }
        
        let route = DrivenRoute(
            id: UUID().uuidString,
            startedAt: started,
            finishedAt: finished,
            expiresAt: Calendar.current.date(byAdding: .day, value: 1, to: finished) ?? finished,
            points: currentTrack.map { CodableCoordinate($0) }
        )
        
        drivenRoutes.append(route)
        currentTrack.removeAll()
        
        saveRoutesToDisk()
    }
    @MainActor
    func loadPlaces(context: ModelContext) {
           let descriptor = FetchDescriptor<MapPoint>()
           if let items = try? context.fetch(descriptor) {
               self.places = items
           }
       }
    
    @discardableResult
    func cleanupExpiredRoutes(now: Date = Date()) -> Bool {
        let before = drivenRoutes.count
        drivenRoutes.removeAll { $0.expiresAt <= now }
        let changed = drivenRoutes.count != before
        if changed { saveRoutesToDisk() }
        return changed
    }
    
    private var routesURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("driven_routes.json")
    }

    func loadRoutesFromDisk() {
        do {
            let data = try Data(contentsOf: routesURL)
            drivenRoutes = try JSONDecoder().decode([DrivenRoute].self, from: data)
            cleanupExpiredRoutes()
            print("📦 Loaded routes:", drivenRoutes.count)
        } catch {
            drivenRoutes = []
            print("📦 No saved routes yet")
        }
    }
    
    func addStartPoint(coordinate: CLLocationCoordinate2D, context: ModelContext) {
          let point = MapPoint(
              id: UUID().uuidString,
              title: "Start / End",
              latitude: coordinate.latitude,
              longitude: coordinate.longitude,
              isStartPoint: true,
              imageName: "start",
              adress: "Start / End",
              lastDate: Date()
          )
          context.insert(point)
          try? context.save()
          places.append(point)
        print(places.count)
      }
    
    
    
    func addManualPoint(
        coordinate: CLLocationCoordinate2D,
        title: String,
        address: String,
        imageData: Data?,
        context: ModelContext
    ) {
        let fileName: String?
        if let imageData {
            let name = UUID().uuidString + ".jpg"
            fileName = (try? ImageStore.saveJPEG(imageData, fileName: name))
        } else {
            fileName = nil
        }

        let point = MapPoint(
            id: UUID().uuidString,
            title: title.isEmpty ? "Place \(places.count + 1)" : title,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            isStartPoint: false,
            imageName: "pin",
            adress: address,
            lastDate: Date(),
            imagePath: fileName
        )

        context.insert(point)
        try? context.save()
        places.append(point)
        print(places.count)
    }
    
    func deleteAllLocalData(context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<MapPoint>())

            for p in all {
                if let path = p.imagePath {   // თუ შენ imagePath იყენებ
                    ImageStore.delete(path)
                }
            }

            all.forEach { context.delete($0) }
            try context.save()

            places.removeAll()
            print("✅ Deleted all MapPoint + local photos")
        } catch {
            print("❌ Delete all error:", error)
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
    
    func saveNavigationSession() {
        let session = NavigationSession(
            isNavigating: isNavigating,
            destinationLat: destination?.latitude,
            destinationLng: destination?.longitude,
            targetPlaceId: targetPlaceId,
            targetRadius: Double(targetRadius),
            encodedPolyline: encodedPolyline
        )

        do {
            let data = try JSONEncoder().encode(session)
            UserDefaults.standard.set(data, forKey: navSessionKey)
        } catch {
            print("❌ saveNavigationSession error:", error)
        }
    }

    func loadNavigationSession() {
        guard let data = UserDefaults.standard.data(forKey: navSessionKey) else { return }
        do {
            let session = try JSONDecoder().decode(NavigationSession.self, from: data)

            isNavigating = session.isNavigating
            targetPlaceId = session.targetPlaceId
            targetRadius = session.targetRadius
            encodedPolyline = session.encodedPolyline

            if let lat = session.destinationLat, let lng = session.destinationLng {
                destination = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            } else {
                destination = nil
            }

            if let id = session.targetPlaceId,
               let p = places.first(where: { $0.id == id }) {
                target = CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude)
            } else {
                target = nil
            }

            showPlaceSlider = !session.isNavigating
            hasArrived = false
        } catch {
            print("❌ loadNavigationSession error:", error)
        }
    }

    func clearNavigationSession() {
        UserDefaults.standard.removeObject(forKey: navSessionKey)
    }

    
    
    func handleWorkArrival(user: CLLocationCoordinate2D) {
        guard let idx = places.firstIndex(where: { $0.isStartPoint }) else { return }
        let workPlace = places[idx]

        let userLoc = CLLocation(latitude: user.latitude, longitude: user.longitude)
        let placeLoc = CLLocation(latitude: workPlace.latitude,
                                  longitude: workPlace.longitude)

        let dist = userLoc.distance(from: placeLoc)

        if dist >= resetDistance {
            canTriggerArrivalToggle = true
            return
        }

        guard dist <= targetRadius, canTriggerArrivalToggle else { return }
        canTriggerArrivalToggle = false

        places[idx].date = Date()

        if workStartedAt != nil {
            stopWork()
            finishRecordingDriveIfNeeded()
        } else {
            startWork()
            startRecordingDriveIfNeeded()
        }
    }
    
    func resumeNavigationIfNeeded(currentLocation: CLLocationCoordinate2D?) {
        guard isNavigating,
              let destination,
              let origin = currentLocation else { return }

        requestRoute(origin: origin, destination: destination)
    }
 

    func finish() {
        if workStartedAt != nil {
            stopWork()
        }

        showPlaceSlider = false
        finishRecordingDriveIfNeeded()
    }
    
    func startWork() {
        guard workStartedAt == nil else { return }
        workStartedAt = Date()
    }

    func stopWork() {
        guard let startedAt = workStartedAt else { return }
        workSecondsTotal += Date().timeIntervalSince(startedAt)
        workStartedAt = nil
    }

    func startRecordingDriveIfNeeded() {
        guard !isRecording else { return }
        startRecordingDrive()
    }

    func finishRecordingDriveIfNeeded() {
        guard isRecording else { return }
        finishRecordingDrive()
    }
    
    
    
    func setDestination(_ coordinate: CLLocationCoordinate2D) {
        destination = coordinate
    }
    
    func startTrackingPlace(place: MapPoint, radius: CLLocationDistance = 100, context: ModelContext) {
        guard !place.isStartPoint else { return }
        UIApplication.shared.isIdleTimerDisabled = true




        target =   CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        targetPlaceId = place.id
        targetRadius = radius

        resetTrackingState()

        if let origin {
            processTargetIfNeeded(user: origin, context: context)
        }
    }
    
    func stopTrackingTargetPlace() {
        target = nil
        targetPlaceId = nil
        resetTrackingState()
        distanceToTargetMeters = nil
    }
    
    
    
    
    private func resetTrackingState() {
        isInsideTarget = false
        enteredAt = nil
        lastStaySeconds = nil
    }
    
    private func processTargetIfNeeded(user: CLLocationCoordinate2D, context: ModelContext) {
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

            saveEnter(place: place, context: context)
        }

        if !insideNow && isInsideTarget {
            isInsideTarget = false

            guard let enteredAt else { return }
            let seconds = Date().timeIntervalSince(enteredAt)
            self.enteredAt = nil

            stays.append(PlaceStay(id: UUID().uuidString, title: place.title, seconds: seconds))

            print("🚪 EXIT | \(place.title) | stayed:", formatSeconds(Int(seconds)))

            saveExit(context: context)
        }
    }

    
    
    func cleanupExpiredVisits(context: ModelContext) {
        let now = Date()
        let d = FetchDescriptor<PlaceVisitModel>(
            predicate: #Predicate { $0.expiresAt <= now }
        )
        if let expired = try? context.fetch(d) {
            expired.forEach { context.delete($0) }
            try? context.save()
        }
        
        workSecondsTotal = 0.0
        
    }
    
    func saveEnter(place: MapPoint, context: ModelContext) {
        cleanupExpiredVisits(context: context)

        let visit = PlaceVisitModel(
            placeId: place.id,
            title: place.title,
            enteredAt: Date()
        )

        context.insert(visit)
        try? context.save()

        activeVisitId = visit.id   
    }
    
    func saveExit(context: ModelContext) {
        guard let activeVisitId else { return }

        let idToFind = activeVisitId
        let descriptor = FetchDescriptor<PlaceVisitModel>(
            predicate: #Predicate { $0.id == idToFind }
        )

        if let visit = try? context.fetch(descriptor).first {
            let exitDate = Date()
            let seconds = exitDate.timeIntervalSince(visit.enteredAt)

            visit.exitedAt = exitDate
            visit.seconds = seconds
            visit.expiresAt = exitDate.addingTimeInterval(24 * 3600)

            try? context.save()
            print("💾 Saved exit with seconds:", seconds)
        }

        self.activeVisitId = nil // ✅ მხოლოდ ვიზიტის reset
    }
     func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let m = s / 60
        let sec = s % 60
        if m >= 60 {
             let h = m / 60
             let mm = m % 60
             return "\(h)h \(mm)m"
         }
         return "\(m)m \(sec)s"
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
        UIApplication.shared.isIdleTimerDisabled = false

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
        clearNavigationSession()
    }
    
    
    
    func processLocationUpdate(_ coordinate: CLLocationCoordinate2D, context: ModelContext) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessAt) >= minProcessInterval else { return }
        lastProcessAt = now

        origin = coordinate

        if isRecording { appendTrackPoint(coordinate) }

        handleWorkArrival(user: coordinate)
        processTargetIfNeeded(user: coordinate, context: context)
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

