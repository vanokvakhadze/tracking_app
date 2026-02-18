//
//  MapArchive.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 17.02.26.
//

import SwiftUI
import GoogleMaps
import CoreLocation


struct MapArchive: View {
    @ObservedObject var mapVM: MapVM

    var body: some View {
        ZStack {
            ArchiveGoogleMap(routes: mapVM.drivenRoutes)
                .ignoresSafeArea()
        }
        .navigationTitle("Routes History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ArchiveGoogleMap: UIViewRepresentable {
    let routes: [DrivenRoute]

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(latitude: 41.7151, longitude: 44.8271, zoom: 11)
        let mapView = GMSMapView(frame: .zero, camera: camera)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.clear()

        guard !routes.isEmpty else { return }

        var bounds: GMSCoordinateBounds?

        for route in routes {
            let path = GMSMutablePath()

            for p in route.points {
                path.add(p.cl)
                bounds = bounds == nil
                ? GMSCoordinateBounds(coordinate: p.cl, coordinate: p.cl)
                : bounds!.includingCoordinate(p.cl)
            }

            let polyline = GMSPolyline(path: path)
            polyline.strokeWidth = 5
            polyline.geodesic = true
            polyline.map = mapView
        }

        if let bounds {
            mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 60))
        }
    }
}


