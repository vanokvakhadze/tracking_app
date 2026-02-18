//
//  StartButton.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 18.02.26.
//

import SwiftUI

struct StartButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
       
        
        Button(action: action) {
            HStack{
                Text("Start")
                
                
                Spacer()
                    .frame(width: 12)
                
                Image(systemName: "location.north.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)
                    .frame(maxWidth: 18, maxHeight: 18)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Circle())
                    .shadow(color: .green.opacity(0.35), radius: 4)
                
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
            )
    }
    }
}

