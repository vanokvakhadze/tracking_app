//
//  ResultView.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 17.02.26.
//

import SwiftUI
import SwiftData


struct ResultView: View {
    @ObservedObject var mapVM: MapVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var visits: [PlaceVisitModel]
    
    init(mapVM: MapVM) {
           self.mapVM = mapVM

           _visits = Query(sort: \.enteredAt, order: .reverse)
       }

    

    var body: some View {
        ZStack{
            
            VStack(spacing: 20){
                if mapVM.workIsRunning {
                    
                    Text(mapVM.workIsRunning ? "დღის სამუშაო დრო:  \(mapVM.format(mapVM.currentWorkSeconds))" :  "დროის ათვლა დაიწყო : \(mapVM.format(mapVM.currentWorkSeconds))"  )
                        .bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(lineWidth: 1)
                        )
                }
                else {
                    Text("დროის ათვლა ჯერ არ დაწყებულა")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(lineWidth: 1)
                        )
                }
                
                
                    NavigationLink(destination: MapArchive(mapVM: mapVM)) {
                        HStack(spacing: 15){
                            Text("View your history on the map")
                                .foregroundStyle(.primary)
                            
                            sysImage(image: "mappin.and.ellipse", width: 25, height: 15)
                                .foregroundStyle(.green)
                            
                            Spacer(minLength: 10)
                            
                            sysImage(image: "chevron.forward.circle", width: 20, height: 15)
                                .foregroundStyle(.gray)
                               
                        
                        }
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity)
                        .frame(height: 45)
                            
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.blue, lineWidth: 2)
                    )
                
                
                if visits.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)

                        Text("ჩანაწერები ვერ მოიძებნა")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("დაიწყე გადადგილება და შენი ისტორია აქ გამოჩნდება.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
                } else {
                    
                    
                    
                    ScrollView{
                        VStack{
                            
                            HStack{
                                Text("კომპანიის სახელი")
                                    .bold()
                                    .frame(maxWidth: .infinity / 3, alignment: .leading)
                                    .padding(.leading, 15)
                                
                                Text("დრო")
                                    .bold()
                                    .frame(maxWidth: .infinity / 3)
                                
                                Text("თარიღი")
                                    .bold()
                                    .frame(maxWidth: .infinity / 3)
                                
                                
                                
                                
                            }
                            
                            
                            Divider()
                                .frame(maxWidth: .infinity)
                                .frame(height: 3)
                                .foregroundStyle(.gray)
                            
                            ForEach(visits, id: \.id) { stay in
                                
                                VStack(alignment: .leading){
                                    HStack {
                                        
                                        Text(stay.title)
                                            .frame(maxWidth: .infinity / 3, alignment: .leading)
                                            .padding(.leading, 5)
                                        
                                        Spacer()
                                        
                                        Text(formatDuration(stay.seconds))                                .frame(maxWidth: .infinity / 3)
                                        
                                        
                                        Text(dateOnly(stay.enteredAt))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity / 3)
                                    }
                                    .padding(10)
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        
                        .background(RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemBackground))
                        )
                        
                    }
                    
                    
                }
                    
                    Button(action: {
                        dismiss()
                        mapVM.showPlaceSlider = true
                            
                    }) {
                        Text("Back To Home")
                            .foregroundStyle(.white)
                            .padding(.horizontal, 55)
                            .padding(.vertical, 10)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.blue)
                    )
                
            }
            .padding()
        }
        .navigationBarBackButtonHidden()
        
    }
    

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    func formatDuration(_ seconds: Double?) -> String {
        guard let seconds else { return "-" }

        let s = Int(seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60

        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(sec)s" }
        return "\(sec)s"
    }
    func dateOnly(_ date: Date?) -> String {
        guard let date else { return "-" }
        return dateFormatter.string(from: date)
    }
}

#Preview {
    ResultView(mapVM: MapVM())
}
