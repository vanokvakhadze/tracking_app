//
//  MapScreen.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 24.02.26.
//

import SwiftUI
import GoogleMaps
import SwiftData
import CoreLocation

struct MapScreen: View {
    @Environment(\.modelContext) private var context
    @ObservedObject var mapVM: MapVM

    @State private var tappedCoordinate: CLLocationCoordinate2D?

    @State private var showStartAlert = false
    @State private var startAlertConfirmed = false
    @State private var showAddConfirm = false
    @State private var showDetailsSheet = false
    @State private var isAddingNextPlace = false
    @State private var selectedImageData: Data?
    @FocusState private var isTitleFocused: Bool
    @State private var typedTitle = ""
    @State private var typedAddress = ""
    @Binding var navigate: Bool

    var body: some View {
        StarterMapView(mapVM: mapVM, context: context) { coord in
            tappedCoordinate = coord

            if mapVM.places.isEmpty {

                if !startAlertConfirmed {
                    showStartAlert = true
                    return
                }

                mapVM.addStartPoint(coordinate: coord, context: context)

                tappedCoordinate = nil
                showAddConfirm = true
                return
            }

            if isAddingNextPlace {
                typedTitle = ""
                typedAddress = ""
                showDetailsSheet = true
                isAddingNextPlace = false
                return
            }

            showAddConfirm = true
        }
        .overlay(alignment: .top){
            if  !showAddConfirm || !startAlertConfirmed ||  !showStartAlert || !showAddConfirm {
                Text("მონიშნეთ ლოკაცია")
                    .padding(.horizontal, 24)
                    .padding(.vertical , 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(lineWidth: 2)
                    )
                    .offset(y: 70)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if mapVM.places.isEmpty {
                showStartAlert = true
            } else {
                startAlertConfirmed = true
            }
           
        }

        .alert("მონიშნეთ საწყისი წერტილი", isPresented: $showStartAlert) {
            Button("OK") {
                startAlertConfirmed = true
                showStartAlert = false
            }
        } message: {
            Text("გთხოვთ მონიშნოთ თქვენი ზუსტი ლოკაცია, საიდანაც დაიწყებთ და დაასრულებთ მოძრაობას.")
        }

        // ✅ Confirm dialog: add other location?
        .confirmationDialog("ობიექტის ლოკაციის დამატება",
                            isPresented: $showAddConfirm,
                            titleVisibility: .visible) {
            Button("კი") {
                // შემდეგ tap-ზე შეავსებინებს დეტალებს
                isAddingNextPlace = true
            }
            Button("არა", role: .cancel) {
                isAddingNextPlace = false
                tappedCoordinate = nil
                navigate = true
            }
        } message: {
            Text("გსურთ სხვა ლოკაციის დამატება?")
        }

        // ✅ Details sheet
        .sheet(isPresented: $showDetailsSheet) {
            NewObjectScreen(
                typedTitle: $typedTitle,
                typedAddress: $typedAddress,
                selectedImageData: $selectedImageData,
                onCancel: {
                    tappedCoordinate = nil
                    selectedImageData = nil
                    showDetailsSheet = false
                },
                onSave: {
                    guard let c = tappedCoordinate else { return }
                    
                    mapVM.addManualPoint(
                        coordinate: c,
                        title: typedTitle,
                        address: typedAddress,
                        imageData: selectedImageData,
                        context: context
                    )
                    
                    tappedCoordinate = nil
                    selectedImageData = nil
                    showDetailsSheet = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showAddConfirm = true
                    }
                },
                isTitleFocused: $isTitleFocused
            )
        }
            .onChange(of: showDetailsSheet) { _, isPresented in
                if isPresented {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 550_000_000)
                        isTitleFocused = true
                    }
                } else {
                    isTitleFocused = false
                }
            }
            .onAppear{
                isTitleFocused = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isTitleFocused = false
                }
            }
    }
}


struct StarterMapView: UIViewRepresentable {
    @ObservedObject var mapVM: MapVM
    var context: ModelContext

    var onTap: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> StartingMap { StartingMap(self) }

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(latitude: 41.7151, longitude: 44.8271, zoom: 12)
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.syncPlaceMarkers(on: mapView, places: mapVM.places)
    }
}

final class StartingMap: NSObject, GMSMapViewDelegate {
    private let parent: StarterMapView
    private var markersById: [String: GMSMarker] = [:]

    init(_ parent: StarterMapView) { self.parent = parent }

    func mapView(_ mapView: GMSMapView, didLongPressAt coordinate: CLLocationCoordinate2D) {
        print("✅ LONG PRESS:", coordinate.latitude, coordinate.longitude)
        DispatchQueue.main.async {
            self.parent.onTap(coordinate)
        }
    }

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

        for p in places where markersById[p.id] == nil {
            addMarker(on: mapView, place: p)
        }
    }
}
