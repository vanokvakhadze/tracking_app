//
//  sysImage.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 14.01.26.
//

import SwiftUI

struct sysImage: View {
    var image: String
    var width: CGFloat
    var height: CGFloat
    var body: some View {
        Image(systemName: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
    }
}
