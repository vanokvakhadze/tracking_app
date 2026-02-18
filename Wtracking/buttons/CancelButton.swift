//
//  CancelButton.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 18.02.26.
//

import SwiftUI

struct CancelButton: View {
    @ObservedObject var mapVM: MapVM
    @Binding var shouldCenter: Bool
    let action: () -> Void


    var body: some View {
        VStack(alignment: .leading, spacing: 10){
            HStack{
                Text("Distance: ")
                Text(mapVM.remainingDistanceText )
                
                Spacer()
                
                Button {
                       shouldCenter.toggle()
                   } label: {
                       HStack(spacing: 5){
                           Text("Center")
                               .foregroundStyle(.primary)
                               
                           Image(systemName: "location.fill")
                               .font(.system(size: 16, weight: .bold))
                               .foregroundStyle(.blue)

                           
                       }
                       .padding(12)
                   }
                   .background(
                       RoundedRectangle(cornerRadius: 12)
                        .fill(.secondary.opacity(0.7))
                   )
            }
            
            HStack{
                Text("Time: ")
                Text("\(mapVM.remainingETAText)")
            }
            
            Button(action: action) {
                Text("Cancel Route")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .background(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(radius: 6)
            }
            .padding(.top, 5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .frame(maxWidth: .infinity)
    }
}


