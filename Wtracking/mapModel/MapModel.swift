//
//  MapModel.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 14.01.26.
//


import Foundation
import MapKit
import CoreLocation


struct MapPoint: Identifiable {
    var id: String          // stable id (UUID string or your own)
    let title: String
    let coordinate: CLLocationCoordinate2D
    let systemIcon: String
       let color: UIColor
}







