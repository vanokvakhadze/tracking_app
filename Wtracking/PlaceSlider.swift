//
//  PlaceSlider.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 01.02.26.
//

import SwiftUI

struct LocationDetails<Content: View, T: Identifiable>: View {

    var list: [T]
    var content: (T) -> Content

    var spacing: CGFloat
    var trailingSpace: CGFloat

    @Binding var index: Int
    let onIndexChanged: (T) -> Void

    @GestureState private var offset: CGFloat = 0

    init(
        spacing: CGFloat = 15,
        trailingSpace: CGFloat = 90,
        index: Binding<Int>,
        items: [T],
        onIndexChanged: @escaping (T) -> Void,
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.list = items
        self.spacing = spacing
        self.trailingSpace = trailingSpace
        self._index = index
        self.onIndexChanged = onIndexChanged
        self.content = content
    }

    var body: some View {

        GeometryReader { proxy in

            let availableWidth = proxy.size.width

            let cardWidth = max(availableWidth - trailingSpace, 1)
            let pageWidth = max(availableWidth - (trailingSpace - spacing), 1)
            let adjustmentWidth = (trailingSpace / 2) - spacing

            HStack(spacing: spacing) {

                ForEach(list) { item in
                    content(item)
                        .frame(width: cardWidth)
                }
            }
            .padding(.horizontal, spacing)
            .offset(x:
                (CGFloat(index) * -pageWidth)
                + (index != 0 ? adjustmentWidth : 0)
                + offset
            )
            .gesture(
                DragGesture()
                    .updating($offset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in

                        let threshold: CGFloat = pageWidth / 2
                        var newIndex = index

                        if value.translation.width > threshold {
                            newIndex -= 1
                        } else if value.translation.width < -threshold {
                            newIndex += 1
                        }

                        newIndex = max(min(newIndex, list.count - 1), 0)

                        withAnimation(.spring()) {
                            index = newIndex
                        }

                        onIndexChanged(list[newIndex])
                    }
            )
        }
        .animation(.easeInOut, value: offset == 0)
    }
}

struct StartButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(radius: 6)
                .padding(.horizontal, 16)
        }
    }
}

struct CancelButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Cancel Route")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.red)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(radius: 6)
                .padding(.horizontal, 16)
        }
    }
}


struct PlaceCard: View {
    let place: MapPoint
    let isSelected: Bool
    let onSelect: () -> Void
    let onStart: () -> Void

    var body: some View {


                GeometryReader { proxy in
                    let size = proxy.size
                    ZStack(alignment: .bottomTrailing){
                        VStack(alignment: .leading, spacing: 10) {
                            
                            Rectangle()
                                .fill(Color.gray.opacity(0.25))
                                .frame(width: size.width - 20, height: size.height - 100)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            
                            
                            Text(place.title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            Text("\(place.coordinate.latitude), \(place.coordinate.longitude)")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(width: size.width)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 6)
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(.spring(), value: isSelected)
                        
                    
                        Button(action: {
                            
                        }) {
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
            
        
 
    }
}
