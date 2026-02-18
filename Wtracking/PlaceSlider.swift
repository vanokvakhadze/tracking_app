//
//  PlaceSlider.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 01.02.26.
//

import SwiftUI

struct PlaceCarousel: View {
    let places: [MapPoint]
    @Binding var selectedIndex: Int
    let onIndexChanged: (MapPoint) -> Void
    let onStart: (MapPoint) -> Void

    @State private var scrollID: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                        if !place.isStartPoint{
                            PlaceCard(
                                place: place,
                                isSelected: selectedIndex == index,
                                onSelect: {
                                    setSelected(index: index, proxy: proxy)
                                },
                                onStart: { onStart(place) }
                            )
                            .frame(width: 300)
                            .id(place.id)
                            .scrollTargetLayout()
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollID, anchor: .center)
            .onAppear {
                guard places.indices.contains(selectedIndex) else { return }
                let id = places[selectedIndex].id
                scrollID = id
                onIndexChanged(places[selectedIndex])

                DispatchQueue.main.async {
                    proxy.scrollTo(id, anchor: .center)
                }
            }

            .onChange(of: scrollID) { newID in
                guard let newID,
                      let idx = places.firstIndex(where: { $0.id == newID }) else { return }

                if selectedIndex != idx {
                    selectedIndex = idx
                    onIndexChanged(places[idx])
                }
            }

            .onChange(of: selectedIndex) { newValue in
                guard places.indices.contains(newValue) else { return }
                let id = places[newValue].id

                if scrollID != id {
                    scrollID = id
                    withAnimation(.easeInOut) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private func setSelected(index: Int, proxy: ScrollViewProxy) {
        guard places.indices.contains(index) else { return }
        selectedIndex = index
        let id = places[index].id
        scrollID = id
        onIndexChanged(places[index])

        withAnimation(.easeInOut) {
            proxy.scrollTo(id, anchor: .center)
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
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
                                    .frame(
                                        width: max(size.width - 20, 1),
                                        height: max(size.height - 100, 1)
                                    )
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
                        
                    
                        StartButton(title: "", action: onStart)
                               
                    }
                    .padding(.top, 20)

                    
                    
                }
            
        
 
    }
}
