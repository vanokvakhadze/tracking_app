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
    @State private var isNavigating = false
    @State private var selectedIndex: Int = 0
    @State private var showPlaceSlider: Bool = true
    @State private var focusPlaceId: String? = "1"


    @State private var selectedPlace: MapPoint? = nil

    @State var  places: [MapPoint] = [
        MapPoint(id: "1", title: "Pickup",
                    coordinate: .init(latitude: 41.7271, longitude: 44.7506),
                    systemIcon: "checkmark",
                    color: .white),
        
        MapPoint(id: "2", title: "work2",
                 coordinate: .init(latitude: 41.7211, longitude: 44.7006),
                 systemIcon: "person", color: .white),
        
        MapPoint(id: "3", title: "work4",
                 coordinate: .init(latitude: 41.7211, longitude: 44.6406),
                 systemIcon: "car", color: .white),
        
        MapPoint(id: "4", title: "work4",
                 coordinate: .init(latitude: 41.7211, longitude: 44.6406),
                 systemIcon: "car", color: .white),
        
        MapPoint(id: "5", title: "work5",
                 coordinate: .init(latitude: 41.7221, longitude: 44.7356),
                 systemIcon: "house", color: .white),
        
        MapPoint(id: "6", title: "work6",
                 coordinate: .init(latitude: 41.7281, longitude: 44.8326),
                 systemIcon: "building", color: .white)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {

            GoogleMapView(
                        locationManager: locationManager,
                        places: places,
                        selectedPlace: $selectedPlace,
                        routePolylineEncoded: $mapVM.encodedPolyline,
                        isNavigating: $isNavigating,
                        focusPlaceId: $focusPlaceId          // ✅ NEW
                    )
            .onTapGesture {
               
                    selectedPlace = nil
                
            }
            .ignoresSafeArea()
            

                    // ✅ Cancel button (when route exists)
                    if mapVM.encodedPolyline != nil {
                        CancelButton {
                            mapVM.cancelRoute()
                            isNavigating = false
                            showPlaceSlider = true
                            selectedPlace = nil
                        }
                        .padding(.bottom, 24)
                    }
            
        }
        .sheet(isPresented: $showPlaceSlider) {
            LocationDetails(
                spacing: 15,
                trailingSpace: 80,
                index: $selectedIndex,
                items: places,
                onIndexChanged: { place in

                    selectedPlace = place
                    focusPlaceId = place.id

                }
            ) { place in

                PlaceCard(
                    place: place,
                    isSelected: places[selectedIndex].id == place.id,
                    onSelect: {},
                    onStart: {

                        guard let user = locationManager.location?.coordinate else { return }

                        mapVM.setUserLocation(user)
                        mapVM.setDestination(place.coordinate)
                        mapVM.startRoute()

                        isNavigating = true
                        showPlaceSlider = false
                    }
                )
            }
            .presentationDetents([.fraction(0.4)]) // ✅ 50% of screen
            .presentationCornerRadius(25) .interactiveDismissDisabled(true)
            .interactiveDismissDisabled(true)

        }
        
        .onAppear {
                // default selection
                if selectedPlace == nil, !places.isEmpty {
                    selectedPlace = places[0]
                    focusPlaceId = places[0].id
                }
            }
            .onChange(of: selectedIndex) { idx in
                guard places.indices.contains(idx) else { return }
                selectedPlace = places[idx]
                focusPlaceId = places[idx].id          // ✅ tell map to move camera
            }
            .onReceive(locationManager.$location.compactMap { $0 }) { loc in
                mapVM.setUserLocation(loc.coordinate)
            }
    }

    private func start(to place: MapPoint) {
          guard let user = locationManager.location?.coordinate else {
              print("No user location yet")
              return
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
