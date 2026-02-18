//
//  ContentView.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 14.01.26.
//

import SwiftUI
import CoreLocation

struct ContentView: View {
    
    @StateObject var locationManager = LocationManager()
    @StateObject var mapVM = MapVM()
    @State private var focusPlaceId: String? = "1"
    @State private var goToResult = false
    @State private var shouldCenter = false

    
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
               
             
                if mapVM.encodedPolyline != nil {
                    CancelButton(mapVM: mapVM, shouldCenter: $shouldCenter) {
                        mapVM.cancelRoute()
                        
                    }
                    
                }
                
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .sheet(isPresented: $mapVM.showPlaceSlider) {
                
                VStack(alignment: .trailing, spacing: 20){
                        
                        
                        Button(action: {
                            mapVM.showPlaceSlider = false
                            mapVM.finishRecordingDrive()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                goToResult = true
                            }
                        }) {
                            Text("Finish Work")
                                .foregroundStyle(.white)
                                .padding(6)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.red.opacity(0.7))
                        )
                    .padding(EdgeInsets(top: 15, leading: 0, bottom: 0, trailing: 10))

                PlaceCarousel(
                    places: mapVM.places,
                    selectedIndex: $mapVM.selectedIndex,
                    onIndexChanged: { place in
                        mapVM.selectedPlace = place
                        focusPlaceId = place.id
                    },
                    
                    
                    onStart: { place in
                        guard let user = locationManager.location?.coordinate else { return }
                        
                        mapVM.processLocationUpdate(user)
                        
                        mapVM.startTrackingPlace(place: place, radius: 50)
                        
                        mapVM.setDestination(place.coordinate)
                        mapVM.startRoute()
                        
                        mapVM.isNavigating = true
                        mapVM.showPlaceSlider = false
                    }
                    )
                    }
                
                .presentationDetents([.fraction(0.6) , .fraction(0.5)])
                .presentationCornerRadius(25) .interactiveDismissDisabled(true)
                .interactiveDismissDisabled(true)
                .presentationBackgroundInteraction(.enabled)
                
            }
            
            .navigationDestination(isPresented: $goToResult) {
                    ResultView(mapVM: mapVM)
                }
            .onAppear {
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
            .onReceive(locationManager.$location.compactMap { $0 }) { loc in
                mapVM.processLocationUpdate(loc.coordinate)
            }
        }
    }
    
    
}

#Preview {
    ContentView()
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
        
        // no bg -> just return symbol
        guard let bgColor = backgroundColor else {
            return symbol
        }
        
        // ✅ force square canvas
        let side = max(symbol.size.width, symbol.size.height) + padding * 2
        let size = CGSize(width: side, height: side)
        let radius = side / 2
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            
            // ✅ circle background
            let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            bgColor.setFill()
            path.fill()
            
            // center symbol
            let origin = CGPoint(
                x: (side - symbol.size.width) / 2,
                y: (side - symbol.size.height) / 2
            )
            symbol.draw(at: origin)
        }
    }
}
