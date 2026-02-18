//
//  ResultView.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 17.02.26.
//

import SwiftUI

struct ResultView: View {
    @ObservedObject var mapVM: MapVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack{
            
            VStack(alignment: .leading){
                
                ScrollView{
                  
                    Text("total working time  = \(mapVM.format(mapVM.workSecondsTotal))")
                    
                    Spacer()
                        .frame(height: 15)
                    
                    ForEach(Array(mapVM.lastStayPlaceTitle.keys), id: \.self) { key in
                        HStack {
                            Text(key)
                            
                            Spacer()
                            
                            Text(mapVM.lastStayPlaceTitle[key] ?? "")
                            
                            Divider()
                                .frame(maxWidth: .infinity)
                                .frame(height: 3)
                                .foregroundStyle(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    NavigationLink(destination: MapArchive(mapVM: mapVM)) {
                        Text("view your history on the map")
                            .foregroundStyle(.primary)
                            
                    }
                    
                    Button(action: {
                        dismiss()
                        mapVM.showPlaceSlider = true
                            
                    }) {
                        Text("Go To Home")
                            .foregroundStyle(.white)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.blue.opacity(0.7))
                    )
                }
            }
        }
        .navigationBarBackButtonHidden()
        
    }
}

#Preview {
    ResultView(mapVM: MapVM())
}
