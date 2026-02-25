//
//  ContentView.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 14.01.26.
//

import SwiftUI
import CoreLocation
import AVFoundation
import SwiftData

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context

    @StateObject var locationManager = LocationManager()
    @StateObject var mapVM = MapVM()

    @State private var didDecide = false
    @State private var shouldStartNavigator = false

    var body: some View {
        Group {
            if !didDecide {
                ProgressView()
            } else if shouldStartNavigator {
                NavigatorView(locationManager: locationManager, mapVM: mapVM, navigate: $shouldStartNavigator)
            } else {
                MapScreen(mapVM: mapVM, navigate: $shouldStartNavigator)
            }
        }
        .task {
            guard !didDecide else { return }

            do {
                // 1) Fetch all MapPoints from SwiftData (local)
                let all = try context.fetch(FetchDescriptor<MapPoint>())

                // debug
                print("📦 SwiftData MapPoint count:", all.count)

                // 2) snapshot decision once
                shouldStartNavigator = all.count >= 2

                // 3) sync VM once (თუ გჭირდება)
                mapVM.places = all

                didDecide = true
            } catch {
                print("❌ Fetch error:", error)
                shouldStartNavigator = false
                didDecide = true
            }
        }
    }
}


extension UIImage {
    
    static func mapSymbol(
        name: String,
        pointSize: CGFloat = 24,
        color: UIColor,
        backgroundColor: UIColor? = nil,
        padding: CGFloat = 8
    ) -> UIImage? {
        
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
        
        guard let symbol = UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
        else { return nil }
        
        guard let bgColor = backgroundColor else {
            return symbol
        }
        
        let side = max(symbol.size.width, symbol.size.height) + padding * 2
        let size = CGSize(width: side, height: side)
        let radius = side / 2
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            
            let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            bgColor.setFill()
            path.fill()
            
            let origin = CGPoint(
                x: (side - symbol.size.width) / 2,
                y: (side - symbol.size.height) / 2
            )
            symbol.draw(at: origin)
        }
    }
    
    
    static func mapAsset(
        name: String,
        baseSize: CGFloat = 32,
        selectedSize: CGFloat = 38,
        backgroundColor: UIColor = .systemBlue,
        padding: CGFloat = 6,
        isSelected: Bool
    ) -> UIImage? {
        
        guard let baseImage = UIImage(named: name) else { return nil }
        
        let imageSize = isSelected ? selectedSize : baseSize
        let imageRect = CGRect(origin: .zero, size: CGSize(width: imageSize, height: imageSize))
        
        if !isSelected {
            return UIGraphicsImageRenderer(size: imageRect.size).image { _ in
                
                let circlePath = UIBezierPath(ovalIn: imageRect)
                circlePath.addClip() // 👈 this makes image circular
                
                baseImage.draw(in: imageRect)
            }
        }
        
        let side = imageSize + padding * 2
        let canvasSize = CGSize(width: side, height: side)
        
        return UIGraphicsImageRenderer(size: canvasSize).image { _ in
            
            let rect = CGRect(origin: .zero, size: canvasSize)
            
            backgroundColor.withAlphaComponent(0.25).setFill()
            UIBezierPath(ovalIn: rect).fill()
            
            let imageOrigin = CGPoint(x: padding, y: padding)
            let imageFrame = CGRect(origin: imageOrigin,
                                    size: CGSize(width: imageSize, height: imageSize))
            
            let circlePath = UIBezierPath(ovalIn: imageFrame)
            circlePath.addClip()
            
            baseImage.draw(in: imageFrame)
        }
    }
    
    
    static func mapIcon(
        baseImage: UIImage,
        baseSize: CGFloat = 32,
        selectedSize: CGFloat = 38,
        backgroundColor: UIColor = .systemBlue,
        padding: CGFloat = 6,
        isSelected: Bool
    ) -> UIImage {

        let imageSize = isSelected ? selectedSize : baseSize
        let imageRect = CGRect(origin: .zero, size: CGSize(width: imageSize, height: imageSize))

        if !isSelected {
            return UIGraphicsImageRenderer(size: imageRect.size).image { _ in
                let circlePath = UIBezierPath(ovalIn: imageRect)
                circlePath.addClip()
                baseImage.draw(in: imageRect)
            }
        }

        let side = imageSize + padding * 2
        let canvasSize = CGSize(width: side, height: side)

        return UIGraphicsImageRenderer(size: canvasSize).image { _ in
            let rect = CGRect(origin: .zero, size: canvasSize)
            backgroundColor.withAlphaComponent(0.25).setFill()
            UIBezierPath(ovalIn: rect).fill()

            let imageOrigin = CGPoint(x: padding, y: padding)
            let imageFrame = CGRect(origin: imageOrigin, size: CGSize(width: imageSize, height: imageSize))

            let circlePath = UIBezierPath(ovalIn: imageFrame)
            circlePath.addClip()
            baseImage.draw(in: imageFrame)
        }
    }

    }



struct NavigatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject var locationManager: LocationManager
    @ObservedObject var mapVM: MapVM
    @State private var focusPlaceId: String? = "1"
    @State private var goToResult = false
    @State private var shouldCenter = false
    @Binding var navigate: Bool   // ✅ ეს დაამატე


    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
      
                GoogleMapView(
                    locationManager: locationManager,
                    mapVM: mapVM,
                    routePolylineEncoded: $mapVM.encodedPolyline,
                    isNavigating: $mapVM.isNavigating,
                    focusPlaceId: $focusPlaceId,
                    shouldCenter: $shouldCenter
                )
                .ignoresSafeArea()
               
             
                if mapVM.encodedPolyline != nil {
                    CancelButton(mapVM: mapVM, shouldCenter: $shouldCenter) {
                        mapVM.cancelRoute()
                        
                    }
                    
                }
                
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .sheet(isPresented: $mapVM.showPlaceSlider) {
                
                VStack(alignment: .trailing, spacing: 20){
                    HStack{
                        
                        Button(action: {
                            mapVM.deleteAllLocalData(context: modelContext)
                            navigate = false
                        }) {
                            Text("ობიექტების წაშლა")
                                .foregroundStyle(.white)
                                .padding(6)
                                
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.red.opacity(0.7))
                        )
                        
                        Spacer()
                        
                        Button(action: {
                            mapVM.finish()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                goToResult = true
                            }
                        }) {
                            Text("ისტორიის ნახვა")
                                .foregroundStyle(.white)
                                .padding(6)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue.opacity(0.7))
                        )
                        
                    }
                    .padding(EdgeInsets(top: 15, leading: 10, bottom: 0, trailing: 10))

                PlaceCarousel(
                    places: mapVM.places,
                    selectedIndex: $mapVM.selectedIndex,
                    onIndexChanged: { place in
                        mapVM.selectedPlace = place
                        focusPlaceId = place.id
                    },
                    
                    
                    onStart: { place in
                        guard let user = locationManager.location?.coordinate else { return }
                        
                        mapVM.processLocationUpdate(user, context: modelContext)
                        
                        mapVM.startTrackingPlace(place: place, radius: 50, context: modelContext)
                        
                        mapVM.setDestination(CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
                        mapVM.startRoute()
                        
                        mapVM.isNavigating = true
                        mapVM.showPlaceSlider = false
                    }
                    )
                    }
                
                .presentationDetents([.fraction(0.6) , .fraction(0.5)])
                .presentationCornerRadius(25)
                .interactiveDismissDisabled(true)
                .presentationBackgroundInteraction(.enabled)
                
            }
            
            .navigationDestination(isPresented: $goToResult) {
                    ResultView(mapVM: mapVM)
                }
            
           
            .onAppear {
                mapVM.cleanupExpiredVisits(context: modelContext)

                if mapVM.selectedPlace == nil, !mapVM.places.isEmpty {
                    mapVM.selectedPlace = mapVM.places[1]
                    mapVM.selectedIndex = 1
                    focusPlaceId = mapVM.places[1].id
                }
            }
            
            .onChange(of: mapVM.selectedPlace?.id) { newId in
                guard let newId else { return }
                if let idx = mapVM.places.firstIndex(where: { $0.id == newId }) {
                    if mapVM.selectedIndex != idx {
                        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.88)) {
                            mapVM.selectedIndex = idx
                        }
                    }
                }
            }
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active:
                    mapVM.loadNavigationSession()
                    mapVM.resumeNavigationIfNeeded(currentLocation: locationManager.location?.coordinate)

                case .inactive, .background:
                    mapVM.saveNavigationSession()

                default: break
                }
            }
            
            .onReceive(locationManager.$location.compactMap { $0 }) { loc in
                mapVM.processLocationUpdate(loc.coordinate, context: modelContext)
            }
        }
    }
    
}
